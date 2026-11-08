# Web UI

> **Status: design.** See ADR-010 and ADR-011.

## Purpose

The main way people use the box. It is served by `cryptboxd` on the local network
only.

## Pages

| Path | Access | Purpose |
|---|---|---|
| `/setup/*` | Setup code, first run only | Wizard, or restore |
| `/unlock` | Public | Enter the passphrase |
| `/` | Unlocked | Home |
| `/items` | Unlocked | Passwords, notes and keys |
| `/files` | Unlocked | Files of any size |
| `/backup` | Unlocked | Backup drives and recovery kit test |
| `/apps` | Unlocked | Add-on apps |
| `/settings` | Unlocked | Passphrase, updates, clock, address |
| `/ca.crt` | Public | Certificate for devices to trust |

## Design language

Umbrel's visual style is the guide. We follow the feel and write everything ourselves,
with no Umbrel code, assets or branding.

- Inter type, self-hosted
- A dark wallpaper behind frosted-glass panels with background blur
- Soft inner highlights and deep drop shadows
- Generous rounded corners
- A dock for moving between sections
- One accent colour

Accessibility is required: visible keyboard focus, sufficient contrast, labels for
screen readers, and solid backgrounds under `prefers-reduced-transparency`.

## Language

Say Secrets, Files, Passphrase, Recovery kit and Backup drive. Never show ZFS, Nix,
TLS or generation numbers in normal use.

## Security

- Requests with an unexpected `Host` are refused, which stops DNS rebinding.
- Session cookies are `Secure`, `HttpOnly` and `SameSite=Strict`.
- Pages load no external assets, under a strict CSP with no inline scripts.
- Failed unlocks are rate limited.
- The setup code works once, and setup closes when the wizard finishes.

## Certificates

The box creates its own certificate authority at first run and issues a certificate
for its address, within the 825-day limit iOS enforces. Renewal happens while
unlocked, because the authority's key lives in the keyring.

The first visit shows a browser warning. The owner compares the fingerprint with the
one on the box's screen, and the wizard then explains how to trust the certificate on
each device.

## Edge cases

- **Upload larger than RAM:** streamed, and not held in memory.
- **Tab left open:** when the box locks, the page returns to `/unlock` and shows no
  cached secrets.
