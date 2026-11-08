# Storage

> **Status: design.** See ADR-014.

## Purpose

Keep the box running through drive failures with no choices asked of the owner.

## Layout

The installer erases every internal drive. USB drives are never touched.

| Drives found | Result |
|---|---|
| Two or more NVMe or SATA | One N-way ZFS mirror across all of them |
| One NVMe or SATA | Single drive, with a warning and two copies of data |
| Only eMMC | Single drive on eMMC, with a warning |

eMMC is not mirrored alongside NVMe or SATA drives because it is slower and wears
faster.

Each mirrored drive has:

| Partition | Label | Purpose |
|---|---|---|
| 1 | `CB-ESP` | Boot files, 1 GiB, kept identical across drives |
| 2 | `CB-ZFS` | Member of pool `cbpool` |

| Dataset | Mount | Contents |
|---|---|---|
| `cbpool/nix` | `/nix` | System store |
| `cbpool/persist` | `/persist` | Encrypted store and box configuration |
| `cbpool/apps/<name>` | `/persist/apps/<name>` | One per enabled add-on app |

Boot files are installed on the UEFI removable path, so any drive can boot without
firmware entries. After each update, a service copies them to every boot partition it
finds.

## Maintenance

- A monthly scrub repairs silent corruption.
- ZFS events appear on the status page as "Drive 2 needs replacing".
- Replacement is guided from the web UI.

## Edge cases

- **Mixed sizes:** capacity is that of the smallest drive.
- **Used drives with old pool labels:** cleared by the installer after confirmation.
- **eMMC hardware boot partitions:** skipped.
- **A mirror is not a backup:** deletions, theft and fire reach every drive. See
  [backup](backup.md).
