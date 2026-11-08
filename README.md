# cryptbox

A purpose-built operating system for keeping secrets safe over the long term. Flash
it onto an ordinary PC and that PC does one thing: hold your passwords, keys and
files, encrypted, on your local network, with no route to the internet.

> **Status: early development.** Nothing is installable yet, and the software has
> not been audited. See [the roadmap](doc/roadmap.md).

## What you get

- A web interface served only on your local network, and a text interface on the
  box itself
- Passwords, notes, keys and files of any size in one encrypted store
- Locked whenever you are not using it, and after every reboot
- Mirrored drives by default when you have more than one
- Automatic backups that restore onto a new box
- Your data in the open [age](https://age-encryption.org) format, so it can outlive
  this project
- Optional add-on apps, such as Vaultwarden, for people who prefer an existing
  password manager

## What it isn't

- A general home server. Add-on apps are limited to keeping secrets.
- A hardware security module. An ordinary PC has no secure element or tamper
  detection.

## Repository

| Path | Contents |
|---|---|
| `modules/` | NixOS modules that define the system |
| `modules/apps/` | Add-on apps |
| `pkgs/` | Nix packages |
| `src/` | `cryptboxd`, the core |
| `tests/` | Unit tests and VM tests |
| `doc/` | Architecture, decisions, roadmap and setup |

## Documentation

- [Architecture](doc/architecture.md)
- [Setup](doc/setup.md)
- [Decisions](doc/decisions.md)
- [Roadmap](doc/roadmap.md)
