# Integrity

> **Status: partly built.** See ADR-018 and ADR-028. The read-only OS, block verification and module
> locking are built and VM-tested. Authenticating the boot files and `boxcrypt verify`
> are not built. Until they are, an attacker who can write to the
> boot partition can replace the kernel and nothing will report it.

## Purpose

Guarantee that the box cannot reach the internet, and that nobody can change that
without the owner knowing.

A firewall is only as trustworthy as the system enforcing it, so the guarantee has to
reach from the source code to the running machine.

## Chain of trust

| Link | What it proves | How |
|---|---|---|
| Source to image | The image is exactly what this source builds | Reproducible builds, rebuilt independently before release |
| Project to everyone | Every owner received the same release | Signature and a public append-only log |
| Firmware to kernel | The kernel is unmodified | Secure Boot where available, TPM measurement always |
| Kernel to system | Every block of the OS is unmodified | dm-verity, with its root hash inside the kernel image |
| Disk to policy | Nothing writable can widen the network rules | Rules live only in the verified image |
| Machine to owner | The owner can see all of this held | `boxcrypt verify` from the owner's computer |

## Network policy

The firewall and routing rules are part of the verified image. Nothing under
`/persist` can add outbound access, and files on `/persist` cannot be executed directly
because it is mounted `noexec`, `nosuid` and `nodev`.

Writable settings can only choose a private address, a Wi-Fi network, and inbound LAN
ports for catalog apps. None of them can open a path to the internet.

## Telling the owner

The owner can check the box at any time. [Checks](checks.md) has the full design.

**Verify from another computer.** `boxcrypt verify <address>` asks the TPM for a signed
quote over a fresh random number and compares it with the values published for that
release. Every box running a release should report the same PCR 11 value, which is why
one image must fit every machine (ADR-004). Firmware measurements differ on each machine,
so they are compared with the values from enrollment.

**Browser warning.** The private key of the TLS certificate is sealed to the TPM, so a
changed boot chain or a stolen drive cannot use it, and the browser shows a warning or a
connection failure. This does not cover malware that reached the box while it was unlocked.

## Reducing what malware can do

- Services such as `boxcryptd` will run without `CAP_NET_ADMIN` or `CAP_NET_RAW`, and
  without packet sockets, so even as root they cannot change routes or firewall rules
  or send raw frames.
- `systemd-networkd` and `iwd` need those privileges to do their jobs, so they remain
  trusted components. Compromising one could bypass the firewall, which cannot filter
  raw frames.
- Kernel module loading is locked after boot.
- The root filesystem is rebuilt on every boot and the OS is read-only, so once the boot
  files are authenticated, a reboot returns the box to a known state.

## Limits

- **Live kernel compromise.** Cryptography proves what booted, not what is happening in
  memory. An attacker with kernel-level code execution could change the rules until the
  next reboot, and the box could not reliably report it. The router block is the
  independent backstop, because nothing on the box can change it. The restart check in
  `boxcrypt verify` shows that a genuine release booted again.
- **No TPM.** A TPM is not required, but without one the box cannot prove its state. The
  installer explains this and asks the owner to accept it, and the status page keeps
  saying so.
- **No Secure Boot.** A replaced kernel is not blocked, but the TPM measurement exposes
  it.
- **Wi-Fi is enabled by a plain file.** Someone who can write to the disk could turn on
  the radio and choose the network. That cannot open a path to the internet, but it adds
  radio exposure. Measuring this choice into the TPM is planned.
- **A private source address does not prove a device is local.** If a router forwards a
  port to the box, internet traffic can arrive looking local. Never forward a port to it.
- **`noexec` only blocks running a file directly.** An existing interpreter can still
  read a script, so nothing at boot may read code from `/persist`.
- **DHCP and mDNS are small exceptions.** Only the network services can send on those
  ports, but a compromised service could send data to a relay on the LAN. Any process that
  can ask the resolver for a name can also make it send a query, so services must be kept
  away from the resolver. That work is planned for M3. IGMP can also
  carry a small amount of data to the LAN, because a process can choose which groups to join.
  `systemd-networkd` also reads raw DHCP frames, which the firewall does not see, so the
  DHCP rate limit does not protect it.
- **A rogue DHCP server** can offer a very large subnet, which creates a route that covers
  public addresses. The firewall still blocks new outbound connections.
- **A malicious USB device** can attack the kernel drivers that are loaded. There is no
  USB device allowlist yet.
- **The name can be claimed.** Another device on the LAN can answer to `boxcrypt.local`.
  Compare the certificate fingerprint on the first visit. After that, browsers reject an
  impostor.
- **A prepared disk.** Someone who can add an internal drive or SD card holding a pool
  named `bcpool` could supply false settings at boot. Pinning the pool to the authenticated
  boot chain is planned. USB drives are not visible during early boot.
- **External drives that look internal.** Thunderbolt NVMe enclosures report as NVMe, so
  the installer treats them as internal. Disconnect them before you install.
- **Firmware and hardware** sit below all of this and could lie.
- **Reproducibility is not automatic.** It must be proven for this image, not assumed
  from NixOS.
- **Features that need outbound traffic,** such as remote access or sync beyond the LAN,
  must not weaken this. They need a separately measured mode that the owner can see.
