# Testing

All tests run in virtual machines. No test has run on real hardware yet.

## Run the tests

You need Nix with flakes on x86-64 Linux, with KVM.

```sh
nix flake check                                 # all tests
nix build .#checks.x86_64-linux.network         # one test
```

## What each test proves

| Test | Proves |
|---|---|
| `tests/network.nix` | The device takes an address but no route, and answers to `boxcrypt.local`. Only the allowed web port answers. The device cannot connect out, even with a route. It does not configure USB network adapters. A device whose firewall fails stays off the network. Only the network services can send on the DHCP and mDNS ports. The device keeps its multicast membership and renews its lease. |
| `tests/security.nix` | Kernel settings and parameters are applied. SSH, sudo, Nix and login prompts are absent. Root is locked. Radios stay off. |
| `tests/wifi.nix` | Wi-Fi drivers cannot load until the owner chooses Wi-Fi. After that, the device joins a network, gets no route, and keeps the same firewall. |
| `tests/verified-boot.nix` | The device runs from a read-only system. The kernel refuses a changed block. Files on `/persist` cannot run directly. Kernel modules lock after boot. |
| `tests/install.nix` | The installer builds a mirror. It refuses machines without UEFI or with Secure Boot on, active pools, drives in use and cancelled installs. A scrub repairs a damaged drive, in a mirror and on one drive. It leaves USB drives alone. Each drive boots alone. A dataset planted in the pool is not mounted at boot. |

## Rules for tests

- A test that proves a block needs a control. The control shows that the same action
  works without the block. For example, the network test flushes the firewall, and the
  blocked traffic then succeeds.
- Wait until a service is ready before you test that it is blocked. Otherwise the test
  can pass for the wrong reason.
- Test the system that ships. If the test framework changes a setting, remove that change
  in the test.

## What the tests do not prove

- Behaviour on real firmware and hardware.
- Protection of the boot files. This is not built. See [Integrity](modules/integrity.md).
- Wi-Fi with kernel module locking. The Wi-Fi test loads its driver after boot, and the
  shipped system needs a restart.
- A rebuild from source. See the next section.

## Reproducible builds

Build the image on two machines from the same `flake.lock`, then compare the hashes:

```sh
nix build .#image --print-out-paths
sha256sum result/*.raw
```

The image was identical on two machines with different Nix versions. Both machines
downloaded prebuilt packages from the NixOS cache, so this result proves that image
assembly is deterministic. A full rebuild from source is a release gate for 1.0.

## Security review

Three external AI models review all code before it is complete: Codex (GPT-6 Astra),
Kimi K3.1 and DeepSeek V4.1 Flash. Each model receives the same brief and read-only
access. The brief does not include earlier findings.

A person or the author agent verifies each finding against the code before any change.
Some findings are wrong, so do not apply them without a check.

These reviews do not replace the independent security audit that 1.0 requires.
