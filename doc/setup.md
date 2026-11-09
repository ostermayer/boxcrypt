# Setup

> **Status: design.** Nothing here is installable yet.

## Installing a box

You need:

- An x86-64 PC with UEFI, and wired Ethernet (recommended) or Wi-Fi
- A monitor and keyboard, for the installation only
- A USB stick of at least 8 GB for the installer
- A second USB drive for backups

Installing erases every internal drive. USB drives are never touched.

1. Download the image from the releases page and check its signature.
2. Write it to the USB stick with any image writer.
3. Boot the PC from the stick and confirm the drives it lists.
4. Write down the one-time setup code and the certificate fingerprint that the screen
   shows.
5. Remove the stick and restart when asked. You can then disconnect the monitor and
   keyboard.
6. On another device on the same network, open `https://boxcrypt.local` and follow the
   wizard.

The wizard takes you through choosing a passphrase, saving your recovery kit,
setting up a backup drive and trusting the box's certificate on your devices.

## Restoring onto a new box

Install as above, then choose **Restore from backup** on the first screen. Plug in
your backup drive and enter your passphrase. The box returns with the same address
and certificate.

## Developing BoxCrypt

Building and VM tests need Nix with flakes on x86-64 Linux, with KVM available.

```sh
nix flake check          # unit tests and VM tests
nix build .#image        # the system image
```

Read [decisions.md](decisions.md) before changing anything structural.

Never commit real addresses, hostnames, device names or keys. This repository is
public.
