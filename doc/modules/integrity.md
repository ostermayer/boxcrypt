# Integrity

> **Status: design.** See ADR-018.

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
| Machine to owner | The owner can see all of this held | Check phrase and independent verification |

## Network policy

The firewall and routing rules are part of the verified image. Nothing under
`/persist` can add outbound access, and `/persist` is mounted `noexec`, `nosuid` and
`nodev`.

Writable settings can only choose a private address, a Wi-Fi network, and inbound LAN
ports for catalog apps. None of them can open a path to the internet.

## Telling the owner

**Check phrase.** During setup the owner picks a phrase, which is sealed in the TPM to
the boot measurements. The unlock page shows it before asking for the passphrase. If
the boot chain has changed, the TPM refuses to release it and the page shows a warning
instead. Access to the sealed phrase is closed once boot finishes.

**Verify from another computer.** `cryptbox verify <address>` asks the TPM for a signed
quote and compares it with the value published for that release. Every box running a
release should report the same measurement, which is why one image must fit every
machine (ADR-004).

## Reducing what malware can do

- Network-facing programs run without `CAP_NET_ADMIN`, so even as root they cannot
  change routes or firewall rules.
- Kernel module loading is locked after boot.
- The root filesystem is rebuilt on every boot and the OS is read-only, so a reboot
  returns the box to a known state.

## Limits

- **Live kernel compromise.** Cryptography proves what booted, not what is happening in
  memory. An attacker with kernel-level code execution could change the rules until the
  next reboot, and the box could not reliably report it. The router block is the
  independent backstop, because nothing on the box can change it.
- **No TPM.** A TPM is not required, but without one the box cannot prove its state. The
  installer explains this and asks the owner to accept it, and the status page keeps
  saying so.
- **No Secure Boot.** A replaced kernel is not blocked, but the TPM measurement exposes
  it.
- **Firmware and hardware** sit below all of this and could lie.
- **Reproducibility is not automatic.** It must be proven for this image, not assumed
  from NixOS.
- **Features that need outbound traffic,** such as remote access or sync beyond the LAN,
  must not weaken this. They need a separately measured mode that the owner can see.
