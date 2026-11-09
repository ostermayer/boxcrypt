# Web UI

> **Status: design.** See ADR-010 and ADR-011.

## Purpose

The main way people use the box. It is served by `boxcryptd` on the local network
only.

## Pages

| Path | Access | Purpose |
|---|---|---|
| `/setup/*` | Setup code, first run only | Wizard, or restore |
| `/unlock` | Public | Enter the passphrase and a second factor |
| `/` | Unlocked | Home |
| `/items` | Unlocked | Passwords, notes and keys |
| `/files` | Unlocked | Files of any size |
| `/checks` | Unlocked | Software, drive, store and backup [checks](checks.md) |
| `/backup` | Unlocked | Backup drives and recovery kit test |
| `/apps` | Unlocked | Add-on apps |
| `/settings` | Unlocked | Device name, passphrase, [safeguards](safeguards.md), updates, clock, device information, restart, shut down, factory reset |
| `/help` | Unlocked | Task guides, glossary and the first-look tour |
| `/ca.crt` | Public | Certificate for devices to trust |
| `/attest` | Public | Signed proof of what booted, for `boxcrypt verify` |

The address is `https://boxcrypt.local` until the owner changes the device name.

## First run

Umbrel's setup is the model for this flow. Everything happens in the browser, and each
screen asks for one thing.

1. **Start.** A language choice and one button. The footer offers "Restore from backup"
   and a link to get help.
2. **Storage.** The drives found, and the space available. Mirroring is on by default and
   is explained as "Your data stays safe if a drive fails". With one drive, the page says a
   second drive can be added later. With mixed sizes, it says the smallest drive sets the
   limit.
3. **Account.** A name and a passphrase, entered twice, with a strength meter. The page says
   the data is stored only on this device, and that only the recovery kit can reset the
   passphrase.
4. **Recovery kit.** Save it, then prove that it works.
5. **Trust this device.** Install the certificate, with steps for each kind of device.
6. **Second factor.** Enroll a YubiKey or an authenticator app, and use it once. This step
   is required. See [two-factor login](two-factor.md).
7. **Backup drive.** Set one up now, or skip and receive a reminder.
8. **Finished.** "You are all set, Name."

After setup:

- The unlock page greets the owner by name.
- Settings show the device model, memory, storage and software version.
- Factory reset first lists what it will remove, then asks for the passphrase.
- A "Support the project" link opens in the owner's browser. The device makes no request.

## Design language

Umbrel's visual style is the guide. We follow the feel and write everything ourselves,
with no Umbrel code, assets or branding.

- Inter type, self-hosted
- A dark wallpaper behind frosted-glass panels with background blur
- Soft inner highlights and deep drop shadows
- Generous rounded corners
- A dock for moving between sections
- Orange as the one accent colour

Accessibility is required: visible keyboard focus, sufficient contrast, labels for
screen readers, and solid backgrounds under `prefers-reduced-transparency`.

## Language

Say Secrets, Files, Passphrase, Recovery kit and Backup drive. Never show ZFS, Nix,
TLS or generation numbers in normal use.

## Help and tutorials

The device cannot reach the internet, so all help ships in the image.

- **One-line explanation.** Each setting has one under its label, in plain words and in
  normal text.
- **Help note.** Each setting and technical term has a `?` button. The note says what it
  does, when to use it and what can go wrong. It opens on click, tap or keyboard focus,
  never on hover alone. `Esc` closes it, and screen readers announce it.
- **Guided steps.** A setting that can destroy data opens step by step. It explains the
  result, checks what must be ready, asks for confirmation and offers a test.
- **First-look tour.** After setup, a tour of at most four stops. You can skip it, and
  start it again from Help.
- **Task guides.** Short guides on the Help page: add a secret, trust a new browser, set
  up a backup drive, test the recovery kit, replace a failed drive, restore to a new box
  and turn on Wi-Fi.
- **Empty pages teach.** An empty page says what goes there and has the button to add it.
- **Errors help.** An error says what happened and what to do next.

The web UI and the TUI use one catalog of help text, in Simplified Technical English. A
test fails if a setting has no help text.

## Security

- Requests with an unexpected `Host` are refused, which stops DNS rebinding.
- Session cookies are `Secure`, `HttpOnly` and `SameSite=Strict`.
- Pages load no external assets, under a strict CSP with no inline scripts.
- Each login needs a second factor. See [two-factor login](two-factor.md).
- Failed unlocks are rate limited. See [safeguards](safeguards.md).
- The setup code holds at least 128 bits of randomness and works once. Setup closes when
  the wizard finishes, and after too many wrong codes.

## Certificates

The box creates its own certificate authority at first run and issues a certificate
for its name, within the 825-day limit iOS enforces. Renewal happens while
unlocked, because the authority's key lives in the keyring. On a box with a TPM, the private
key of the certificate stays in the TPM. See [checks](checks.md).

The first visit shows a browser warning. The owner compares the fingerprint with the
one the installer showed, and the wizard then explains how to trust the certificate on
each device.

## Edge cases

- **Upload larger than RAM:** streamed, and not held in memory.
- **Tab left open:** when the box locks, the page returns to `/unlock` and shows no
  cached secrets.
