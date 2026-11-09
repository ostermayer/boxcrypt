# Safeguards

> **Status: design.** See ADR-022.

## Purpose

A secret goes into the box and does not come out unless the owner says so. Hardware
wallets such as the Coldcard work this way, and they are the model for these settings.
BoxCrypt uses only the ideas that fit a computer on a local network.

## Settings

The settings are on the **Safeguards** page in Settings. To change one, you must enter
the passphrase and a second factor again.

| Setting | What it does | Default |
|---|---|---|
| Erase after wrong passphrases | Erases the store after the number of wrong passphrases in a row that you choose, from 5 to 99 | Off |
| Erase passphrase | A second passphrase. When you enter it on the unlock page, the box erases the store | Not set |
| Unlock delay | Makes each unlock wait for a time that you choose, from 5 minutes to 28 days | Off |
| Auto-lock | Locks the box after a time with no activity, from 1 minute to 24 hours | 15 minutes |
| Ask again to reveal | Asks for the passphrase and a second factor again before the box shows a secret or sends a file | Off |
| Sealed items | Marks a key so that the box can sign with it but never shows or exports it | Per item |
| USB ports | Allows your backup drives and enrolled security keys, also a keyboard, or nothing | Backup drives and enrolled security keys |
| Test safeguards | The next unlock attempt tells you what would have happened and does nothing. It works once, and a banner shows while it is on | |

## Erase after wrong passphrases

### Who can make a guess

A person must hold a hardware wallet to guess its PIN. BoxCrypt is on a network. If every
device could guess, a guest or an infected laptop could erase the box.

Each login needs a second factor, and the box checks it first. See
[two-factor login](two-factor.md). A device without a valid second factor cannot make a
passphrase guess, so it cannot use up tries or start an erase.

- Each guess needs a new code, or a new touch of a security key.
- A wrong second factor never counts.
- If you lose every second factor, use the recovery kit in any browser. The recovery key is
  too long to guess. Any device can try it, with a rate limit, and a try does not count.

### How the count works

Only one attempt runs at a time, for the whole box. Each attempt has three steps:

1. Write the attempt and the new count to disk. If the write fails, refuse the attempt.
2. Check the passphrase.
3. Write the result. A correct passphrase sets the count to zero.

These rules apply:

- A restart does not change the count, and cutting the power does not save a try.
- If the count reaches the limit and the last attempt has no result, because the power
  failed, the box does not erase. It accepts only the recovery key.
- If the count cannot be read, or is damaged, the box accepts only the recovery key.
- The count has its own reserved space, so a full pool cannot stop the writes.
- The same wrong passphrase twice in a row counts once, so a double click does not cost a
  try. The box makes this comparison in memory only.
- The unlock page shows the tries that remain, and warns when Caps Lock is on.
- The wait between tries increases after each wrong passphrase.
- Agent tokens and setup codes never reach the passphrase check, and never count.
- In an unlocked session, three wrong passphrases lock the box. They never erase it, so a
  stolen session cannot start an erase.

### What the erase does

An erase deletes the keys and the pool. It is not a forensic wipe. Overwriting a file does
not work on ZFS or an SSD, destroying a pool does not remove its data blocks, and discard
depends on the drive.

1. Write a marker on the boot partition, outside the pool. It records each step, and a hash
   of the recovery key.
2. Remove the keys from memory.
3. With a TPM, destroy the key that the TPM holds.
4. Overwrite the keyring files, destroy the pool and discard the storage partition on each
   drive.
5. Restart. Early boot finishes any step that is not done, then makes an empty pool before
   it mounts `/persist`.
6. Wait for the recovery key or a new install. The box does not open first-run setup,
   because anyone on the LAN could claim it.

The erase removes the store, the internal backup and add-on app data. The operating system
stays. USB backups and mirror boxes are not touched, so you can restore from them.

### Turning it on

The guided steps check that you tested the recovery kit. They warn
you if you have no USB backup, because an erase would remove the only copy. You then choose
the number and type `ERASE`.

### With a TPM

A TPM can also protect a copy of the drives. This works only for keys that were never in a
passphrase-only keyring:

- A box that you set up with erase on has this from the start.
- On an existing box, the guided steps offer a rebuild: new keys, a new pool and new
  backups. Deleting the old keyring is not enough, because ZFS and SSDs keep old blocks.
  Older backups can still be guessed against, so destroy them.
- Without a rebuild, erase still works, with the limits of a box that has no TPM.

On a box with this protection:

- The TPM holds an essential part of the key and releases it only for the correct
  passphrase. The TPM counts wrong tries and has its own lockout.
- There is no passphrase-only keyring on the drives or in backups. No file can confirm a
  passphrase guess.
- The recovery key is the only way to open a copy of the drives or a backup, so a restore
  to a new computer needs the recovery kit.
- Clearing the TPM, resetting the firmware or replacing the mainboard also makes the
  recovery kit necessary.

Without a TPM, the passphrase-only keyring stays.

### Limits

- Without a TPM and a rebuild, this stops guessing at the box only. A person who copies the
  drives can guess against the copy with no limit, so use a long passphrase.
- A person who can write to the drives can reset the count, or change the erase marker. That
  person could also destroy the data directly. The TPM's own lockout still applies.
- The erase is best effort in every case. Data can stay on a drive, and a person with the
  recovery kit can read what remains.
- A person with your security key or authenticator secret can use up the tries.
- An erase does not hide that it happened. A person who forces you to unlock will see an
  empty box.

## Erase passphrase

The box accepts it only on the locked unlock page, from the same places as the passphrase.
Every other passphrase field refuses it. It must be different from the passphrase, and the
box checks this when you set either one.

The box checks it in the same time as a normal passphrase. Its table has a fixed size and
random data in unused slots, so the disk does not show whether one is set.

## Unlock delay

The delay counts while the box is on. A restart sets it back to the full time, so a restart
never shortens it. It needs no clock, so it works on a device with no network time.

## Sealed items

The box uses a sealed key to sign and never shows or exports it. A backup holds an
encrypted copy, so a restore brings the key back.

## Not used

Wallet functions, keypad tricks and self-destruct of a secure element do not apply. A
standard computer has no secure element. Decoy passphrases stay on the
[roadmap](../roadmap.md).

## Edge cases

- **Power fails during an erase:** the next start finishes it from the marker.
- **Restore from a backup:** safeguards do not come back with the data. The wizard asks you
  to set them again.
- **Pool full:** the count still works, because its space is reserved.
- **Power fails during a correct unlock at the limit:** the box accepts only the recovery
  key. This stops a person who cuts the power to save a try.
