# ZFS settings shared by the installer and the system it installs.
{
  boot.supportedFilesystems = [ "zfs" ];

  # By-partuuid works on every kind of drive, and each pool member has a unique UUID.
  boot.zfs.devNodes = "/dev/disk/by-partuuid";

  # Datasets are mounted from fstab only. Mounting by dataset property would let anyone
  # who can write to the pool mount a dataset over the system at the next boot.
  systemd.services.zfs-mount.enable = false;
  systemd.services.zfs-share.enable = false;
  boot.zfs.forceImportRoot = false;

  # ZFS requires a host ID. It is constant so one image fits every machine.
  networking.hostId = "c0b0c0b0";
}
