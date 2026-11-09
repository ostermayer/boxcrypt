# BoxCrypt documentation

BoxCrypt is a computer safe deposit box. Drop files onto the box and they cannot leave.
You open them with your passphrase, from a device on your local network. BoxCrypt is an
operating system based on NixOS.

## Where to start

| To learn | Read |
|---|---|
| How the system fits together | [Architecture](architecture.md) |
| How to install or build it | [Setup](setup.md) |
| What is built and what is planned | [Roadmap](roadmap.md) |
| Why the design is the way it is | [Decisions](decisions.md) |
| How the system is tested and reviewed | [Testing](testing.md) |
| What a technical term means | [Glossary](glossary.md) |

## Modules

| Module | Purpose | State |
|---|---|---|
| [System](modules/system.md) | Hardened base system | Built and tested |
| [Network](modules/network.md) | Local network only, no route out | Built and tested |
| [Storage](modules/storage.md) | Mirrored drives | Built and tested |
| [Installer](modules/installer.md) | Erases the drives and installs the system | Program built, USB image not built |
| [Integrity](modules/integrity.md) | Proves that the system has no changes | Partly built |
| [Checks](modules/checks.md) | Shows the owner that the software is genuine and the data is intact | Design |
| [Core](modules/core.md) | Encrypted store and keys | Design |
| [Two-factor login](modules/two-factor.md) | Security key or authenticator app for each login | Design |
| [Safeguards](modules/safeguards.md) | Erase after wrong passphrases and other settings | Design |
| [Web UI](modules/web-ui.md) | Interface on the local network | Design |
| [TUI](modules/tui.md) | Text interface on the device | Design |
| [Backup](modules/backup.md) | Copies and restore | Design |
| [Apps](modules/apps.md) | Optional add-on apps | Design |
| [Agents](modules/agents.md) | Deposits and signing for agents | Design |
| [Sync](modules/sync.md) | Mirrors between devices | Design |

Each module document starts with its state. "Built and tested" means tested in virtual
machines. Nothing has run on real hardware yet.

## How to change these documents

- Update the module document when you change its code.
- Add a record to [Decisions](decisions.md) when you make a tradeoff.
- Write short sentences in the active voice. Use Simplified Technical English.
- Do not add real addresses, hostnames, device names or keys. This repository is public.
