# Roadmap

## Current state

The design is written. The base system builds and passes its VM tests. Nothing has
booted from a real disk or been tested on real hardware.

## Milestones

### M1: The system boots
- [x] Flake with a hardened base
- [x] LAN-only network rules
- [x] VM test proving only the allowed port answers and outbound traffic is dropped
- [x] Full appliance system builds
- [x] Wi-Fi stays off by default and keeps the same limits when chosen, proven in a VM
- [ ] Tmpfs root and ZFS boot work from a real disk, proven with the installer in M2

### M2: It installs
- [ ] USB installer that discovers drives and builds the mirror
- [ ] Each drive boots alone, proven in a VM by removing drives
- [ ] First install on real hardware
- [ ] Lock kernel module loading once the needed drivers are known

### M3: The core works
- [ ] Keyring, passphrase unlock, recovery key and auto-lock
- [ ] Objects, signed logs and index
- [ ] Secrets and files, with streaming for files larger than RAM
- [ ] Stock `age` can recover everything, proven by a test

### M4: A person can use it
- [ ] First-run wizard with setup code
- [ ] Web UI in the design language
- [ ] TUI on the box's screen, including joining a Wi-Fi network
- [ ] Certificate install guide per device type

### M5: It survives losing the box
- [ ] Automatic backups to USB, verified by hash
- [ ] Restore, proven on different hardware
- [ ] Recovery kit test

### M6: 1.0
- [ ] Signed offline updates and rollback
- [ ] Drive failure alerts and guided replacement
- [ ] Reproducible builds and published signatures
- [ ] **Independent security audit**

### M7: Add-on apps
- [ ] App catalog in the web UI
- [ ] Vaultwarden
- [ ] Further password managers, see [apps](modules/apps.md)

## Feature parity with Arca

Everything Arca describes is on the roadmap unless listed as not possible.

| Area | Capability | Target |
|---|---|---|
| Storage | Per-object encryption, separate content and metadata keys | M3 |
| Storage | Search, tags and metadata | M4 |
| Storage | Import and export tools | Later |
| Storage | Cloud import and export | Later |
| Access | Web UI and text interface | M4 |
| Access | Text interface over SSH | Later |
| Access | WireGuard, Tailscale and Tor, opt-in | Later |
| Access | Scoped setup, enrollment and recovery tokens | Later |
| Recovery | Replacement-box recovery and recovery checks | M5 |
| Recovery | Recovery packets with secret, context and instructions | Later |
| Recovery | Advance-setup travel recovery | Later |
| Agents | Secrets drop box | After 1.0 |
| Agents | Reads approved by the owner | After 1.0 |
| Agents | Policy checks, scoped tokens, audit context | After 1.0 |
| Agents | Constrained SSH access | Later |
| Signing | Keys usable without export | After 1.0 |
| Signing | Remote multisig co-signer and single-sig signer | Later |
| Signing | Policy gating: limits, destinations, approvals, local confirmation | Later |
| Swarm | Mirror a tenant between boxes, reciprocal mirroring | After 1.0 |
| Swarm | Sync policies, peer health, conflict handling | After 1.0 |
| Tenants | Isolated tenants, landlord without access, quotas | Later |
| Tenants | Multiple users and access levels | Later |
| Tenants | Hosted tenants | Later |
| Inheritance | Inheritance setup, dead-man workflows, controlled release | Later |
| Duress | Decoy access paths and decoy passphrases | Later |
| Apps | Password-manager servers | M7 |
| Builds | Reproducible builds | M6 |

**Not possible on ordinary PCs:** secure elements, active tamper detection, a motion
sensor, an internal UPS and status LEDs. A TPM offers a partial substitute for some
key storage, and a USB UPS can be supported. Arca's embedded COLDCARD signer is
Coinkite's product, so cryptbox will have its own signer.

## Known limitations

- No secure element or tamper detection
- One owner until tenants arrive
- Requires x86-64 UEFI
- Choosing Wi-Fi adds radio exposure and stores the network password unencrypted
- Rollback of the whole disk to an older state cannot be detected by one box alone
- Deleted data cannot be guaranteed erased from SSDs, backups or mirrors

## Open questions

- Which scrypt work factor is right across low-end and high-end machines, while
  staying within what stock `age` accepts?
- Should the log be compacted, or is replaying it at unlock fast enough?
- Do current Bitwarden phone apps accept a private certificate authority? This
  affects the Vaultwarden app.

## Before the first release

- Confirm licence obligations for every app shipped in the image, including source
  availability for AGPL-3.0 and GPL components.
