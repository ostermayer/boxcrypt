# Glossary

| Term | Meaning |
|---|---|
| **age** | A file encryption format and tool. BoxCrypt stores each secret as one age file. |
| **Agent** | An automated program, often AI, that uses BoxCrypt through a limited token. |
| **dm-verity** | A Linux feature that checks each block of a read-only disk against a hash. The kernel refuses a changed block. |
| **Erase passphrase** | A second passphrase. When you enter it, the device erases the store. |
| **EROFS** | A read-only Linux file system. BoxCrypt uses it for the system partition. |
| **ESP** | EFI System Partition. It holds the files that the firmware starts. |
| **FIDO2** | A standard for security keys, such as a YubiKey. Browsers use it through WebAuthn. |
| **Keyring** | The encrypted file that holds the keys for the store. |
| **MCP** | Model Context Protocol. A standard way to give an LLM tools. |
| **mDNS** | Multicast DNS. It lets a device answer to a `.local` name on the local network. |
| **Mirror** | Two or more drives that hold the same data. The data stays available if a drive fails. |
| **NixOS** | A Linux distribution. One configuration in this repository defines the whole system. |
| **Passphrase** | The secret that you type to unlock the device. |
| **Recovery key** | A second key that also opens the keyring. Keep it away from the device. |
| **Scrub** | A full read of each drive that compares each block with its checksum and repairs damage. |
| **Sealed item** | A key that the device can sign with but never shows or exports. |
| **Second factor** | Something you have, which each login needs with the passphrase: a security key or an authenticator app. |
| **Secure Boot** | A firmware feature that starts only signed boot files. |
| **Store** | The encrypted collection of secrets and files. |
| **TOTP** | Time-based one-time password. The 6-digit code in an authenticator app. |
| **TPM** | Trusted Platform Module. A security chip that records what started on the computer and can hold secrets until those records match. |
| **TPM quote** | A record of what started on the computer, signed by a key that cannot leave the TPM. |
| **TUI** | Text user interface. It operates on the screen of the device. |
| **UEFI** | The modern firmware standard for starting a computer. |
| **ZFS** | A file system that mirrors drives and detects damaged data. |
