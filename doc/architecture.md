# Architecture

> **Status: mostly design.** The base system is built and VM-tested. See
> [the roadmap](roadmap.md).

cryptbox is a purpose-built operating system, built on NixOS, for keeping secrets
safe over the long term. It turns an ordinary PC into a vault on the local network
with no route to the internet.

## Principles

- **One job.** Keep secrets. Anything else belongs on another machine.
- **Locked by default.** Secrets are readable only while the owner has unlocked the
  box, and every reboot locks it.
- **Readable in 30 years.** Every stored object is a stock age file, so the data
  does not depend on this project surviving.
- **No custom cryptography.** The core arranges audited-by-use primitives and
  invents none.
- **Copies are safe.** Backups and mirrors are ciphertext and need no keys.
- **One image, any machine.** The system holds nothing machine-specific.
- **The owner never sees the machinery.** No Nix, ZFS or shell in normal use.

## System

```
   Browser on the LAN        Agent on the LAN        Screen on the box
          |                        |                        |
          |  HTTPS 443             |  HTTPS 443             |  TUI over a
          v                        v                        v  Unix socket
   +-----------------------------------------------------------------+
   | cryptboxd   TLS, web UI, API, keys in RAM only while unlocked   |
   +-----------------------------------------------------------------+
          |                                         |
          v                                         v
   Encrypted store                           Add-on apps, off by default
   /persist/store on a ZFS mirror            isolated, each with its own data
          |
          v
   Backup drives, and later other boxes
```

The system lives in a read-only Nix store. The root filesystem is a tmpfs rebuilt
at every boot, so only declared paths under `/persist` survive.

## Module map

| Module | Location | Purpose | Doc |
|---|---|---|---|
| System | `modules/security.nix` | Hardened base, tmpfs root | [system](modules/system.md) |
| Network | `modules/network.nix` | LAN-only networking, firewall | [network](modules/network.md) |
| Storage | `modules/storage.nix` | ZFS mirror, boot redundancy | [storage](modules/storage.md) |
| Core | `src/cryptboxd/` | Encrypted store, keys, API | [core](modules/core.md) |
| Web UI | `src/cryptboxd/web/` | The local web interface | [web-ui](modules/web-ui.md) |
| TUI | `src/cryptboxd/tui/` | The text interface | [tui](modules/tui.md) |
| Backup | `src/cryptboxd/backup/` | Copies of the store, restore | [backup](modules/backup.md) |
| Installer | `modules/presets/installer.nix` | USB image | [installer](modules/installer.md) |
| Apps | `modules/apps/` | Optional add-on apps | [apps](modules/apps.md) |
| Agents | later | Deposits, approved reads, signing | [agents](modules/agents.md) |
| Sync | later | Mirroring between boxes | [sync](modules/sync.md) |

## Data flow

**First run.** The box's screen shows an address, a setup code and a certificate
fingerprint. The owner opens the address, enters the code and chooses a passphrase.
The wizard creates the keys, proves the recovery kit works and sets up a backup
drive.

**Unlock.** The passphrase opens the keyring, which is held in RAM. Inactivity,
logging out or a reboot locks the box and discards it.

**Saving.** The core encrypts while it receives, so large files never sit on disk
in plaintext. It names the object after its hash, then records it in a signed log.

**Backup.** Objects the drive lacks are copied across. No key is needed, so backups
run while the box is locked.

**Restore.** A fresh install offers restore on its first screen. It copies the store
back, and the owner's passphrase opens it.

**Update.** The owner uploads a signed release file. The box verifies it and
installs it as a new system generation, keeping the old one for rollback.

## What is on disk

| Data | Protection |
|---|---|
| Secrets and files | Encrypted, needs the passphrase or recovery key |
| Names, tags and history | Encrypted, needs the passphrase or recovery key |
| Keyring | Encrypted, needs the passphrase or recovery key |
| Number, sizes and dates of objects | Visible |
| TLS server key, network settings and any Wi-Fi password | Visible, because the unlock page must work while locked |

## Threat model

| Threat | Result | Defence |
|---|---|---|
| Attacker on the LAN | Must know the passphrase | One port, rate limits, locked by default |
| Malicious website in a LAN browser | Blocked | Host allowlist, strict CSP, same-site cookies |
| Attacker in radio range | No radio to attack unless the owner chose Wi-Fi | Wi-Fi off by default, wired recommended |
| Compromised agent | Can only deposit | Agents hold public keys and scoped tokens |
| Stolen box or drive | Ciphertext, open to passphrase guessing | Memory-hard KDF, strong passphrase required |
| Someone hosting a mirror | Ciphertext only | Mirrors never receive keys |
| Recorded ciphertext, future quantum computer | Stays encrypted | Hybrid post-quantum keys |
| Tampered backup or mirror | Detected | Hash-named objects, signed logs |
| Compromised box while locked | Could capture the next unlock | Small surface, read-only system |
| Compromised box while unlocked | Everything readable | Auto-lock, small surface |
| Compromised add-on app | Limited to that app's own data | Isolation, no access to the store |
| Drive failure | Keeps running | N-way mirror |
| Box destroyed | Restore to new hardware | Backups kept elsewhere |
| Forgotten passphrase | Recovery key opens the keyring | Lose both and the data is gone, by design |

cryptbox has no secure element or tamper detection, and it cannot detect an attacker
who modifies the box and waits for the owner to unlock it.

## Hardware

x86-64, UEFI and 4 GB of RAM or more, with wired Ethernet or Wi-Fi. Wired is
recommended, and Bluetooth is disabled. ARM boards are future work.
