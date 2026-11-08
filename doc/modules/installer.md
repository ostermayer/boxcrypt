# Installer

> **Status: design.**

## Purpose

A bootable USB image that turns a PC into a cryptbox with no network access and no
technical choices.

## Flow

1. Boot from USB. The image contains the complete system, so it needs no internet.
2. List internal drives by model and size, and show the storage plan.
3. If no TPM is found, explain that this machine cannot prove it has not been tampered
   with, and ask the owner to accept that before continuing.
4. Ask the owner to type `ERASE` to confirm.
5. Partition, build the pool and install, as described in [storage](storage.md).
6. Ask the owner to remove the stick and reboot.

## Drive rules

- A drive is internal unless its transport is USB or it is marked removable.
- The installer stick and all USB drives are never touched.
- Every internal drive is erased, including any it will not use, so no old operating
  system remains to take over at boot.

## Edge cases

- **No eligible drive:** explain and stop.
- **BIOS-only machine:** explain that UEFI is required and stop.
- **TPM switched off:** the installer cannot tell this from a missing TPM, so the warning
  suggests checking the BIOS for a setting such as Intel PTT or AMD fTPM.
- **Secure Boot on:** explain how to turn it off until signed boot is supported.
- **Failure midway:** there is no state to preserve. Show the error and offer a retry.
