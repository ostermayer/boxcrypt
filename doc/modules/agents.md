# Agents

> **Status: stub, planned after 1.0.**

## Purpose

Let automated agents place secrets on the box and obtain signatures, without ever
giving them standing access to what is stored.

## Deposits

- The owner clicks "Add agent" and gives it a one-time pairing string containing a
  scoped token and the public keys.
- The agent encrypts the value and a suggested name before sending, so plaintext never
  reaches the box.
- Deposits land in that agent's inbox, marked unreviewed, and work while locked.
- An agent cannot read, list or overwrite anything.

Agents should pass a file or environment variable instead of the value, for example
`cryptbox put stripe/prod --from-file key.txt`, so the secret stays out of the model's
transcript.

## Reads

An agent can ask to read a secret, but only the owner can approve it, directly on the
box. A grant covers one secret, one read and a few minutes by default, and is delivered
encrypted to a key the agent generated for that request.

## Signing

Signing keys live in the store and are used only while unlocked. Each agent is enabled
per key and can only request signatures, within a policy, with every request logged.
Ed25519 and secp256k1 are both intended, so SSH, git and Bitcoin signing are all
possible.

A compromised agent cannot steal a key, but it can request any signature its policy
allows.

## Open questions

- Per-agent size and rate limits.
- Whether signing should be allowed unattended, or always require confirmation.
