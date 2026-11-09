# Decisions

Each record says why something is the way it is.

## ADR-001: A purpose-built core

**Context.** The product needs a local web UI in its own style, a TUI, files of any
size, write-only agents and mirroring between boxes.

**Decision.** Write `boxcryptd` in Go as a single small program.

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
than enterprise distributions, so BoxCrypt owns its release schedule.

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

**Decision.** The system contains nothing machine-specific. Pools are imported by name.
The system partition is found by an ID derived from its hash. Each drive boots through
the UEFI removable path, and common drivers are always present.

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

**Decision.** Backups have the same layout as the store. They go to an internal dataset
and to USB drives, and copying is incremental. The internal backup protects against
mistakes and damaged data. The USB backup protects against loss of the whole device.

**Consequences.** Backups run while locked and restore onto any supported hardware.
The box can verify every byte of a backup without a key.

## ADR-010: `boxcryptd` terminates all network traffic

**Decision.** `boxcryptd` terminates TLS with the Go standard library. Add-on apps
listen on loopback and are reached through it.

**Consequences.** One small program faces the network. An enabled app adds one more
listening port on `boxcryptd`, and a disabled app adds none.

## ADR-011: Umbrel's style without Umbrel's code

**Context.** Umbrel's visual style is the design guide, but its code is under the
PolyForm Noncommercial licence.

**Decision.** Follow the look and write everything ourselves, with no Umbrel code,
assets or branding. Use server-rendered templates, hand-written CSS and a small
amount of plain JavaScript, with no npm dependencies.

**Consequences.** No frontend supply chain and a strict CSP. Rich interactions take
more hand work.

## ADR-012: A TUI alongside the web UI

**Context.** Most owners will run the device without a screen.

**Decision.** The web UI is the main interface and does everything. The TUI is optional. It
runs on a connected screen, or over SSH that the owner turns on and that can only open
the TUI. It talks to `boxcryptd` over a Unix socket. The installer shows the setup details,
so the device never needs a screen after installation.

**Consequences.** The default has one open port. Turning on SSH opens a second one.

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

**Consequences.** Any single surviving drive can run the box, and checksums repair silent
corruption. If the drive serving the system fails, the box needs a restart to carry on.
Capacity is that of the smallest drive.

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

**Decision.** Wi-Fi drivers stay blocked unless the owner chooses Wi-Fi during
installation. One gate on `cfg80211` covers every modern driver. The box only ever joins a
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

## ADR-018: The no-internet guarantee is verified from build to boot

**Context.** The box must not be able to reach the internet, and malware must not be
able to change that without the owner knowing. A firewall alone is only as trustworthy
as the system enforcing it.

**Decision.** Build reproducible images, and sign and publicly log each release. Boot a
single kernel image through Secure Boot where available, measured by the TPM. Verify the
OS with dm-verity, keep network rules only in the verified image, and show the owner a
TPM-sealed check phrase before each unlock. See [integrity](modules/integrity.md).

**Consequences.** The OS moves off ZFS into verified A/B partitions, and ZFS holds only
`/persist`. Persistent tampering either fails to boot or shows at the next unlock. A live
kernel compromise cannot be ruled out by the box itself, so docs treat a router block as
part of the design.

A TPM is not required, so the box still runs on any commodity hardware. Without one, the
installer explains that the machine cannot prove its state and asks the owner to accept
that, and the status page keeps saying so.

**Rejected.** A signed settings file with no hardware anchor, because malware could
replace the file and the key that checks it together.

## ADR-019: One image per hardware family, each with stated guarantees

**Context.** Owners want to reuse PCs, ARM boards, Raspberry Pi 5s and Mac minis. These
machines boot differently, and not all of them can prove their state.

**Decision.** Build one image for each hardware family. ADR-004 applies within a family.
The roadmap states what each family guarantees, and the installer tells the owner.

**Consequences.** There are more images to build, test and review. A Raspberry Pi or
Apple Silicon Mac cannot give the full tamper guarantee. The installer must never erase
the internal drive of an Apple Silicon Mac, because Apple's boot data lives on it.

## ADR-020: Agents receive secrets by reference

**Context.** Anything a tool returns to an LLM enters its prompt, transcript and provider
logs. Some agents need to use a secret, and MCP is the common way to give them tools.

**Decision.** MCP tools request and refer to secrets but never return their values. A
local helper delivers an approved secret as an environment variable for one command, or
as a short-lived file that the agent passes to a program.

**Consequences.** Values stay out of prompts in normal use. A file only helps if the model
does not open it, so the agent harness must deny that read. An agent with a shell can still
print a value, so approval and short lifetimes remain necessary.

## ADR-021: The device announces itself as boxcrypt.local

**Context.** Most owners run the device without a screen and should not need to find an IP
address.

**Decision.** The device answers to `boxcrypt.local` by multicast DNS until the owner
changes the name. `systemd-resolved` provides this and looks up names nowhere else. The
certificate covers that name, so the address can change without any effect.

**Consequences.** One more port is open, UDP 5353, for private sources and the link-local
multicast group only. Another device on the LAN can claim the name, so owners compare the
certificate fingerprint on the first visit. After that, browsers reject an impostor.

## ADR-022: Wrong passphrases can erase the box

**Context.** Owners want the box to erase itself after a number of wrong passphrases, as
a hardware wallet does. A person must hold a hardware wallet to guess its PIN. BoxCrypt is
on a network, so a simple counter would let any device on the LAN destroy the data.

**Decision.** The setting is off by default, and the owner chooses the number. Only a login with a
valid second factor reaches the passphrase check, so a device on the LAN cannot use up the
tries. An erase deletes the keys and the pool. It counts as best effort, because
neither overwriting nor destroying a pool removes data from ZFS or an SSD. On a box with a
TPM and keys that were never in a passphrase-only keyring, the TPM checks the passphrase, so
nobody can guess against a copy of the drives.

**Consequences.** A device without a valid second factor cannot cause an erase. An owner who
loses every second factor needs the recovery kit. With that TPM protection, a restore to a new
computer needs the recovery kit, and so does a cleared TPM. An existing box needs a rebuild
to gain it, and older backups stay open to guessing. Without a TPM, the count cannot stop guessing
against copied drives, so a long passphrase still matters, and the setting says so.

## ADR-023: Help text is part of each feature

**Context.** Owners are moderately technical. The device cannot reach the internet, and
some settings can destroy data.

**Decision.** Each setting has a one-line explanation and a help note. A setting that can
destroy data uses guided steps. All help ships in the image, in one catalog for the web UI
and the TUI. A test fails if a setting has no help text.

**Consequences.** A new setting takes more work to add. Help stays in step with features,
and the two interfaces cannot disagree.

## ADR-024: A computer can be flashed over the network

**Context.** Many owners reuse a computer that already runs Linux and has no screen. Moving
a screen, a keyboard and a USB stick to it is the hardest part of the install.

**Decision.** `boxcrypt-flash` connects over SSH, copies the installer and image from the
owner's computer, and starts the installer in RAM with `kexec`. It then runs the same
install program as the USB image. The target needs no internet access. The tool makes the
installer's SSH host key on the owner's computer and accepts no other key after the `kexec`.

**Consequences.** The owner must trust the old system, because it controls the copy and the
`kexec`. The tool says so, and the USB image stays the path for a computer that is not
trusted. The setup code appears in the owner's terminal before the `ERASE` prompt, so a
flash needs no screen.
Nothing is erased before the owner types `ERASE`, so a failed `kexec` costs only a restart.

## ADR-025: Every login needs a second factor

**Context.** The web UI and the TUI guard every secret, and anyone on the LAN can reach the
login page. Owners use YubiKeys and authenticator apps. The box has no internet and no
network time.

**Decision.** Each login to the web UI and the TUI needs the passphrase and a second factor,
and the owner cannot turn this off. The factor is a FIDO2 security key, such as a YubiKey, or
an authenticator app. The box checks the second factor before the passphrase. The recovery
kit replaces both when every factor is lost. YubiKey's one-time password mode is not
supported, because a Yubico server checks it.

**Consequences.** A device on the LAN without a factor cannot guess the passphrase or cause
an erase, so the design needs no list of trusted browsers. Setup takes one more step. Codes
depend on the clock of a box that has no network time, so a security key is the better
factor. The second factor protects the login, not the data on the drives.

## ADR-026: The project uses the GPL

**Context.** The project started under the MIT licence, which lets others sell closed
versions. Owners of a device that holds their secrets must be able to read the code that it
runs.

**Decision.** BoxCrypt uses GPL-3.0-or-later. Version 3 also requires a person who sells a
device with BoxCrypt to let its owner install a changed version.

**Consequences.** A person who distributes a changed version must publish its source. A
person who only runs a changed version as a service does not have to, and the AGPL would
cover that case. Copies taken under MIT before this change stay under MIT. Add-on apps keep
their own licences.
