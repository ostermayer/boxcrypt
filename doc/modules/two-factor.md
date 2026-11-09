# Two-factor login

> **Status: design.** See ADR-025.

## Purpose

Every login to the web UI and the TUI needs the passphrase and a second factor. The second
factor is mandatory. The owner cannot turn it off.

## Supported factors

| Factor | Web UI | TUI over SSH | TUI on a connected screen | Needs a correct clock |
|---|---|---|---|---|
| YubiKey or other FIDO2 security key | Touch the key (WebAuthn) | An `sk-` SSH key on the key | The key in a USB port of the box | No |
| Authenticator app (TOTP) | 6-digit code | 6-digit code | 6-digit code | Yes |

The long string that a YubiKey types in its one-time password mode is not supported, because
it is checked by a Yubico server and the box has no internet. A YubiKey can use WebAuthn, or
hold TOTP codes in Yubico Authenticator.

## Rules

- Setup cannot finish until you enroll a second factor and use it once.
- Setup asks you to add another one, so that one lost key does not lock you out.
- You cannot remove the last second factor.
- To add or remove a second factor, you must enter the passphrase and a second factor.
- Each new session needs both, even when the box is already unlocked.
- Agent tokens are for programs and do not open a login. See [agents](agents.md).

## Order of checks

The login page has one form and shows one error: "Wrong passphrase or second factor". The
box then checks in this order:

1. The second factor.
2. The passphrase, only if step 1 passed.

This order has three results:

- A device without a valid second factor cannot make a passphrase guess. It cannot use up
  tries or start an erase. See [safeguards](safeguards.md).
- The slow passphrase check cannot be used to overload the box.
- The second factor can be checked while the keys are locked.

A wrong second factor never counts toward an erase. It is only rate limited.

## Security keys

- The box stores only the public key.
- WebAuthn needs an HTTPS certificate that the browser trusts, so setup installs the
  certificate before it enrolls a key.
- A key is enrolled for one device name. To change the name, you enroll the key for the new
  name before the box switches to it.

## Authenticator apps

- Codes use SHA-1, 6 digits and 30 seconds, because all authenticator apps support them.
  The secret has 160 bits. Setup shows a QR code. The TUI draws it as text and also shows
  the secret.
- Each code works once. The box writes the last used time step to disk before it accepts a
  code.
- The box accepts one time step before or after the current one, and records the drift of
  its clock at each login.
- Wrong codes are rate limited for each source and for the whole box.
- The box must read the secret while it is locked. With a TPM, the TPM seals it.

## Limits

- A second factor protects the login. It does not encrypt the store. Without TPM protection,
  a person who copies the drives needs only the passphrase. See [safeguards](safeguards.md).
- Without a TPM, a copy of the drives also reveals the authenticator secret.
- A person with your key or your authenticator secret can use up the tries.
- A device that floods wrong codes can slow logins that use a code. Security keys are not
  affected.

## Recovery

If you lose every second factor, use the recovery kit in any browser. The recovery key is too
long to guess, so it replaces both the passphrase and the second factor. After that, the box
asks you to enroll a new second factor before it does anything else.

## Edge cases

- **The clock is wrong:** authenticator codes fail. Use a security key or the recovery kit.
  After you log in, the web UI offers to correct the clock.
- **Restore from a backup:** second factors do not come back with the data. The wizard asks
  you to enroll one.
- **USB ports set to allow nothing:** a security key cannot work on the box's own screen. Use
  an authenticator code there.
