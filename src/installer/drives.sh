# Prints every physical drive underneath the filesystem that holds a path.
drives_backing() {
  local source listing name type
  source=$(findmnt -no SOURCE -T "$1") || die "Cannot find the drive that holds $1."
  source=${source%%\[*}
  [[ -b $source ]] || return 0
  listing=$(lsblk -nsro NAME,TYPE "$source") || die "Cannot inspect the drive that holds $1."
  while read -r name type; do
    if [[ $type == disk ]]; then echo "$name"; fi
  done <<<"$listing"
}

# The drives this installer is running from must never be erased.
protected_drives() {
  local path
  for path in / /nix/store "$BOXCRYPT_IMAGE"; do
    drives_backing "$path"
  done | sort -u | jq -Rsc 'split("\n") | map(select(. != ""))'
}

# Lists internal drives that are writable, or read-only when $1 is true.
internal_drives() {
  local protected
  protected=$(protected_drives) || return 1
  lsblk --json --nodeps -o NAME,TYPE,TRAN,RM,RO |
    jq -r --argjson skip "$protected" --argjson readonly "$1" '
      .blockdevices[]
      | select(.type == "disk" and .rm == false and .ro == $readonly)
      | select(
          (.tran // "" | test("^(sata|ata|sas|nvme|mmc|virtio)$"))
          or (.tran == null and (.name | test("^mmcblk")))
        )
      | select(.name | test("^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|mmcblk[0-9]+)$"))
      | select(.name as $name | $skip | index($name) | not)
      | .name'
}

is_sd_card() {
  local type=/sys/block/$1/device/type
  [[ $1 == mmcblk* ]] || return 1
  [[ ! -r $type || $(<"$type") == SD ]]
}

# An SD card in a built-in reader can look internal, but it is not ours to erase.
erasable_drives() {
  local listing drive
  listing=$(internal_drives false) || return 1
  while read -r drive; do
    [[ -n $drive ]] || continue
    if ! is_sd_card "$drive"; then echo "$drive"; fi
  done <<<"$listing"
}

large_enough() {
  local size
  size=$(blockdev --getsize64 "/dev/$1") || die "Cannot read the size of $1."
  ((size >= MIN_DRIVE_BYTES))
}

# Mirror every NVMe and SATA drive. eMMC is only used when there is nothing else.
# Extra namespaces on one NVMe drive are skipped, because they would be a false mirror.
select_targets() {
  local -a preferred=() fallback=()
  local drive
  for drive in "$@"; do
    large_enough "$drive" || continue
    if [[ $drive =~ ^nvme[0-9]+n([2-9]|[0-9]{2,})$ ]]; then continue; fi
    if [[ $drive == mmcblk* ]]; then
      fallback+=("$drive")
    else
      preferred+=("$drive")
    fi
  done
  if ((${#preferred[@]})); then
    printf '%s\n' "${preferred[@]}"
  elif ((${#fallback[@]})); then
    printf '%s\n' "${fallback[0]}"
  fi
}

drive_in_use() {
  local listing type mounts
  listing=$(lsblk -nro TYPE,MOUNTPOINTS "/dev/$1") || die "Cannot inspect $1."
  while read -r type mounts; do
    [[ $type == disk || $type == part ]] || return 0
    [[ -z $mounts ]] || return 0
  done <<<"$listing"
  return 1
}

check_not_in_use() {
  local drive
  for drive in "$@"; do
    if drive_in_use "$drive"; then die "$drive is in use. Nothing was changed."; fi
  done
}

# What the owner approves. A drive that changes after approval stops the install.
drive_identities() {
  lsblk -bdnro NAME,SIZE,MODEL,SERIAL,TRAN,DISK-SEQ "${@/#//dev/}"
}

# Drive models come from the hardware, so they must not be able to control the terminal.
describe_drive() {
  local model serial size
  model=$(lsblk -dno MODEL "/dev/$1" | tr -c '[:print:]' ' ' | cut -c1-40)
  serial=$(lsblk -dno SERIAL "/dev/$1" | tr -c '[:print:]' ' ' | cut -c1-40)
  size=$(lsblk -dno SIZE "/dev/$1" | tr -d ' ')
  printf '  /dev/%s  %s  %s  %s\n' "$1" "$size" "$model" "$serial"
}

show_plan() {
  local -n all_drives=$1 target_drives=$2
  local drive kept
  echo "These drives will be ERASED:"
  for drive in "${all_drives[@]}"; do
    describe_drive "$drive"
  done
  echo
  if ((${#target_drives[@]} > 1)); then
    echo "BoxCrypt will mirror ${#target_drives[@]} drives: ${target_drives[*]}."
    echo "It keeps running as long as one of them works."
  else
    echo "BoxCrypt will use one drive: ${target_drives[0]}."
    echo "WARNING: with one drive, a drive failure means restoring from a backup."
  fi
  kept=$(protected_drives | jq -r 'join(" ")')
  if [[ -n $kept ]]; then echo "This installer runs from $kept. That drive will not be erased."; fi
  echo "Unplug any drive that you want to keep. External eSATA and SAS drives count as internal."
  echo
}

has_trusted_tpm() {
  local device=/sys/class/tpm/tpm0
  [[ -e $device/tpm_version_major && $(<"$device/tpm_version_major") == 2 ]] || return 1
  [[ $(readlink -f "$device") != */usb* ]]
}

warn_about_tampering() {
  echo "This version cannot detect changes to its boot files yet."
  echo
  if ! has_trusted_tpm; then confirm "$NO_TPM_WARNING" ACCEPT; fi
}

# shellcheck disable=SC2034  # result is a reference to the caller's array.
list_into() {
  local -n result=$1
  local listing
  listing=$("${@:2}") || die "Cannot read the list of drives."
  result=()
  if [[ -n $listing ]]; then mapfile -t result <<<"$listing"; fi
}

# Run after the owner approves, because the prompt can wait for a long time.
check_unchanged() {
  local approved=$1
  shift
  local -a now read_only
  list_into read_only internal_drives true
  list_into now erasable_drives
  [[ ${#read_only[@]} -eq 0 && "${now[*]}" == "$*" ]] || die "The drives changed. Nothing was erased."
  [[ $(drive_identities "$@") == "$approved" ]] || die "The drives changed. Nothing was erased."
  check_not_in_use "$@"
  check_no_active_pools
}
