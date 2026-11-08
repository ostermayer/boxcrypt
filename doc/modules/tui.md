# TUI

> **Status: design.** See ADR-012.

## Purpose

A text interface with the same abilities as the web UI, for the box's own screen.

## Behaviour

- Runs full-screen on the box's console in place of a login prompt. There is no
  shell.
- Talks to `cryptboxd` over a Unix socket, so it adds no network exposure.
- Before setup it shows the address, setup code and certificate fingerprint.
- With no cable connected, it offers to join a Wi-Fi network.
- Afterwards it shows status while locked, and accepts the passphrase to unlock.
- Works with a keyboard alone.

## Later

SSH delivery, opt-in and off by default. It would allow only the TUI through a forced
command, and would open a second port while enabled.

## Edge cases

- **No monitor attached:** the web UI covers everything except reading the setup
  code, so the first boot needs a screen.
- **Secrets on screen:** hidden until requested, and cleared when the box locks.
