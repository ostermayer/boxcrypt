# Backup

> **Status: design.** See ADR-009.

## Purpose

Make losing the box an inconvenience instead of a disaster.

## Recovery kit

Created once during setup, and printed or saved by the owner. It holds the **recovery
key**, which opens the keyring if the passphrase is forgotten. The wizard proves it
works before setup finishes. It also holds the **device public key**, so that
`boxcrypt verify` can check a backup on a new computer. Keep it apart from the box
and the backup drives. Losing both the passphrase and the kit loses the data.

## Backup

BoxCrypt keeps two kinds of backup. Both have the same layout as the store.

| Backup | Protects against | Does not protect against |
|---|---|---|
| Internal, on the `bcpool/backup` dataset | Deleted items, mistakes and damaged data | Theft, fire and loss of all drives |
| USB drive labelled `BOXCRYPT-BAK` | Loss of the whole device, if you keep the drive in another place | Changes made after the last copy |

The internal backup runs after changes and at least daily. It needs no action from the
owner. The USB backup runs at the same times, when the drive is attached.

Each backup works from one ZFS snapshot, so that it copies one consistent state.

1. Copy every object the drive lacks, under a temporary name, then rename it.
2. Copy new log entries, `recipients.txt` and the wrapped keyrings.
3. Copy add-on app data, encrypted to the content key.
4. Verify what was copied against its hash.
5. Copy the signed inventory last. A backup without its inventory is not complete.

The operating system is not backed up, because the image supplies it. Everything on
the drive is already encrypted, so a backup needs no key and runs while locked.

## Verification

| Check | When | Proves |
|---|---|---|
| Hash every new object | Every backup | New copies are intact |
| Hash the whole drive | Monthly | Nothing has decayed |
| Decrypt and verify logs | When unlocked, monthly | The backup's log opens with the current keys |
| Decrypt a sample of files | When unlocked, monthly | Those files open and match their content hashes |
| Recovery kit test | Prompted every 6 months | The kit still opens the keyring |

The results appear on the [Checks](checks.md) page. Only a full restore shows that everything
opens.

## Second copy

The web UI records when each backup drive was last seen, and prompts the owner if no
second drive has appeared for 30 days.

## Restore

Offered on the first screen of a fresh install, behind the setup code. It copies the
store back, checks every object against its hash and asks for the passphrase, or for the
recovery key if the box had TPM protection. Logs and
keyring come back first, so secrets are usable before large files finish copying. The
box keeps the same address and certificate authority, so devices that trust the box still
trust it. It issues a new key and certificate, because a new TPM cannot open the old key. The
Checks page shows **Restoring** until the copy finishes. The owner then runs `boxcrypt verify`
to enroll the new computer.

## Edge cases

- **Damaged object on the backup drive:** the monthly check finds it by its hash. The next
  backup copies that object again from the store.
- **Erase after wrong passphrases:** the internal backup is erased with the store. USB
  backups are not. See [safeguards](safeguards.md).
- **Backup drive too small:** the box says so and shows the size needed.
- **Drive removed mid-copy:** temporary files are ignored, and the next run resumes.
- **New drive:** formatting requires explicit confirmation showing its model and size.
- **Passphrase changed:** older backups keep the old wrapped keyring until the next
  run, and the recovery key opens both.
- **Tampered backup:** altered objects fail their hash, and forged log entries fail
  their signatures.
