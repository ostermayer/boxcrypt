# Apps

> **Status: design, after 1.0.** See ADR-017.

## Purpose

Let owners add an existing password manager, in the style of an app store but limited
to one subject. The catalog is as narrow as bitcoinix: if an app does not keep secrets,
it does not belong.

## Rules for the catalog

An app must:

1. Store or manage secrets
2. Work with no internet connection
3. Run sandboxed and listen on loopback only
4. Be actively maintained, with a way to report security problems
5. Be packaged for NixOS

## Catalog

| App | For | State |
|---|---|---|
| Vaultwarden | Bitwarden apps and extensions | First. NixOS service exists |
| OpenBao | Developer and infrastructure secrets | Candidate. NixOS service exists |
| KeePass file sharing | KeePassXC users, by serving a `.kdbx` file on the LAN | Candidate. Needs a small WebDAV service |
| Passbolt | Teams | Candidate. Needs packaging, and multi-user support on the box |
| Psono | Self-hosted password manager | Candidate. Needs packaging |

KeeWeb was considered and rejected, because its last release was in 2021.

## How an app works

Each app is one NixOS module in `modules/apps/` that declares a name, a description, a
LAN port, a loopback port and its data paths.

- **Install:** the app already ships inside the image, stopped. Installing is one click
  and needs no internet.
- **Running:** `cryptboxd` terminates TLS on the app's LAN port and proxies to its
  loopback port. Disabling the app closes the port.
- **Isolation:** each app has a sandboxed service and its own dataset, cannot read the
  store and cannot reach anything outside the box.
- **LAN only:** apps follow the same firewall rules as the box, so they work only from
  the owner's local network.
- **Accounts:** each app has its own login. Locking the box does not stop an app.
- **Backups:** app data is encrypted to the content key and copied with everything else.
- **Updates:** apps update with the system image.
- **Removal:** requires confirmation, and deletes that app's data.

## Vaultwarden

Runs with signups closed after the first account, and with organizations, invitations,
Send, emergency access, SSO, icon downloads and the admin panel off. Most of its 2026
security advisories concern those features.

Bitwarden phone apps must trust the box's private certificate, which older reports say
is unreliable on Android. That needs testing before we promise it.

## Edge cases

- **Port conflict:** ports are fixed per app in the catalog.
- **App is compromised:** it can reach only its own data.
- **Security advisory for an app:** a new system image is released, or the app is
  disabled by default until one is.
