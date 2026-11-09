# Architecture

> **Status: mostly design.** The base system is built and VM-tested. See
> [the roadmap](roadmap.md).

BoxCrypt is a computer safe deposit box. Drop files onto the box and they cannot leave.
You open them with your passphrase, from a device on your local network. BoxCrypt is an
operating system, built on NixOS, that keeps secrets over the long term with no route to
the internet.

## Guiding principle

Usability with high security. A control that owners cannot use does not protect them. When
the two seem to conflict, look for a design that gives both before giving up either one.

## Principles

- **One job.** Keep secrets. Anything else belongs on another machine.
- **Verified from build to boot.** The goal is that the box cannot reach the internet,
  and nobody can change that without the owner knowing. Part of this is built. See
  [integrity](modules/integrity.md).
- **Locked by default.** Secrets are readable only while the owner has unlocked the
  box, and every reboot locks it.
- **Readable in 30 years.** Every stored object is a stock age file, so the data
  does not depend on this project surviving.
- **No custom cryptography.** The core arranges audited-by-use primitives and
  invents none.
- **Copies are safe.** Backups and mirrors are ciphertext and need no keys.
- **One image, any machine.** The system holds nothing machine-specific.
- **The owner never sees the machinery.** No Nix, ZFS or shell in normal use.
- **Beautiful, intuitive and secure.** The web UI and TUI are the product, and none of
  those three can be traded away for the others.

## System

```
   Browser on the LAN        Agent on the LAN        SSH or a screen, optional
          |                        |                        |
          |  HTTPS 443             |  HTTPS 443             |  TUI over a
          v                        v                        v  Unix socket
   +-----------------------------------------------------------------+
   | boxcryptd   TLS, web UI, API, keys in RAM only while unlocked   |
   +-----------------------------------------------------------------+
          |                                         |
          v                                         v
   Encrypted store                           Add-on apps, off by default
   /persist/store on a ZFS mirror            isolated, each with its own data
          |
          v
   Backup drives, and later other boxes
```

The system lives in read-only partitions verified block by block. The root filesystem
is a tmpfs rebuilt at every boot, so only declared paths under `/persist` survive.

## Module map

| Module | Location | Purpose | Doc |
|---|---|---|---|
| System | `modules/security.nix` | Hardened base, tmpfs root | [system](modules/system.md) |
| Network | `modules/network.nix` | LAN-only networking, firewall | [network](modules/network.md) |
| Storage | `modules/presets/zfs.nix` | ZFS mirror, boot redundancy | [storage](modules/storage.md) |
| Integrity | `modules/presets/appliance.nix` | Verified boot, proof for the owner | [integrity](modules/integrity.md) |
| Checks | `src/boxcryptd/checks/` | Shows the owner that the software is genuine and the data is intact | [checks](modules/checks.md) |
| Core | `src/boxcryptd/` | Encrypted store, keys, API | [core](modules/core.md) |
| Web UI | `src/boxcryptd/web/` | The local web interface | [web-ui](modules/web-ui.md) |
| TUI | `src/boxcryptd/tui/` | The text interface | [tui](modules/tui.md) |
| Backup | `src/boxcryptd/backup/` | Copies of the store, restore | [backup](modules/backup.md) |
| Installer | `src/installer/` | USB image | [installer](modules/installer.md) |
| Apps | `modules/apps/` | Optional add-on apps | [apps](modules/apps.md) |
| Agents | later | Deposits, approved reads, signing | [agents](modules/agents.md) |
| Sync | later | Mirroring between boxes | [sync](modules/sync.md) |

Paths under `src/boxcryptd/` and `modules/apps/` are planned and do not exist yet. See the
[documentation index](README.md) for the state of each module.

## Data flow

**First run.** The installer shows a setup code and a certificate fingerprint. After that
the device runs without a screen. The owner opens `https://boxcrypt.local`, enters the code and chooses a passphrase.
The wizard creates the keys, proves the recovery kit works and sets up a backup
drive.

**Unlock.** The passphrase opens the keyring, which is held in RAM. Inactivity,
logging out or a reboot locks the box and discards it.

**Saving.** The core encrypts while it receives, so large files never sit on disk
in plaintext. It names the object after its hash, then records it in a signed log.

**Backup.** New objects are copied to the internal backup and to any attached USB backup
drive. No key is needed, so backups run while the box is locked.

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
| Attacker on the LAN | Must know the passphrase | One web port, locked by default, login rate limits in `boxcryptd` |
| Malicious website in a LAN browser | Blocked | Host allowlist, strict CSP, same-site cookies |
| Attacker in radio range | No radio to attack unless the owner chose Wi-Fi | Wi-Fi off by default, wired recommended |
| Compromised agent | Can only deposit | Agents hold public keys and scoped tokens |
| Stolen box or drive | Ciphertext, open to passphrase guessing | Memory-hard KDF, strong passphrase required |
| Someone hosting a mirror | Ciphertext only | Mirrors never receive keys |
| Recorded ciphertext, future quantum computer | Stays encrypted | Hybrid post-quantum keys |
| Tampered backup or mirror | Detected | Hash-named objects, signed logs |
| Malware rewrites the OS or firewall on disk | Fails to boot, or the browser refuses it and the proof fails | Verified boot, TLS key held in the TPM, signed TPM quote |
| Malicious or altered release | Refused, or exposed by a rebuild | Signatures, public log, reproducible builds |
| Live kernel compromise | Could change the rules until reboot | No network privileges for exposed programs, router block |
| Compromised box while locked | Could capture the next unlock | Small surface, read-only system |
| Compromised box while unlocked | Everything readable | Auto-lock, small surface |
| Compromised add-on app | Limited to that app's own data | Isolation, no access to the store |
| Drive failure | Keeps running | N-way mirror |
| Box destroyed | Restore to new hardware | Backups kept elsewhere |
| Forgotten passphrase | Recovery key opens the keyring | Lose both and the data is gone, by design |

BoxCrypt has no secure element or tamper detection, and it cannot detect an attacker
who modifies the box and waits for the owner to unlock it.

## Hardware

x86-64, UEFI and 4 GB of RAM or more, with wired Ethernet or Wi-Fi. Wired is
recommended, and Bluetooth is disabled. A TPM 2.0 is strongly recommended, because
without one the box cannot prove its state. ARM boards, Raspberry Pi 5 and Mac minis are
planned as separate hardware families (ADR-019).
