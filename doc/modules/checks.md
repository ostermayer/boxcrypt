# Checks

> **Status: design.** See ADR-028. ZFS scrubs already run and repair damage, but nothing
> shows the results to the owner yet. Everything else on this page is not built.

## Purpose

An owner can find out at any time whether the box runs genuine BoxCrypt software and whether
the data is intact. Each answer uses plain words and says what was checked, when, and who
checked it.

## Who gives the answer

A page that the box serves cannot prove that the box is honest, because changed software can
draw the same page. So each result has one of two labels.

| Label | Who checked | Where it appears | Can changed software fake it? |
|---|---|---|---|
| **Box report** | The box | The Checks page | Yes |
| **Proven** | The owner's own computer | That computer | No, with the limits below |

A box report finds accidents: drive decay, failed writes and damaged backups. It is not proof
that the software is honest. The help note says so, and the page never shows a general
"secure" badge.

## The Checks page

The web UI has this page at `/checks`. The TUI has the same screen, with the same text.

| Section | Shows |
|---|---|
| Software | Release, boot measurement, last proof request, restarts since then, and the steps to run a proof |
| Drives | State of each drive, last scrub, data checked, errors repaired, errors not repaired, next scrub |
| Store | Objects checked, objects that failed, log entries checked, last run |
| Backups | Each backup drive, last backup, last full check, last recovery kit test |
| System files | Last check of the system partitions and boot files on each drive (M6) |

- Each row has one state: **OK**, **Repaired**, **Damaged**, **Overdue** or **Not checked**.
  The state is a word and an icon, not only a colour.
- Each result has a date and the amount checked. The page never shows "OK" without them.
- A check that did not run on time is **Overdue**, not OK. This matters for a box that is
  usually off.
- **Check now** starts the check, shows progress and can be stopped. A scrub slows the box,
  so the help note says how long it can take.
- Damage names the affected files and gives the next step, with a link to restore them.
- Repairs are counted for each drive. Repeated repairs suggest that the owner replace the drive.
- A problem puts one banner on Home. The unlock page shows drive state only, with no file names.
- Each row and term has a help note. See ADR-023.

## Software proof

**What genuine means.** The boot measurement of the box equals the value in the signed list
of published releases. After reproducible builds ship (M6), anyone can rebuild the source and
get the same value. An owner can install a changed version, and the proof then says that it is
not a published release.

**`boxcrypt verify <address>`** runs on the owner's computer. It needs no login, and it works
while the box is locked or unlocked.

1. The computer makes a fresh random number and sends it to `/attest`.
2. The TPM signs the boot measurements, the random number, its restart count, the hash of the
   box's TLS public key and the position of the store's log.
3. The computer checks the signature, the number and the TLS key of this connection.
4. It compares the measurement with the signed list, and the firmware measurements with the
   values from setup.
5. It shows the release, any firmware change, the restarts since the last check and the result.

| Attack | What stops it |
|---|---|
| Replay of an old good answer | The fresh random number |
| A fake box passes questions to a real box | The TLS key hash inside the signed answer |
| A box signs with a key that it made | The key is pinned at setup and printed in the recovery kit. For a bought box, the TPM maker's certificate |
| Someone puts an older copy of the disk back | The computer remembers the log position and warns if it goes back |

`/attest` accepts only a 32-byte number and has a rate limit.

**Every visit.** On a box with a TPM, the private key of the TLS certificate is created inside
the TPM and cannot leave it. The TPM uses the key only when the boot measurements match a
signed release. The key of the certificate authority stays in the keyring, so a changed boot
cannot issue a new certificate. After a changed boot, the browser shows a certificate error
before it shows a false unlock page. The owner does nothing extra.

**Check phrase.** The phrase stays on the unlock page and on a connected screen as a quick
sign. It is not proof, because anyone who has seen it can copy it.

**Restart and prove.** `boxcrypt verify --restart` restarts the box, waits for it and asks for
a new proof. The signed restart count must go up, so the box cannot pretend to restart. A
restart locks the box and ends a compromise that lives only in memory. This is the strongest
check that the software can give.

## Data checks

| Check | When | Proves | While locked |
|---|---|---|---|
| Deposit receipt | Each upload | The box stored the bytes that the browser sent | No |
| Scrub | Monthly, one hour after each start, **Check now** | Each block matches its ZFS checksum, and damage is repaired | Yes |
| Store check | After each scrub, **Check now** | Each object matches the SHA-256 in its name | Yes |
| Log check | Each unlock, **Check now** | Each log entry has a valid signature and chain, and its object exists | No |
| Backup checks | See [backup](backup.md) | The copies are intact and open with the current keys | Partly |

ZFS only knows that a block is what ZFS wrote. The store check also finds a change that went
through the file system, from a bug or from someone with write access.

**Deposit receipt.** The browser hashes the file as it sends it. The box hashes the same bytes
before it encrypts them. If the two hashes differ, the upload fails. After the write, the box
decrypts the object in the background and hashes it again. The file shows **Checking**, then
**Checked**. The hash stays in the encrypted log entry, and the file page shows it.

**Check by hand.** These results are **Proven**, because the owner's computer does the work.

- Download a file and compare its SHA-256 with your own copy.
- Connect a USB backup to your computer and run `boxcrypt verify --backup <path>`. It hashes
  each object and checks the log chain. It needs no passphrase.

## Limits

- **Live kernel compromise.** The proof shows what booted, not what is in memory now. An
  attacker who takes the kernel after a genuine boot still passes. Use restart and prove.
- **Firmware.** The firmware makes the first measurements, so changed firmware could send false
  ones. See ADR-027 for a box that you bought.
- **No TPM.** The software proof is not available, and the Software section says "cannot be
  proven". The data checks still work as box reports. See the hardware table in the
  [roadmap](../roadmap.md).
- **A compromised box can give false box reports.** Only the checks by hand and the software
  proof do not depend on it.
- **A hash shows no change since the first hash.** An error in memory before that point is
  not found, so ECC RAM is better when the computer supports it.
- **An older copy of the disk passes each check on the box.** Only the log position that the
  computer remembers can show it, and only if that computer has checked the box before.
- **New hardware.** A restore creates new TPM keys. The owner accepts them one time, and
  earlier checks do not prove that moment.
- **Slow TPMs.** A device on the LAN can force TPM signatures and slow the login. The rate limit
  and TLS session resumption reduce this. It cannot expose a key.

## Open questions

- Can a saved web page reach `/attest`? Owners who do not use a terminal need this, and browsers
  limit requests to local addresses.
- How long does a TPM take to sign a TLS handshake on slow hardware?
- WebCrypto cannot hash a file in steps, so very large uploads need a small WASM hasher that
  fits the content security policy.

## Tests

- A VM with a software TPM boots a changed image. The proof fails and the TLS key is refused.
- A replayed answer, a relayed answer and an answer from another TPM all fail.
- `--restart` fails if the restart count does not go up.
- A damaged object is found, the page names its file, and the state is **Damaged**.
- A check that is late shows **Overdue**. A row without a date cannot show **OK**.
- A changed upload fails its receipt.
