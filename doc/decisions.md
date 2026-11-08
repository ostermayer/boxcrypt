# Decisions

Each record says why something is the way it is.

## ADR-001: A purpose-built core

**Context.** The product needs a local web UI in its own style, a TUI, files of any
size, write-only agents and mirroring between boxes.

**Decision.** Write `cryptboxd` in Go as a single small program.

**Consequences.** One design covers all of those needs. We own security-critical
code, so it stays small, invents no cryptography and needs an independent audit
before 1.0.

**Rejected.** Vaultwarden has its own UI, no TUI, a 525 MB file limit and no
mirroring between boxes. OpenBao's raft replication is for one site and has no
owner-friendly UI. Both are better as add-on apps or components.

## ADR-002: NixOS

**Decision.** Build on NixOS 26.05.

**Consequences.** The whole machine is defined in this repository, and the root
filesystem can be rebuilt on every boot. nixpkgs gives weaker patching guarantees
than enterprise distributions, so cryptbox owns its release schedule.

**Rejected.** FreeBSD, because common Realtek 2.5G network cards remain unreliable
there and ARM support is weaker. Debian, because it cannot express the whole machine
declaratively.

## ADR-003: Shaped like bitcoinix

**Decision.** A narrow-purpose collection of NixOS modules and packages, plus a
ready-to-flash image. `doc/` and `tests/` follow this project's conventions.

**Consequences.** Nix users can compose the modules, and everyone else flashes the
image. Scope stays narrow: if it does not help keep secrets, it does not belong.

## ADR-004: One machine-agnostic image

**Context.** NixOS normally bakes disk IDs and boot targets into each build.

**Decision.** The system contains nothing machine-specific. Pools are imported by
name, boot partitions are found by label, and common drivers are always present.

**Consequences.** One signed image serves every machine, and updates work offline.

## ADR-005: Every object is a stock age file

**Context.** The goal is storing secrets over decades, longer than any one project
is likely to last.

**Decision.** Store every secret, file and log body in the unmodified age format.
Wrap the keyring with age's own passphrase mode.

**Consequences.** The data can be recovered with the standard `age` tool and a
documented layout. The passphrase KDF is scrypt rather than Argon2id, which is the
cost of staying compatible. We found no formal third-party audit of age, so the 1.0
audit includes our use of it.

## ADR-006: Hybrid post-quantum keys

**Context.** Backups and mirrors may sit on other people's hardware for decades, so
recorded ciphertext is exposed to future attacks.

**Decision.** Use age's hybrid post-quantum recipients for all content and metadata.

**Consequences.** Each object carries a slightly larger header. Log signatures are
classical Ed25519 for now, and entries carry an algorithm field so they can change.

## ADR-007: One passphrase, and the box does the decrypting

**Context.** There are no client apps, only a web UI and TUI served by the box. A
compromised box could alter browser code, so browser-side encryption would add
complexity without removing that exposure. It would also bring back browser memory
limits on large downloads.

**Decision.** The box encrypts and decrypts. One passphrase unlocks it, and keys stay
in RAM only while unlocked.

**Consequences.** A compromised, unlocked box can read secrets, so short unlock
windows and a small surface are the defence. Reboots require the passphrase.

## ADR-008: Immutable objects and signed per-device logs

**Decision.** Objects are named by the SHA-256 of their bytes and never change. Each
box appends to its own signed log, and state is the merge of all logs.

**Consequences.** Any copy can be verified without keys. Mirroring between boxes
reduces to exchanging missing files. Anyone with a public key can create an object,
so only entries in a signed log are trusted.

## ADR-009: Backups and mirrors are copies of the store

**Decision.** A backup drive holds the same layout as the store, and copying is
incremental.

**Consequences.** Backups run while locked and restore onto any supported hardware.
The box can verify every byte of a backup without a key.

## ADR-010: `cryptboxd` terminates all network traffic

**Decision.** `cryptboxd` terminates TLS with the Go standard library. Add-on apps
listen on loopback and are reached through it.

**Consequences.** One small program faces the network. An enabled app adds one more
listening port on `cryptboxd`, and a disabled app adds none.

## ADR-011: Umbrel's style without Umbrel's code

**Context.** Umbrel's visual style is the design guide, but its code is under the
PolyForm Noncommercial licence.

**Decision.** Follow the look and write everything ourselves, with no Umbrel code,
assets or branding. Use server-rendered templates, hand-written CSS and a small
amount of plain JavaScript, with no npm dependencies.

**Consequences.** No frontend supply chain and a strict CSP. Rich interactions take
more hand work.

## ADR-012: A TUI alongside the web UI

**Decision.** The TUI runs on the box's own screen and talks to `cryptboxd` over a
Unix socket. SSH delivery is opt-in, and it can only open the TUI.

**Consequences.** Full control is available with no network exposure.

## ADR-013: LAN only, with no route out

**Decision.** Ignore any DHCP gateway, drop outbound traffic except replies and
DHCP, accept inbound traffic only from private ranges, and disable IPv6. Docs advise
blocking the box at the router too.

**Consequences.** There is no internet time, so the box uses its hardware clock and
offers to correct it from the browser. Updates arrive as uploaded files. Remote
access, when added, must be an explicit opt-in.

## ADR-014: Mirror every data drive with ZFS

**Decision.** With two or more NVMe or SATA drives, build one N-way ZFS mirror. Each
drive has its own boot partition and can boot alone.

**Consequences.** Any single surviving drive keeps the box running, and checksums
repair silent corruption. Capacity is that of the smallest drive.

**Rejected.** mdadm has no checksums. btrfs handles degraded boots poorly.

## ADR-015: No full-disk encryption

**Context.** Secrets, names and history are already encrypted in the store, and the
unlock page must be served while locked.

**Decision.** Leave the OS and store directory unencrypted at the disk level.

**Consequences.** A stolen drive reveals object counts, sizes, dates, the TLS key and
network settings.

**Rejected.** ZFS native encryption, because reports of corruption with raw send
remain unresolved.

## ADR-016: Wired by default, Wi-Fi by choice

**Context.** Some owners can only reach the box over Wi-Fi. A wireless driver handles
frames from anyone in radio range, even before the box joins a network, so it is
exposed in a way a cable is not.

**Decision.** Wi-Fi drivers stay blocked unless the owner chooses Wi-Fi on the box's
screen. One gate on `cfg80211` covers every modern driver. The box only ever joins a
network as a client. Bluetooth is always off.

**Consequences.** Wired owners have no radio surface at all. Wi-Fi owners accept that
surface, and the network password is stored unencrypted, because the box must join the
network before it can show the unlock page.

## ADR-017: A narrow catalog of add-on apps

**Context.** Some people want an existing password manager. Umbrel's app model is
friendly, but a general catalog would defeat the purpose of this box.

**Decision.** Offer a curated catalog limited to tools for keeping secrets. Each app
is a NixOS module, ships inside the image, is off by default, runs isolated and is
reachable on the LAN only. See [apps](modules/apps.md).

**Consequences.** Installing is a click and needs no internet. Each app adds to image
size and to the review burden of every release, which keeps the list short.
