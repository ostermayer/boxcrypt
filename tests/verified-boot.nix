# Proves the shipped system runs from a read-only, integrity-checked OS and refuses altered
# blocks. It does not cover the boot files themselves: see doc/modules/integrity.md.
{ self }:
{
  name = "boxcrypt-verified-boot";

  nodes.box =
    { lib, pkgs, ... }:
    {
      imports = [
        self.nixosModules.default
        ../modules/presets/appliance.nix
      ];

      # Reads the boot partition without a kernel module, which are locked after boot.
      environment.systemPackages = [ pkgs.mtools ];

      # The installer creates the real pool. This test only needs somewhere to mount.
      fileSystems."/persist" = {
        device = lib.mkForce "none";
        fsType = lib.mkForce "tmpfs";
      };

      # Boot the image the way a real machine would, without the framework's shortcuts.
      virtualisation = {
        fileSystems = lib.mkVMOverride { };
        directBoot.enable = false;
        mountHostNixStore = false;
        useEFIBoot = true;
      };

      # The test framework gives root an empty password. Remove it to test what ships.
      users.users.root.hashedPasswordFile = lib.mkForce null;
    };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.box.system.build) image;
      qemu = nodes.box.virtualisation.qemu.package;
    in
    ''
      import json
      import os
      import subprocess
      import tempfile

      RAW_IMAGE = "${image}/${nodes.box.image.filePath}"
      READ_WHOLE_OS = "dd if=/dev/mapper/usr of=/dev/null bs=1M"
      BLOCK_SIZE = 4096

      def new_disk():
          disk = tempfile.NamedTemporaryFile(suffix=".qcow2", delete=False).name
          subprocess.run(
              ["${qemu}/bin/qemu-img", "create", "-f", "qcow2", "-b", RAW_IMAGE, "-F", "raw", disk],
              check=True,
          )
          return disk

      def boot_from(disk):
          os.environ["NIX_DISK_IMAGE"] = disk
          box.start()
          box.wait_for_unit("multi-user.target")

      def offset_inside_os():
          with open("${image}/repart-output.json") as output:
              store = next(p for p in json.load(output) if p["label"] == "store")
          middle = store["offset"] + store["raw_size"] // 2
          return middle - middle % BLOCK_SIZE

      boot_from(new_disk())

      with subtest("runs from a volatile root and a verified OS"):
          box.succeed("findmnt --kernel --type tmpfs /")
          assert "ACTIVE" in box.succeed("dmsetup info --target verity usr")
          backing = box.succeed("df --output=source /nix/store | tail -n1").strip()
          assert backing == "/dev/mapper/usr", f"/nix/store is backed by {backing}"

      with subtest("the OS cannot be written to"):
          box.fail("touch /nix/store/tampered")
          box.fail("mount -o remount,rw /nix/store")

      with subtest("the boot menu cannot be edited at the keyboard"):
          box.succeed("MTOOLS_SKIP_CHECK=1 mtype -i /dev/vda1 ::loader/loader.conf | grep -qx 'editor no'")

      with subtest("every block of the unmodified OS verifies"):
          box.succeed(READ_WHOLE_OS)

      with subtest("root is locked on the system that ships"):
          box.succeed("grep -q '^root:!' /etc/shadow")

      with subtest("kernel modules are locked after boot"):
          box.succeed("grep -qx 1 /proc/sys/kernel/modules_disabled")
          box.fail("modprobe dummy")

      with subtest("files on /persist cannot be executed directly"):
          box.succeed("findmnt -no OPTIONS /persist | grep -q noexec")
          box.succeed("cp /run/current-system/sw/bin/true /persist/planted")
          box.fail("/persist/planted")

      with subtest("the firewall loader does not read writable state"):
          service = box.succeed("systemctl show -p ExecStart --value nftables.service")
          loader = service.split("path=")[1].split()[0]
          assert loader.startswith("/nix/store/"), service
          box.fail(f"grep -q /persist {loader}")
          before = box.succeed("nft list ruleset")
          box.succeed("touch /persist/network/wifi-enabled")
          box.succeed("systemctl restart nftables.service")
          after = box.succeed("nft list ruleset")
          assert before == after, "changing writable state changed the firewall"

      box.shutdown()

      with subtest("an altered block of the OS is refused"):
          disk = new_disk()
          subprocess.run(
              ["${qemu}/bin/qemu-io", "-c", f"write -P 0x41 {offset_inside_os()} {BLOCK_SIZE}", disk],
              check=True,
          )
          boot_from(disk)
          box.fail(READ_WHOLE_OS)
          box.succeed("dmesg | grep -q 'verity.*data block.*is corrupted'")
    '';
}
