# Sync

> **Status: stub, planned after 1.0.** See ADR-008 and ADR-009.

## Purpose

Mirror a tenant across boxes in different places, so a copy survives losing a device,
a building or a location.

## Intended behaviour

- Boxes pair by exchanging public keys, in person or through a trusted channel.
- Each box lists its objects and logs, and fetches what it lacks. Objects are immutable
  and hash-named, so there is nothing to merge at that level.
- A box that holds the keys merges all logs into one view. The newest change to an item
  wins, and earlier versions remain in history.
- A box hosting someone else's tenant stores ciphertext only and never receives keys.

## Open questions

- The transport between boxes, given that BoxCrypt has no route out by default.
- How a host enforces quotas on a tenant it cannot read.
- Peer health reporting, and what counts as a safe copy.
