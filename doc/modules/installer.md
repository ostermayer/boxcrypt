# Installer

> **Status: the install program is built**, without the setup code and Wi-Fi steps. The
> bootable USB image and the network flash are not.

## Purpose

Turn a PC into a BoxCrypt with no technical choices. There are two ways to do this: a
bootable USB image, or a network flash from another computer.

## Flow

1. Boot from USB. The image contains the complete system, so it needs no internet.
2. Stop if the computer does not boot with UEFI, if Secure Boot is on, or if the system
   image is damaged. A hash made at build time checks the whole image.
3. List internal drives by model and size, and show the storage plan.
4. If no TPM is found, explain that this machine cannot prove it has not been tampered
   with, and ask the owner to accept that before continuing.
5. Ask the owner to type `ERASE` to confirm.
6. Partition, build the pool and install, as described in [storage](storage.md).
7. With no cable connected, offer to join a Wi-Fi network.
8. Show a one-time setup code and the certificate fingerprint. The owner writes them down,
   because the device may never have a screen again.
9. Ask the owner to remove the stick and restart.

## Network flash

Use this for a computer that already runs Linux and accepts SSH, such as an old home
server. You do not need a screen, a keyboard or a USB stick on that computer. The computer
does not need internet access. See ADR-024.

1. On your own computer, run `boxcrypt-flash user@address` in a terminal. The tool checks
   the image hash on your computer and refuses to flash the computer it runs on. It stops
   if SSH does not already know the target's host key. Add the key yourself, after you
   compare its fingerprint on the target.
2. The tool makes two one-time keys on your computer: a client key, and an SSH host key for
   the installer.
3. The tool asks the target about UEFI, Secure Boot, `kexec` and RAM. It needs the image
   size, the installer size and 1 GiB more. These checks only help on an honest system.
4. The tool copies the installer, the image and the keys into RAM on the target.
5. The target starts the installer in RAM with `kexec`. The old system stops, so no drive
   is in use. If this step fails, restart the computer. Nothing was changed.
6. The tool reconnects and accepts only the host key that it made. Every internal drive can
   be erased, because the installer and the image are in RAM.
7. The same install program runs, with the same plan and drive rules. The plan shows drive
   serial numbers, so that you can check this is the right computer.
8. Your terminal shows the setup code and the certificate fingerprint. Confirm that you
   wrote them down, then type `ERASE`.
9. The install does not stop if the connection drops. The installer stays reachable until
   you confirm the result. It also removes old firmware boot entries.

**Use a USB stick for a computer that you do not trust.** During a network flash, the old
system controls the copy and `kexec`. Malware on it could fake the whole install, or stay
in the firmware, which an install does not erase.

The flash needs a network cable at first. After the install, the box has no SSH, so a second
flash needs a USB stick.

## Drive rules

- A drive is internal only if it is SATA, SAS, NVMe, eMMC or a VM disk, and is not
  removable. Anything else is left alone.
- External eSATA and SAS drives count as internal. The plan tells the owner to unplug any
  drive to keep.
- The drives the installer runs from, and all USB drives, are never touched. The plan names
  the drive the installer runs from.
- The install stops before any change if a drive is read-only or in use, if any storage
  pool is active, if the system image is damaged, or if the drives change after the owner
  approves the plan.
- Each partition is read back and compared with the image after it is written.
- SD cards are not erased. Extra namespaces on one NVMe drive are not mirrored.
- Every eligible internal drive is erased, including any it will not use, so no old operating
  system remains to take over at boot.

## Edge cases

- **No eligible drive:** explain and stop.
- **BIOS-only machine:** explain that UEFI is required and stop.
- **TPM switched off:** the installer cannot tell this from a missing TPM, so the warning
  suggests checking the BIOS for a setting such as Intel PTT or AMD fTPM.
- **Secure Boot on:** explain how to turn it off until signed boot is supported.
- **Failure midway:** there is no state to preserve. The installer shows the error, and the
  owner starts it again.
- **Old data:** erasing removes partitions and signatures and discards SSD blocks. It is not
  a forensic wipe, so hard drives can keep readable old data.
