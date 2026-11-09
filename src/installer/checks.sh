# Turns this computer into a BoxCrypt device by erasing its internal drives.
# See doc/modules/installer.md and doc/modules/storage.md.

export LC_ALL=C

readonly POOL=bcpool
readonly ESP_SIZE=1G
readonly SLOT_SIZE=8G
readonly HASH_SIZE=1G
readonly MIN_DRIVE_BYTES=$((32 * 1024 * 1024 * 1024))
readonly FIRMWARE_DIR=${BOXCRYPT_FIRMWARE_DIR:-/sys/firmware/efi}
readonly SECURE_BOOT_VAR=$FIRMWARE_DIR/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c

# GPT partition types, from the Discoverable Partitions Specification and ZFS.
readonly TYPE_ESP=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
readonly TYPE_USR=8484680C-9521-48C6-9C11-B0720656F69E
readonly TYPE_USR_VERITY=77FF5F63-E7B6-4633-ACF4-1565B864C0E6
readonly TYPE_ZFS=6A898CC3-1DD2-11B2-99A6-080020736631
readonly TYPE_UNUSED=0FC63DAF-8483-4772-8E79-3D69D8477DE4

readonly GUID_PATTERN='^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
readonly DAMAGED="The installer is damaged"

readonly NO_TPM_WARNING="WARNING: no TPM 2.0 was found.
This machine cannot prove it has not been tampered with. Your secrets are still
encrypted, but if malware replaced the system you would not be told.
If this computer has a TPM, it may be switched off in the BIOS, under a name such
as Intel PTT or AMD fTPM."

die() {
  echo "boxcrypt-install: $*" >&2
  exit 1
}

confirm() {
  local message=$1 word=$2 answer
  printf '%s\n\nType %s to continue: ' "$message" "$word"
  read -r answer || die "Cancelled. Nothing was changed."
  [[ $answer == "$word" ]] || die "Cancelled. Nothing was changed."
}

check_firmware() {
  local state
  local -a variables=("$FIRMWARE_DIR"/efivars/*)
  [[ -d $FIRMWARE_DIR ]] || die "This computer does not boot with UEFI. BoxCrypt needs UEFI."
  [[ -e ${variables[0]} ]] || die "The firmware settings cannot be read."
  [[ -e $SECURE_BOOT_VAR ]] || return 0
  state=$(od -An -tu1 -j4 -N1 "$SECURE_BOOT_VAR" | tr -d ' ') || die "Secure Boot state cannot be read."
  [[ $state == 0 ]] || die "Turn off Secure Boot in the firmware settings, then start the installer again."
}

layout_field() {
  jq -r --arg label "$1" --arg field "$2" \
    '.[] | select(.label == $label) | .[$field]' "$BOXCRYPT_LAYOUT"
}

check_image_partition() {
  local label=$1 capacity=$2 image_size=$3 offset size
  offset=$(layout_field "$label" offset)
  size=$(layout_field "$label" raw_size)
  [[ $offset =~ ^[0-9]+$ && $size =~ ^[1-9][0-9]*$ ]] || die "$DAMAGED: bad layout."
  [[ $(layout_field "$label" uuid) =~ $GUID_PATTERN ]] || die "$DAMAGED: bad layout."
  ((offset + size <= image_size)) || die "$DAMAGED: the system image is too short."
  ((size <= $(numfmt --from=iec "$capacity"))) || die "$DAMAGED: the $label image is too large."
}

# Everything needed to finish the install must be proven usable before anything is erased.
check_image() {
  local image_size
  echo "Checking the installer..."
  sha256sum --check --status "$BOXCRYPT_MANIFEST" || die "$DAMAGED: the system image is not intact."
  image_size=$(stat -c %s "$BOXCRYPT_IMAGE")
  check_image_partition esp "$ESP_SIZE" "$image_size"
  check_image_partition store "$SLOT_SIZE" "$image_size"
  check_image_partition store-verity "$HASH_SIZE" "$image_size"
  [[ $(layout_field store roothash) =~ ^[0-9a-f]{64}$ ]] || die "$DAMAGED: bad layout."
}

# An active pool may be on any drive, and lsblk cannot show which, so refuse them all.
check_no_active_pools() {
  local pools
  pools=$(zpool list -H -o name) || die "Cannot read the list of storage pools."
  [[ -z $pools ]] || die "A storage pool is active: ${pools//$'\n'/ }. Nothing was changed."
}
