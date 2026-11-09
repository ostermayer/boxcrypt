# TUI

> **Status: design.** See ADR-012.

## Purpose

A text interface with the same abilities as the web UI. Most owners run the device without
a screen and use the web UI, so the TUI is optional.

## Behaviour

- Runs over SSH when the owner turns that on, or full-screen on a connected screen.
  Neither gives a shell.
- Talks to `boxcryptd` over a Unix socket, so it adds no network exposure.
- Afterwards it shows status while locked, and accepts the passphrase to unlock.
- Has a Checks screen with the same results and text as the web UI. See [checks](checks.md).
- Works with a keyboard alone.
- Each login needs a second factor. See [two-factor login](two-factor.md).
- `?` opens the help note for the selected item, and the status line shows its one-line
  explanation. The text comes from the same catalog as the web UI.

## SSH

SSH is off by default, because it opens a second port. The owner turns it on in the web UI
and adds a public key. A forced command allows only the TUI. A key of type `sk-` on a
security key counts as the second factor. Any other key type also needs an authenticator
code.

## Edge cases

- **No screen attached:** this is the normal case. The web UI does everything.
- **Secrets on screen:** hidden until requested, and cleared when the box locks.
