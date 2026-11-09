# Checks

> **Status: design.** See ADR-028. ZFS scrubs already run and repair damage, but nothing
> shows the results to the owner yet. Everything else on this page is not built. It has
> been reviewed on paper and has not run on real TPM hardware.

## Purpose

An owner can find out at any time whether the box runs genuine BoxCrypt software and whether
the data is intact. Each answer uses plain words and says what was checked, when, and who
checked it.

## Who gives the answer

A page that the box serves cannot prove that the box is honest, because changed software can
draw the same page. So each result has one of two labels.

| Label | Who checked | Where it appears | Can changed software fake it? |
|---|---|---|---|
| **Box report** | The box | The Checks page and the TUI | Yes |
| **Proven** | The owner's own computer | That computer | No, with the limits below |

A box report finds accidents: drive decay, failed writes and damaged backups. It is not proof
that the software is honest. The help note says so, and the page never shows a general
"secure" badge. Only `boxcrypt verify` gives a **Proven** result, and the box never claims one.

## The Checks page

The web UI has this page at `/checks`. The TUI has the same screen, with the same text.

| Section | Shows |
|---|---|
| Software | Release, boot measurements, last proof request, and a reminder to run `boxcrypt verify`. This row has no OK state |
| Drives | State of each drive, last scrub, data checked, errors repaired, errors not repaired, next scrub |
| Store | Objects checked, missing and failed, deposits waiting, log entries checked, last run |
| Backups | Each backup drive, last backup, last copy check, last open test, last recovery kit test |
| System files | Appears when this check exists (M6): system partitions and boot files on each drive |

- Each row has one state: **OK**, **Repaired**, **Damaged**, **Overdue**, **Stopped**,
  **Restoring** or **Not checked**. The state is a word and an icon, not only a colour.
- Each result has a date and the amount checked. The page never shows "OK" without them.
- A run that did not finish shows **Stopped**, never OK.
- A check that is late shows **Overdue** with the date of the last full run. A box that is
  usually off starts an overdue check soon after it starts. A scrub continues from its last
  checkpoint, which ZFS writes about every two hours.
- **Check now** starts the check, shows progress and can be stopped. A scrub slows the box,
  so the help note says how long it can take.
- Damage names the affected files and gives the next step, with a link to restore them.
- Repairs are counted for each drive. Repeated repairs suggest that the owner replace the drive.
- A problem puts one banner on Home. The unlock page shows drive state only, with no file names.
- Each row and term has a help note. See ADR-023.
- The page names the command as plain text. It has no copy button and no download link, because
  a tampered box could supply a different command. The owner types `boxcrypt verify`.

## Software proof

**What genuine means.** The boot measurements of the box match a published release in the
signed release list. After reproducible builds ship (M6), anyone can rebuild the source and get
the same values.

### Using `boxcrypt verify`

One small program for the owner's computer, from boxcrypt.org. It needs no login, and it works
while the box is locked or unlocked. It does not depend on the box's certificate being valid, so
it still gives an answer when the browser refuses the box. The last step of setup asks the owner
to install it and run it.

There is one command to remember, and it asks for what it needs.

| Situation | What happens |
|---|---|
| First run | It asks for the box's address and the fingerprint that the installer showed, then enrolls |
| Each run after that | It remembers the box and prints one sentence: the result and what to do next |
| After a **Genuine** result | It offers a restart check, tells you when to restart or unplug, waits and confirms |
| `boxcrypt verify <path>` | It checks a USB backup |
| Firmware or hardware changed | It shows the old and new values and asks whether you made the change |
| The HTTPS key needs repair | It offers the repair below |

`--details` prints the measurements. An owner who does not use a terminal gets box reports only.
A double-click version can follow 1.0.

### Enrollment

1. The installer creates the proof key inside the TPM, as a restricted signing key with
   `fixedTPM`, `fixedParent` and `sensitiveDataOrigin`. It shows a short fingerprint of the key's
   TPM Name. The owner runs the installer from their own stick, so this is the moment of trust.
2. The command reads the key's full public area, checks those attributes and compares its Name
   with the fingerprint.
3. It uses TPM credential activation, tied to that Name, to prove that the key is in the TPM that
   owns the endorsement key. It checks the TPM maker's certificate where one exists.
4. It takes a signed answer, and pins the proof key, the firmware measurements, the TLS key and
   the device public key from that answer.

A pin never changes by itself. New hardware, a cleared TPM or a reinstall needs a new
enrollment, with the fingerprint that the installer showed on that computer.

For a bought box, install from your own stick and then enroll. The maker's certificate shows
only that a real TPM holds the key. It does not show that this is your box, or that its first
software was honest.

### Each check

1. The computer makes 32 random bytes and connects to `/attest`.
2. The TPM signs the measurements and its reset count, with this value as its extra data:
   `SHA-256("boxcrypt-attest-v1" || random bytes || TLS exporter value || SHA-256(device public key))`.
   The TLS exporter value belongs to this one connection (RFC 9266). The box sends the TPM event
   log with the answer.
3. The computer checks the signature against the pinned key, computes the extra data itself and
   replays the event log against the signed measurements.
4. It compares the measurements with the table below, and the TLS key and device key with
   their pins.

| TPM register | Covers | Compared with |
|---|---|---|
| PCR 4 | The boot loader and the whole kernel image file, each measured by the firmware before it runs | Those two hashes must be on the signed list. Other entries must match enrollment |
| PCR 11 | Kernel, initrd, command line and dm-verity root hash | Signed list, at the end of boot. The same on every machine |
| PCR 12 | Credentials, add-ons and extra command line from the boot partition | Must show that nothing was added |
| PCR 13 | System extensions from the boot partition | Must show that nothing was added |
| PCR 0, 2, 7 | Firmware, option ROMs, Secure Boot state | Values from enrollment, for this box only |

The image turns off credentials, add-ons and extensions from the boot partition. The boot
partition is writable, so the proof also checks that none were used.

| Result | Meaning | What to do |
|---|---|---|
| **Genuine** | A published release, nothing added, same firmware | Nothing |
| **Could not check** | No answer, rate limited, or a log this version cannot read | Nothing is known. Try again. Do not erase anything |
| **Older release** | Genuine, but older than the newest this computer has seen | Update. If you did not roll back, treat it as tampering |
| **Firmware or hardware changed** | The software is genuine, and PCR 0, 2 or 7 differ | If you updated firmware or changed a card, accept it. If not, treat it as tampering |
| **Not a published release** | The measurements are not on the list | Expected if you built it yourself. If not, stop |
| **HTTPS key changed** | The TLS key is not the pinned key | Do not enter your passphrase until you know why |
| **HTTPS key needs repair** | Genuine, but the box could not open its TLS key | Accept the repair that the command offers |
| **Different device** | The proof key does not match the pin | Do not enter your passphrase. Find out what is answering |
| **Failed** | Bad signature, or something added or replaced at boot | Do not enter your passphrase and do not erase anything. Disconnect the box and check your USB backup on your computer |
| **Cannot be proven** | The box has no TPM | See limits |

A reinstall erases the internal drives. The command never suggests one as a first step.

| Attack | What stops it |
|---|---|
| Replay of an old good answer | The random bytes |
| A fake box passes questions to a real box, even with a stolen TLS key | The TLS exporter value inside the signed answer |
| A box signs with a key that it made | The pinned key, proven to be a restricted key in the TPM at enrollment |
| A replaced boot loader or kernel image | The firmware measures it into PCR 4 before it runs |
| Extra behaviour added through the boot partition | PCR 12 and PCR 13 |
| Roll back to an older signed release | The computer remembers the newest release for this box |

`/attest` accepts two fixed-size requests only: 32 random bytes, or one credential challenge at
enrollment. It has per-client and global rate limits and no CORS, and login work takes priority
over it in the TPM.

**The release list.** The command checks the list with a project key built into it, gets new
lists from boxcrypt.org, and shows the date of the list. A release newer than the list shows
**Not a published release** with a note to update the command.

### Browser warning

On a box with a TPM, the private key of the TLS certificate is sealed to the TPM during setup,
on the box's first boot. The policy predicts this machine's PCR 4, 11, 12 and 13, with
`systemd-pcrlock` or an equivalent `PolicyOR`. It lists both system slots. The updater adds the
new release before it restarts, and a security update can remove the old slot. Firmware values
in PCR 0, 2 and 7 are not part of the policy.

The box opens the key once at boot and keeps it in memory. A replaced boot chain cannot open it,
because the firmware has already measured the replacement. Someone who has only the drive cannot
read it. The browser then shows a certificate warning or a connection failure. **Stop and run
`boxcrypt verify`.** The only expected warning is the first visit, when setup tells the owner to
compare a fingerprint.

This is not a guarantee against malware that reached the box while it was unlocked. That malware
can copy the key of the certificate authority and issue a certificate that browsers keep
trusting after a restart. The command reports **HTTPS key changed**. After a suspected
compromise, replace the certificate authority on each device.

**No expiry while locked.** The TLS key stays the same across renewals, so the pin does not
change. At each unlock, the box issues certificates for that key that cover the next ten years,
each inside the 825-day limit, with overlapping dates. It moves to the next one by itself, so a
locked box does not run out and the owner is never told to continue past a warning.

**Repair.** If the genuine software cannot open the key, for example after a firmware update that
changes PCR 4, it uses a temporary key and one fixed page that says to run `boxcrypt verify`. It
accepts no passphrase on that page. The command reports **HTTPS key needs repair** and offers to
fix it. It asks for the passphrase and an authenticator code, or the recovery key, and sends them
over the connection that the proof covers. The box then issues and seals a new key. A cleared
TPM counts as new hardware, because the proof key is gone.

### After a restart

After a **Genuine** result the command offers a restart check. It never restarts the box. It
notes the reset count, tells the owner to restart from Settings or unplug the box, waits for the
box to go away and come back, then needs a higher signed reset count and a **Genuine** result.
The image turns off suspend, because a resume is not a restart.

This shows that the TPM was reset and that a genuine release then booted. It does not show that
memory was erased, or that the box stayed clean afterwards. A flaw in that release can be used
again. Unplugging is the better choice, because the owner can see that it happened.

## Data checks

| Check | When | Shows | While locked |
|---|---|---|---|
| Deposit receipt | Each upload | The box reports that it stored the bytes that the browser sent | Hashes only. The read-back waits for the next unlock |
| Scrub | Monthly, one hour after each start, **Check now** | Each block matches its ZFS checksum, and damage is repaired | Yes |
| Store check | Monthly, soon after boot when overdue, **Check now** | Each object in the inventory exists and matches its object hash | Yes |
| Log check | Each unlock, **Check now** | Each log has valid signatures and an unbroken chain up to the inventory's head, and each required object exists | No |
| Backup checks | See [backup](backup.md) | The copies are intact, and a sample opens with the current keys | Copy check only |

ZFS only knows that a block is what ZFS wrote. The store check also finds a change that went
through the file system, from a bug or from someone with write access.

**Two hashes.** The *object hash* is the SHA-256 of the encrypted file and is its name. The
*content hash* is the SHA-256 of the original file and is stored in the encrypted log entry. The
same file stored twice has two object hashes and one content hash, because encryption is random.
The page always says which hash it shows.

**Inventory.** A file, signed with the device key, that lists what the store must hold: the object
hash of each current item and each item inside its retention period, the byte digests of the
keyrings and `recipients.txt`, and the verification key, sequence and log head of each device. Its
values are already visible on the drive, so it can be read while locked.

The box writes logs and inventories to a temporary file, syncs it and renames it, and keeps the
previous inventory until the new one is safe. It writes the new inventory before it removes an
expired object. A log head that is ahead of the inventory means that the inventory is out of date,
and the box rewrites it at the next unlock. A log head that is behind the inventory is **Damaged**.

| What the store check finds | Result |
|---|---|
| An object in the inventory is missing or its hash is wrong | **Damaged**, with the file named if unlocked |
| An object in `inbox/` | Counted as a deposit waiting. It is not covered until the next unlock |
| Any other object not in the inventory | Counted as unknown and shown to the owner |
| Objects exist but no inventory is valid | **Damaged**, "inventory missing" |
| A new box with no objects and no inventory | **Not checked** |
| A restore is still copying | **Restoring**. Objects still to come are not damage |

**What each check can trust.** While locked, the box checks the inventory with a public key from
the same drive, so a locked check finds accidents and not a person with write access. At each
unlock, the box uses the device key from the keyring. It also rebuilds `recipients.txt` from the
keyring, and it reports any difference.

**Deposit receipt.** The browser hashes the file as it sends it. The box hashes the same bytes
before it encrypts them. If the two hashes differ, the upload fails. After the write, the box
decrypts the object in the background and hashes it again. The file shows **Checking**, then
**Checked**, and the file page shows the content hash. This is a box report, because the box
also serves the browser code.

**Check by hand.** These results are **Proven**, because the owner's computer does the work.

- Download a file and compare its SHA-256 with your own copy.
- Connect a USB backup to your computer and run `boxcrypt verify <path>`. It uses the pinned device
  key. On a new computer, it asks for the device public key from the recovery kit. It checks the
  inventory, each log chain up to its signed head, the digest of each keyring and each object. It
  needs no passphrase. The result gives the date and sequence of the inventory, and it warns if
  they are older than the newest this computer has seen. It shows that the copy matches what the
  box signed at that time. It does not show that the copy is the newest one, and only a restore
  shows that the files open.

## Limits

- **Live kernel compromise.** The proof shows what booted, not what is in memory now. An
  attacker who takes the kernel after a genuine boot still passes.
- **Firmware.** The firmware makes the first measurements, so changed firmware could send false
  ones. Firmware and hardware bugs can also let software reset a TPM without a real restart, and
  then replay good measurements. See ADR-027 for a box that you bought.
- **No TPM.** The software proof is not available, and the Software section says "cannot be
  proven". The data checks still work as box reports. See the hardware table in the
  [roadmap](../roadmap.md).
- **A compromised box can give false box reports.** Only the checks by hand and the software
  proof do not depend on it.
- **A compromised box can sign a false inventory.** `boxcrypt verify <path>` shows that a copy
  matches what the box signed. Compare a file with your own copy to check the content.
- **A hash shows no change since the first hash.** An error in memory before that point is
  not found, so ECC RAM is better when the computer supports it.
- **Older data can pass.** Someone with write access to the drive can put back an older signed
  inventory and its logs, for the whole disk or only for recent changes. The checks then pass and
  the later changes are gone. One box cannot detect this alone.
- **Deposits made while locked** are not covered until the next unlock. Someone with write access
  can change them, or change `recipients.txt` so that those deposits go to another key. The next
  unlock reports the changed recipients, after the deposit is made.
- **Rollback memory is per computer.** A new computer has no memory of a newer release, so it can
  report an older signed release as **Genuine**.
- **Dates come from the box's clock,** and the box has no network time.
- **The owner's computer and the download.** The command trusts the computer that it runs on, and
  malware there can change its pins. A bad download of the command could lie, so check its
  signature, in the same way as the installer image.
- **The public answer** shows the release, the reset count and the event log to anyone on the LAN.
- **A security key does not work for a repair,** because the command runs in a terminal. Use an
  authenticator code or the recovery kit.

## Open questions

- Can the installer stick enroll a cleared TPM again without erasing the store?
- Can a TPM counter detect an older inventory without wearing out the TPM? Where can the device
  public key live so that a drive writer cannot replace it?
- `systemd-pcrlock` is still marked as experimental. Is it stable enough, or do we write the
  `PolicyOR` ourselves?
- Which firmware increases the reset count at each reboot, resists a reset and replay, and writes
  an event log that the command can replay? This needs real hardware.
- Two boxes restored from one backup write under one device identity. Sync must handle this.
- WebCrypto cannot hash a file in steps, so very large uploads need a small WASM hasher that
  fits the content security policy.

## Tests

- A VM with a software TPM boots a changed image. The proof fails and the TLS key does not open.
- Replacing only the kernel image, or only the boot loader, makes the proof fail and the key refuse.
- A credential or add-on placed on the boot partition makes the proof fail.
- A replayed answer, a relayed answer and an answer from another TPM all fail. A relay that holds a
  copy of the TLS key fails.
- A key without the required attributes fails enrollment, and so does a key that is not in the
  enrolled TPM.
- The restart check fails if the reset count does not go up. On real hardware, a TPM reset and
  replay without a restart must fail.
- An update, a rollback to the other slot and a firmware update each leave the owner able to log
  in, directly or through the repair.
- A deleted object, a replaced object and a damaged object each show **Damaged** and name the file.
- A normal deletion after its retention period shows no damage, including after a crash at each
  step.
- A log that is cut short fails the log check and fails `boxcrypt verify <path>`.
- A forged USB backup with a new device key fails `boxcrypt verify <path>`.
- An unfinished restore shows **Restoring** and no damage.
- A stopped run shows **Stopped**. A late check shows **Overdue**. A row without a date cannot
  show **OK**.
- A changed upload fails its receipt.
