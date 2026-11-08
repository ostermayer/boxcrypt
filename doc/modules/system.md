# System

> **Status: hardening is built and VM-tested.** The tmpfs root builds but has not
> booted yet, and updates are still to come.

## Purpose

The hardened NixOS base that everything else sits on. NixOS 26.05 removed its hardened
profile, so these settings are our own.

## Behaviour

- Root is a tmpfs rebuilt at every boot, and `/nix` is read-only at runtime.
- Only declared paths persist, bind-mounted from `/persist`.
- No SSH, no login prompt, no sudo, no root password and no Nix daemon at runtime.
- No swap, and core dumps are off, so keys cannot reach the disk.
- Kernel settings restrict pointers, logs, ptrace, BPF, kexec and SysRq.
- Modules for unused network protocols, Bluetooth and FireWire are blocked, and Wi-Fi
  drivers are blocked until the owner chooses Wi-Fi.
- Services run sandboxed under systemd.

## Updates

A release is a signed file containing a complete system. The web UI accepts the
upload, verifies the signature against a key built into the image, imports the system
and activates it for the next boot. The previous generation stays available for
rollback.

## Edge cases

- **Update fails to boot:** the previous generation remains in the boot menu.
- **Upload is corrupt or unsigned:** rejected before anything changes.
- **Clock is wrong:** there is no internet time. The web UI compares the box's clock
  with the browser's and offers to correct it.
