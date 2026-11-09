# Roadmap

## Current state

The design is written. The base system and the install program pass their VM tests.
There is no bootable USB image yet, and nothing has run on real hardware.

## Milestones

### M1: The system boots
- [x] Flake with a hardened base
- [x] LAN-only network rules
- [x] VM test proving only the allowed port answers and outbound traffic is dropped
- [x] Full appliance system builds
- [x] Answers to `boxcrypt.local` on the LAN
- [x] Wi-Fi stays off by default and keeps the same limits when chosen, proven in a VM
- [x] Tmpfs root and ZFS boot work from an installed disk, proven in a VM

### M2: It installs
- [x] Verified system partition with dm-verity, and `/persist` mounted noexec
- [x] Image assembly matches byte for byte on two machines (full source rebuild is in M6)
- [x] VM test proving a modified system block is refused
- [x] VM test that the firewall loader does not read `/persist`
- [ ] Boot an installed system with hostile persistent state and probe its network
- [ ] Wi-Fi test on the shipped image, enabled across a restart
- [ ] Network flash from another computer over SSH, see [installer](modules/installer.md)
- [ ] Authenticate the boot files, and prove a replaced boot file is refused or reported
- [x] Install program that discovers drives and builds the mirror
- [ ] Bootable USB installer image
- [ ] Installer joins Wi-Fi and shows the setup details
- [ ] Install from a browser with no screen connected (see the open questions)
- [x] Installer warns when there is no TPM, and the owner must accept
- [x] Each drive boots alone, proven in a VM by removing drives
- [ ] First install on real hardware
- [x] Lock kernel module loading after boot

### M3: The core works
- [ ] Services run without `CAP_NET_ADMIN` or `CAP_NET_RAW`, and without packet sockets
- [ ] Services cannot reach the resolver's local interfaces, so they cannot send data in mDNS queries
- [ ] Keyring, passphrase unlock, recovery key and auto-lock
- [ ] Mandatory second factor for each login: FIDO2 security key or authenticator app, see [two-factor login](modules/two-factor.md)
- [ ] Erase after wrong passphrases and erase passphrase, see [safeguards](modules/safeguards.md)
- [ ] Objects, signed logs and index
- [ ] Secrets and files, with streaming for files larger than RAM
- [ ] Stock `age` can recover everything, proven by a test
- [ ] Deposit receipt: both sides hash the file, and the box reads it back after the write
- [ ] Store check against a signed inventory: each object against its hash, each log entry against its signature

### M4: A person can use it
- [ ] First-run wizard with setup code
- [ ] [Checks](modules/checks.md) page in the web UI and the TUI: software, drives, store and backups, with **Check now**
- [ ] `boxcrypt verify` from another computer: enrollment, the restart check, USB backups and the repair, with one command to remember
- [ ] Signed list of the measurements of each release
- [ ] TLS key sealed to a policy for this machine's boot chain, with ten years of certificates for that key
- [ ] The image turns off suspend, and credentials, add-ons and extensions from the boot partition
- [ ] An overdue scrub starts soon after boot
- [ ] Web UI in the design language
- [ ] Optional TUI over SSH and on a connected screen
- [ ] Certificate install guide per device type
- [ ] Setup enrolls a second factor and proves that it works, in the web UI and the TUI
- [ ] Safeguards page with guided steps and a test mode
- [ ] Help note for every setting and term, first-look tour and task guides, with a test that fails if a setting has no help text

### M5: It survives losing the box
- [ ] Automatic backups to an internal dataset and to USB, verified by hash
- [ ] Restore, proven on different hardware
- [ ] Recovery kit test

### M6: 1.0
- [ ] Signed offline updates and rollback
- [ ] An interrupted update cannot leave two drives with different slots under one partition ID
- [ ] Drive failure alerts and guided replacement
- [ ] Check the system partitions and boot files on each drive, and rewrite damage from another drive
- [ ] Reproducible rebuilds as a release gate, with signatures and a public log
- [ ] Secure Boot enrollment where the firmware allows it
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
| Access | Text interface over SSH | M4 |
| Access | WireGuard, Tailscale and Tor, opt-in | Later |
| Access | Scoped setup, enrollment and recovery tokens | Later |
| Recovery | Replacement-box recovery and recovery checks | M5 |
| Recovery | Recovery packets with secret, context and instructions | Later |
| Recovery | Advance-setup travel recovery | Later |
| Agents | Secrets for LLMs through MCP, delivered by reference | After 1.0 |
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
Coinkite's product, so BoxCrypt will have its own signer.

## Hardware families

| Family | Order | Can prove it was not changed | Notes |
|---|---|---|---|
| x86-64 UEFI with TPM 2.0 | First | Yes, once M4 and M6 are done | Most PCs since about 2016 |
| x86-64 UEFI without TPM | First | No, shows a warning | Older PCs and Intel Mac minis before 2018 |
| ARM64 UEFI | Second | Only with a TPM | Same design, separate image |
| Raspberry Pi 5 | Third | No, unless a TPM module is added | Does not boot UEFI without community firmware |
| 2018 Intel Mac mini | Later | No | Needs a T2 kernel and firmware security turned off |
| Apple Silicon Mac mini | Last | No | M1 and M2 only for now. Keeps macOS and uses a community kernel |

M4 Mac minis cannot run Linux yet. M3 support is new and has limits.

Open questions for Apple Silicon: whether ZFS and this verified image work on its 16K-page
kernel, and how a mirror fits with one internal drive.

## Known limitations

- No secure element or tamper detection
- A live kernel compromise cannot be ruled out by the box itself
- Machines without a TPM cannot prove their state
- The independent software proof needs a terminal until a double-click version follows 1.0
- One owner until tenants arrive
- x86-64 UEFI only until the other hardware families are built
- Choosing Wi-Fi adds radio exposure and stores the network password unencrypted
- Rollback to an older signed state, of the whole disk or of recent changes, cannot be detected by one box alone
- Deleted data cannot be guaranteed erased from SSDs, backups or mirrors
- Erase after wrong passphrases stops guessing at the box, not guessing against copied drives

## Open questions

- How can a USB install show the setup code when no screen is connected? With no setup
  code, anyone on the LAN could claim a new device first. A network flash shows the code in
  the owner's terminal.
- Which scrypt work factor is right across low-end and high-end machines, while
  staying within what stock `age` accepts?
- Should the log be compacted, or is replaying it at unlock fast enough?
- Do current Bitwarden phone apps accept a private certificate authority? This
  affects the Vaultwarden app.
- Do phone browsers allow security keys on `boxcrypt.local` with a private certificate
  authority? Authenticator codes work either way.

## Before the first release

- Get legal advice on shipping the ZFS kernel module, under CDDL, in one image with the
  GPL Linux kernel
- Confirm licence obligations for every app shipped in the image, including source
  availability for AGPL-3.0 and GPL components.
- Write a buyer's guide for premade boxes: what to check at first start, how to reinstall
  from your own USB stick, and the firmware risk that a reinstall does not remove.
