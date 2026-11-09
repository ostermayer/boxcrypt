erase_drive() {
  local drive=$1 name type
  while read -r name type; do
    [[ $type == part ]] || continue
    zpool labelclear -f "$name" 2>/dev/null || true
    wipefs -aq "$name" || true
  done < <(lsblk -nlpo NAME,TYPE "/dev/$drive")
  wipefs -aq "/dev/$drive" || true
  sgdisk --zap-all "/dev/$drive" >/dev/null
  blkdiscard -f "/dev/$drive" 2>/dev/null || true
  udevadm settle
}

partition_path() {
  if [[ $1 == *[0-9] ]]; then
    echo "/dev/$1p$2"
  else
    echo "/dev/$1$2"
  fi
}

create_partitions() {
  local drive=$1 pool_uuid=$2
  sgdisk --clear \
    --new=1:0:+"$ESP_SIZE" --typecode=1:"$TYPE_ESP" --change-name=1:BC-ESP \
    --partition-guid=1:"$(layout_field esp uuid)" \
    --new=2:0:+"$SLOT_SIZE" --typecode=2:"$TYPE_USR" --change-name=2:BC-SYS-A \
    --partition-guid=2:"$(layout_field store uuid)" \
    --new=3:0:+"$HASH_SIZE" --typecode=3:"$TYPE_USR_VERITY" --change-name=3:BC-VER-A \
    --partition-guid=3:"$(layout_field store-verity uuid)" \
    --new=4:0:+"$SLOT_SIZE" --typecode=4:"$TYPE_UNUSED" --change-name=4:BC-SYS-B \
    --new=5:0:+"$HASH_SIZE" --typecode=5:"$TYPE_UNUSED" --change-name=5:BC-VER-B \
    --new=6:0:0 --typecode=6:"$TYPE_ZFS" --change-name=6:BC-ZFS \
    --partition-guid=6:"$pool_uuid" \
    "/dev/$drive" >/dev/null
  udevadm settle
}

# Writes one partition from the image, then reads it back to prove the drive kept it.
write_partition() {
  local drive=$1 number=$2 label=$3 target offset size
  target=$(partition_path "$drive" "$number")
  offset=$(layout_field "$label" offset)
  size=$(layout_field "$label" raw_size)
  (($(blockdev --getsize64 "$target") >= size)) || die "The $label image does not fit on $drive."
  dd if="$BOXCRYPT_IMAGE" of="$target" bs=4M \
    iflag=skip_bytes,count_bytes conv=fsync status=none skip="$offset" count="$size"
  # Without this, the comparison would read the kernel's cache and not the drive.
  blockdev --flushbufs "$target"
  cmp --bytes="$size" --ignore-initial="$offset:0" "$BOXCRYPT_IMAGE" "$target" ||
    die "The $label partition was not written correctly to $drive."
}

# A bad drive should fail here, not at the first boot.
verify_system() {
  local drive=$1
  veritysetup verify \
    "$(partition_path "$drive" 2)" "$(partition_path "$drive" 3)" \
    "$(layout_field store roothash)"
}

install_system() {
  local drive=$1 pool_uuid=$2
  echo "Writing the system to $drive..."
  create_partitions "$drive" "$pool_uuid"
  write_partition "$drive" 1 esp
  write_partition "$drive" 2 store
  write_partition "$drive" 3 store-verity
  verify_system "$drive"
}

verify_pool() {
  local expected=$1 name members=0
  [[ $(zpool status -x "$POOL") == *"is healthy"* ]] || die "The new storage pool is not healthy."
  while read -r name _; do
    if [[ $name == /dev/* ]]; then members=$((members + 1)); fi
  done < <(zpool list -HPv "$POOL")
  ((members == expected)) || die "The storage pool has $members drives, expected $expected."
}

create_pool() {
  local -a vdevs=()
  (($# > 1)) && vdevs+=(mirror)
  local uuid
  for uuid in "$@"; do
    vdevs+=("/dev/disk/by-partuuid/$uuid")
  done
  zpool create -f -o ashift=12 -O compression=zstd -O atime=off \
    -O exec=off -O setuid=off -O devices=off \
    -O mountpoint=none -O canmount=off \
    "$POOL" "${vdevs[@]}"
  # A failed install must not leave a pool behind, or the next attempt would refuse to run.
  trap 'zpool export -f "$POOL" 2>/dev/null || true' EXIT
  # With no mirror, a second copy of the data at least survives bad blocks.
  (($# > 1)) || zfs set copies=2 "$POOL"
  zfs create -o mountpoint=legacy "$POOL/persist"
  verify_pool "$#"
  zpool export "$POOL"
  trap - EXIT
}

main() {
  local -a all targets read_only uuids=()
  check_firmware
  check_image
  check_no_active_pools

  list_into read_only internal_drives true
  ((${#read_only[@]} == 0)) || die "Read-only drive found: ${read_only[*]}. Remove it first."
  list_into all erasable_drives
  ((${#all[@]})) || die "No internal drives were found."
  list_into targets select_targets "${all[@]}"
  ((${#targets[@]})) || die "No internal drive is large enough. At least 32 GB is needed."
  check_not_in_use "${all[@]}"

  local approved
  approved=$(drive_identities "${all[@]}")
  show_plan all targets
  warn_about_tampering
  confirm "All data on these drives will be erased. Forensic tools may still recover old data." ERASE
  check_unchanged "$approved" "${all[@]}"

  local drive
  for drive in "${all[@]}"; do
    erase_drive "$drive"
  done
  for drive in "${targets[@]}"; do
    uuids+=("$(uuidgen)")
    install_system "$drive" "${uuids[-1]}"
  done
  udevadm settle
  create_pool "${uuids[@]}"
  sync
  echo "Installed. Remove the USB stick and restart this computer."
}

main "$@"
