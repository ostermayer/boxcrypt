# The complete flashable system: a kernel image and a verified, read-only OS.
# It holds nothing machine-specific. See ADR-004 and ADR-018.
{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  inherit (config.image.repart.verityStore) partitionIds;
  inherit (pkgs.stdenv.hostPlatform) efiArch;
in
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
    (modulesPath + "/image/repart.nix")
    ./zfs.nix
  ];

  image.repart = {
    name = "boxcrypt";
    verityStore.enable = true;

    # The image builder follows the disk's 512-byte sectors by default, but udev cannot
    # identify EROFS with blocks that small, so systemd would ignore the OS at boot.
    mkfsOptions.erofs = [ "-b4096" ];

    partitions.${partitionIds.esp} = {
      contents = {
        "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
          "${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
        # Without this, anyone at the keyboard could edit the kernel command line.
        "/loader/loader.conf".source = pkgs.writeText "loader.conf" ''
          timeout 0
          editor no
        '';
      };
      repartConfig = {
        Type = "esp";
        Format = "vfat";
        SizeMinBytes = "1G";
      };
    };
  };

  system.image = {
    id = "boxcrypt";
    version = "0.1.0";
  };

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "mode=755"
        "size=25%"
      ];
    };
    # Files here cannot be executed directly, and nothing at boot reads code from here.
    "/persist" = {
      device = "bcpool/persist";
      fsType = "zfs";
      neededForBoot = true;
      options = [
        "noexec"
        "nosuid"
        "nodev"
      ];
    };
  };

  boot = {
    initrd = {
      systemd.enable = true;
      # No USB here: a stick holding a pool named bcpool must never be imported at boot.
      availableKernelModules = [
        "ahci"
        "mmc_block"
        "nvme"
        "sd_mod"
        "sdhci_pci"
      ];
    };
    # Backup drives arrive after module loading is locked, so load their drivers now.
    kernelModules = [
      "ext4"
      "sd_mod"
      "uas"
      "usb_storage"
    ];
  };

  services.zfs.autoScrub.enable = true;
  # An owner may keep the box switched off, and a calendar date alone can then be missed.
  systemd.timers.zfs-scrub.timerConfig.OnBootSec = "1h";

  security.lockKernelModules = true;

  # /usr is read-only, so activation must not try to create /usr/bin/env.
  system.activationScripts.usrbinenv = lib.mkForce "";

  # Network cards such as the common Realtek 2.5G need firmware to work.
  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "26.05";
}
