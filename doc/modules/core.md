# Core

> **Status: design.** See ADR-001 and ADR-005 to ADR-008.

## Purpose

`cryptboxd` holds every secret and file in one encrypted store, and is the only
program that can open it.

## Keys

| Key | Type | Lives in | Purpose |
|---|---|---|---|
| Passphrase | Chosen by the owner | The owner's memory | Opens the keyring |
| Recovery key | age hybrid identity | Recovery kit only | Also opens the keyring |
| Content key | age hybrid identity | Keyring | Secrets and files |
| Metadata key | age hybrid identity | Keyring | Names, tags and log bodies |
| Device key | Ed25519 | Keyring | Signs this box's log |
| Certificate authority | ECDSA | Keyring | Issues the box's TLS certificate |

The keyring is stored twice: `keyring.pass.age` uses age's passphrase mode, and
`keyring.recovery.age` is encrypted to the recovery key. Changing the passphrase
rewrites only the first.

The scrypt work factor is tuned at setup to take a few seconds, and kept within what
stock `age` accepts.

## Store layout

```
/persist/store/tenants/<tenant>/
  keyring.pass.age
  keyring.recovery.age
  recipients.txt         public keys, used for deposits
  objects/ab/abcdef...   immutable, named by the SHA-256 of their bytes
  log/<device>/<seq>     signed entries, one file each
  inbox/<agent>/...      deposits waiting to be filed
```

The first release has one tenant. The layout already allows more.

## Objects

An object is a stock age file. Saving streams through age into a temporary file while
hashing it, then syncs and renames it to its hash. A file of any size therefore
passes through memory only in small chunks. Downloads stream back, with range support
from age's random-access reader.

## Log

Each box appends to its own chain:

```json
{"v":1, "alg":"ed25519", "device":"...", "seq":42, "prev":"<hash>", "body":"<age>", "sig":"..."}
```

The body, encrypted to the metadata key, records an item ID, an operation, a time, a
name, tags and the object hash. Unlocking replays all logs into an in-memory index
and verifies every signature and chain.

An object is only trusted once a signed entry refers to it, because anyone holding
a public key can create one.

## Locking

Keys and the index exist only in `cryptboxd`'s memory, which is locked against
swapping and excluded from core dumps. The box locks after 15 minutes of inactivity,
on logout, on reboot, or on request. A running transfer holds it open until it ends.

## Edge cases

- **Forgotten passphrase:** the recovery key opens the keyring and sets a new one.
- **Power loss while saving:** temporary files are discarded. A log entry is only
  written once its object is durable.
- **Disk full:** the save is refused and nothing changes.
- **Damaged object:** ZFS repairs it from the mirror. If that fails, it is restored
  from a backup.
- **Deletion:** a tombstone hides the item at once, and the object is removed after
  a retention period.
- **Locked box:** deposits still work, because they need only public keys.
