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
`boxcrypt put stripe/prod --from-file key.txt`, so the secret stays out of the model's
transcript.

## Reads

An agent can ask to read a secret, but only the owner can approve it, directly on the
box. A grant covers one secret, one read and a few minutes by default, and is delivered
encrypted to a key the agent generated for that request.

## Secrets for LLM agents

The value of a secret must never enter the model's context. Everything a tool returns
goes into the prompt, the transcript and the provider's logs. An MCP tool must therefore
never return a secret value. It returns a reference.

1. A small `boxcrypt-mcp` server runs on the agent's computer. Its tools are
   `request_secret`, `deposit` and `sign`.
2. The agent calls `request_secret` with a name and a reason.
3. The owner approves the request in the web UI.
4. A local helper fetches the secret, decrypts it on that computer and delivers it.
5. The tool returns only a reference, such as a variable name or a file path.

| Delivery | Example | Use |
|---|---|---|
| Environment variable for one command | `boxcrypt run --env STRIPE_KEY=stripe/prod -- npm run deploy` | The default |
| Temporary file | `/run/user/1000/boxcrypt/<id>` | A program that needs a file |

Temporary files have mode 0600, are held in RAM where the system allows it, and are deleted
after one use or a few minutes.

**The agent must give the path to a program and must not open the file.** If the model
reads the file, the value enters the prompt. The setup therefore adds a rule to the agent
harness that denies read access to that directory, and `boxcrypt run` removes the exact
value from command output.

This reduces exposure but cannot remove it. An agent with a shell can still print the
value. Owner approval, one-time grants, short lifetimes and the audit log limit the damage.

## Signing

Signing keys live in the store and are used only while unlocked. Each agent is enabled
per key and can only request signatures, within a policy, with every request logged.
Ed25519 and secp256k1 are both intended, so SSH, git and Bitcoin signing are all
possible.

A compromised agent cannot steal a key, but it can request any signature its policy
allows. A policy with no rules signs nothing. A rule can require the owner to approve
each signature on the box. Signing stops if the box cannot write the log.

## Open questions

- Per-agent size and rate limits.
- Whether signing should be allowed unattended, or always require confirmation.
