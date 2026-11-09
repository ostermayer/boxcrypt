# BoxCrypt

BoxCrypt is a computer safe deposit box. Drop files onto the box and they cannot leave.
You open them with your passphrase, from a device on your local network. BoxCrypt is an
operating system based on NixOS. It runs on a standard computer and has no route to the
internet.

> **Status:** Early development. You cannot install it yet. It has no independent security
> audit. See the [roadmap](doc/roadmap.md).

## Design

- A web interface on your local network, and a text interface on the device
- One encrypted store for passwords, notes, keys and files of any size
- The device locks when you are not using it, and after each restart
- Mirrored drives when the computer has more than one drive
- Automatic backups on an internal drive and on a USB drive
- Restore to a new computer from a backup
- A required second factor for each login: a YubiKey or an authenticator app
- An optional erase after a number of wrong passphrases
- Data in the standard [age](https://age-encryption.org) format
- Optional add-on apps, such as Vaultwarden

## Limits

- BoxCrypt is not a general home server. Add-on apps must keep secrets.
- A standard computer has no secure element and no tamper detection.

## Repository

| Path | Contents |
|---|---|
| `modules/` | NixOS modules that define the system |
| `pkgs/` | Nix packages |
| `src/` | Source code |
| `tests/` | Virtual machine tests |
| `doc/` | Documentation. Start at the [index](doc/README.md). |

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE). If you distribute a changed version, you must
publish its source. You can sell computers with BoxCrypt installed. You must give each buyer
the source and what they need to install a changed version.
