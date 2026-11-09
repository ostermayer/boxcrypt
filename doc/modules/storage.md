# Storage

> **Status: mirrored drives are built and tested.** Drive alerts are not. See ADR-014.

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
| 1 | `BC-ESP` | Signed kernel images for both system slots, 1 GiB |
| 2, 3 | `BC-SYS-A`, `BC-VER-A` | System slot A and its dm-verity hashes |
| 4, 5 | `BC-SYS-B`, `BC-VER-B` | System slot B and its dm-verity hashes |
| 6 | `BC-ZFS` | Member of pool `bcpool` |

System slots are identical across drives and are never written while in use. An update
writes to the inactive slot. See [integrity](integrity.md).

| Dataset | Mount | Contents |
|---|---|---|
| `bcpool/persist` | `/persist` | Encrypted store and box configuration |
| `bcpool/backup` | `/persist/backup` | Internal backup, with older copies |
| `bcpool/apps/<name>` | `/persist/apps/<name>` | One per enabled add-on app |

Kernel images are installed on the UEFI removable path, so any drive can boot without
firmware entries. Each update writes to every drive.

## Maintenance

- A scrub runs each month and one hour after each start. A box that you keep switched off
  can miss a calendar date, so each start also runs one. A scrub continues after a restart
  from its last checkpoint, which ZFS writes about every two hours.
- ZFS events appear on the status page as "Drive 2 needs replacing".
- Replacement is guided from the web UI.

## Silent damage (bit rot)

Drives can change stored data with no error. ZFS stores a checksum for each block. It
compares the checksum at each read and at each scrub.

| Where | What finds damage | What repairs it |
|---|---|---|
| Store, internal backup, app data | ZFS checksum | ZFS rewrites the block from another drive. With one drive, from its second copy |
| System partitions | dm-verity, at each read | Nothing yet. The box refuses the block |
| Boot files | Nothing yet | Nothing yet |
| USB backup | Hash of each object, each month | The next backup copies the object again |
| Memory | Nothing, unless the computer has ECC RAM | Nothing |

A VM test damages a drive and proves the repair, for a mirror and for one drive. One drive
survives bad blocks but not a failed drive. ZFS cannot find an error that happens in memory
before it makes the checksum, so ECC RAM is better when the computer supports it.

The owner sees the result of each scrub on the [Checks](checks.md) page.

## Edge cases

- **Drive failure while running:** your data keeps working from the other drives. If the
  failed drive was serving the system, the box needs a restart to carry on from another.
- **A failing drive that is still present:** mirrored drives share system partition IDs, so
  the box may keep picking that drive. Remove it and restart.
- **Mixed sizes:** capacity is that of the smallest drive.
- **Used drives with old pool labels:** cleared by the installer after confirmation.
- **eMMC hardware boot partitions:** skipped.
- **A mirror is not a backup:** deletions, theft and fire reach every drive. See
  [backup](backup.md).
