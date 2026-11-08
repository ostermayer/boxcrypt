# The complete flashable system. It holds nothing machine-specific. See ADR-004.
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "mode=755"
        "size=25%"
      ];
    };
    "/nix" = {
      device = "cbpool/nix";
      fsType = "zfs";
      neededForBoot = true;
    };
    "/persist" = {
      device = "cbpool/persist";
      fsType = "zfs";
      neededForBoot = true;
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/CB-ESP";
      fsType = "vfat";
      options = [
        "umask=0077"
        "nofail"
      ];
    };
  };

  boot = {
    supportedFilesystems = [ "zfs" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = false;
    };
    initrd.availableKernelModules = [
      "ahci"
      "mmc_block"
      "nvme"
      "sd_mod"
      "sdhci_pci"
      "usb_storage"
      "xhci_pci"
    ];
  };

  # ZFS requires a host ID. It is constant so one image fits every machine.
  networking.hostId = "c0b0c0b0";

  # Network cards such as the common Realtek 2.5G need firmware to work.
  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "26.05";
}
