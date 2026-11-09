# Proves the installer builds a mirror, leaves USB drives alone, and that each drive boots alone.
{ self }:
{
  name = "boxcrypt-install";

  nodes = {
    installer =
      {
        config,
        nodes,
        pkgs,
        ...
      }:
      {
        imports = [ ../modules/presets/zfs.nix ];

        environment.systemPackages = [
          pkgs.gptfdisk
          (pkgs.callPackage ../pkgs/boxcrypt-install.nix {
            zfs = config.boot.zfs.package;
            inherit (nodes.box.system.build) image;
            imageFile = nodes.box.image.filePath;
          })
        ];

        virtualisation = {
          memorySize = 2048;
          emptyDiskImages = [
            40960
            40960
          ];
          # The stick the owner might have left plugged in.
          qemu.options = [
            "-device qemu-xhci"
            "-drive id=stick,if=none,format=raw,file=$(pwd)/stick.img"
            "-device usb-storage,drive=stick"
          ];
        };
      };

    box =
      { lib, ... }:
      {
        imports = [
          self.nixosModules.default
          ../modules/presets/appliance.nix
        ];

        # Boot the image the way a real machine would, without the framework's shortcuts.
        virtualisation = {
          fileSystems = lib.mkVMOverride { };
          directBoot.enable = false;
          mountHostNixStore = false;
          useEFIBoot = true;
        };
      };
  };

  testScript =
    { nodes, ... }:
    ''
    import os
    import subprocess

    IMAGE = "${nodes.box.system.build.image}/${nodes.box.image.filePath}"
    LAYOUT = "${nodes.box.system.build.image}/repart-output.json"

    STICK_MARK = "boxcrypt-test-stick"
    SECRET = "kept-on-the-mirror"

    def boot_box(*disks):
        os.environ["NIX_DISK_IMAGE"] = str(disks[0])
        extra = [f"-drive file={disk},if=virtio,format=qcow2" for disk in disks[1:]]
        os.environ["QEMU_OPTS"] = " ".join(extra)
        box.start()
        box.wait_for_unit("multi-user.target")

    def marks_on(member, mark):
        # grep -z skips runs of zeros without counting them, which gives the wrong offset.
        found = box.succeed(f"tr '\\0' '\\n' < {member} | grep -abo {mark}").split()
        return [int(line.split(":")[0]) for line in found]

    def damage_then_repair(member, copies):
        # One mark per run, because an install does not overwrite what was on the drive.
        mark = f"boxcrypt-bitrot-{copies}-copies"
        # Uncompressed and with no intent log, so each copy of the mark is on disk once.
        box.succeed(
            "zfs create -o compression=off -o sync=disabled -o mountpoint=legacy bcpool/rot",
            "mkdir -p /rot && mount -t zfs bcpool/rot /rot",
            f"(printf {mark}; head -c 64K /dev/urandom) > /rot/file",
            "zpool sync bcpool",
        )
        checksum = box.succeed("sha256sum /rot/file")
        marks = marks_on(member, mark)
        assert len(marks) == copies, f"expected {copies} copies on {member}: {marks}"
        box.succeed(f"printf damaged-by-bitrot | dd of={member} bs=1 seek={marks[0]} conv=notrunc,fsync status=none")
        box.succeed("systemctl start --wait zfs-scrub.service")
        status = box.succeed("zpool status bcpool")
        assert "repaired 0B" not in status and "with 0 errors" in status, status
        assert len(marks_on(member, mark)) == copies, "the scrub did not repair the damage"
        assert box.succeed("sha256sum /rot/file") == checksum, "the file changed"

    subprocess.run(["truncate", "-s", "64M", str(installer.state_dir / "stick.img")], check=True)

    INSTALL = "BOXCRYPT_FIRMWARE_DIR=/tmp/uefi boxcrypt-install"
    DRIVES = ["/dev/vdb", "/dev/vdc"]

    # Partitions 1 to 5 end near 19 GiB, the pool fills the rest, and GPT keeps a copy at the end.
    SAMPLED_GIB = [0, 2, 10, 18, 30]

    def fingerprint(drives=DRIVES):
        def sample(drive):
            reads = "; ".join(f"dd if={drive} bs=1M skip={gib * 1024} count=64 status=none" for gib in SAMPLED_GIB)
            return installer.succeed(f"({reads}; tail -c 64M {drive}) | sha256sum")
        return [sample(drive) for drive in drives]

    def refused(reason, drives=DRIVES):
        before = fingerprint(drives)
        output = installer.fail(f"printf 'ACCEPT\\nERASE\\n' | {INSTALL} 2>&1")
        assert reason in output, output
        assert fingerprint(drives) == before, f"refusing with '{reason}' changed the drives"

    installer.start()
    installer.wait_for_unit("multi-user.target")
    installer.wait_until_succeeds("lsblk -dno TRAN | grep -q usb")
    stick = installer.succeed("lsblk -dpno NAME,TRAN | awk '$2 == \"usb\" {print $1}'").strip()
    installer.succeed(f"printf {STICK_MARK} | dd of={stick} conv=fsync status=none")
    stick_before = installer.succeed(f"sha256sum {stick}")
    for drive in DRIVES:
        installer.succeed(f"printf old-data-{drive[-1]} | dd of={drive} conv=fsync status=none")
    drives_before = fingerprint()
    installer.succeed("mkdir -p /tmp/uefi/efivars && touch /tmp/uefi/efivars/placeholder")
    installer_drive_before = installer.succeed("blkid -o value -s UUID /dev/vda")

    with subtest("refuses a machine that does not boot with UEFI"):
        output = installer.fail("printf 'ACCEPT\\nERASE\\n' | boxcrypt-install 2>&1")
        assert "UEFI" in output, output

    with subtest("warns when there is no TPM"):
        output = installer.fail(f"printf 'no\\n' | {INSTALL} 2>&1")
        assert "no TPM 2.0 was found" in output, output

    with subtest("refuses to continue without confirmation"):
        installer.fail(f"printf 'ACCEPT\\nno\\n' | {INSTALL}")

    with subtest("a refused install changes nothing"):
        assert fingerprint() == drives_before, "a refused install changed the drives"

    with subtest("refuses to install with Secure Boot on"):
        secure_boot = "/tmp/uefi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
        installer.succeed(f"printf '\\006\\000\\000\\000\\001' > {secure_boot}")
        refused("Secure Boot")
        installer.succeed(f"rm {secure_boot}")

    with subtest("refuses a damaged system image"):
        installer.succeed(f"truncate -s 1M /tmp/damaged && mount --bind /tmp/damaged {IMAGE}")
        refused("not intact")
        installer.succeed(f"umount {IMAGE}")

    with subtest("refuses a damaged layout"):
        installer.succeed(f"cp {LAYOUT} /tmp/layout && echo >> /tmp/layout && mount --bind /tmp/layout {LAYOUT}")
        refused("not intact")
        installer.succeed(f"umount {LAYOUT}")

    with subtest("refuses while any storage pool is active"):
        installer.succeed("zpool create -f tank /dev/vdb")
        refused("pool is active", drives=["/dev/vdc"])
        # Reopening the pool proves that its own drive was left alone.
        installer.succeed("zpool export tank && zpool import -d /dev tank && zpool destroy tank")

    with subtest("refuses a drive that is in use"):
        installer.succeed("mkfs.ext4 -qF /dev/vdb && mkdir -p /mnt/busy && mount /dev/vdb /mnt/busy && echo kept > /mnt/busy/file")
        refused("in use", drives=["/dev/vdc"])
        installer.succeed("umount /mnt/busy && mount /dev/vdb /mnt/busy && grep -qx kept /mnt/busy/file && umount /mnt/busy")

    with subtest("installs onto both drives"):
        output = installer.succeed(f"printf 'ACCEPT\\nERASE\\n' | {INSTALL} 2>&1")
        assert "runs from vda" in output, output
        for drive in DRIVES:
            layout = installer.succeed(f"sgdisk --print {drive}")
            for name in ["BC-ESP", "BC-SYS-A", "BC-VER-A", "BC-SYS-B", "BC-VER-B", "BC-ZFS"]:
                assert name in layout, f"{name} missing from {drive}: {layout}"

    with subtest("the USB stick was left alone"):
        assert installer.succeed(f"sha256sum {stick}") == stick_before, "the stick changed"

    with subtest("the drive the installer runs from was left alone"):
        after = installer.succeed("blkid -o value -s UUID /dev/vda")
        assert after == installer_drive_before, "the installer changed its own drive"

    installer.shutdown()

    first = installer.state_dir / "empty0.qcow2"
    second = installer.state_dir / "empty1.qcow2"

    boot_box(first, second)

    with subtest("boots from the verified OS onto a healthy mirror"):
        assert "ACTIVE" in box.succeed("dmsetup info --target verity usr")
        status = box.succeed("zpool status bcpool")
        assert "mirror" in status and "ONLINE" in status, status
        box.succeed("findmnt -no OPTIONS /persist | grep -q noexec")
        box.succeed(f"echo {SECRET} > /persist/canary")
        box.succeed("zfs create -o mountpoint=/planted bcpool/planted")
        box.succeed("sync; zpool sync bcpool")

    with subtest("the mirror repairs silent damage to one drive"):
        box.succeed("systemctl is-active zfs-scrub.timer")
        timers = box.succeed("systemctl show -p TimersMonotonic --value zfs-scrub.timer")
        assert "OnBootUSec=1h" in timers, timers
        damage_then_repair("/dev/vda6", copies=1)

    box.shutdown()

    for name, disk in [("first", first), ("second", second)]:
        boot_box(disk)
        with subtest(f"the {name} drive boots alone and still has the data"):
            assert "DEGRADED" in box.succeed("zpool status bcpool")
            assert box.succeed("cat /persist/canary").strip() == SECRET
        with subtest("a dataset planted in the pool is not mounted at boot"):
            box.fail("findmnt /planted")
        box.shutdown()

    # boot_box chose the disks through these, and they would also apply to the installer.
    os.environ.pop("NIX_DISK_IMAGE")
    os.environ.pop("QEMU_OPTS")
    installer.start()
    installer.wait_for_unit("multi-user.target")
    installer.succeed(
        "mkdir -p /tmp/uefi/efivars && touch /tmp/uefi/efivars/placeholder",
        # Hides the second drive, as if this computer had only one.
        "basename $(readlink -f /sys/block/vdc/device) > /sys/bus/virtio/drivers/virtio_blk/unbind",
    )

    with subtest("installs onto one drive and warns about it"):
        output = installer.succeed(f"printf 'ACCEPT\\nERASE\\n' | {INSTALL} 2>&1")
        assert "with one drive" in output, output

    installer.shutdown()
    boot_box(first)

    with subtest("one drive repairs silent damage from its second copy"):
        damage_then_repair("/dev/vda6", copies=2)

    box.shutdown()
  '';
}
