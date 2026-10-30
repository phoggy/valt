---
layout: home
title: Home
nav_order: 1
---

# valt

Public key encryption for files and archives, using [age](https://age-encryption.org/) and
[minisign](https://jedisct1.github.io/minisign/), built on [rayvn](/rayvn).

valt creates a passphrase-protected key pair, plus a printable *paper key*: a PDF that backs up the key and explains to
your successors, step by step, how to use it. Files are encrypted to your own key (and optionally to others), and signed
so that tampering is detected on decryption. Any number of files and directories can be kept together in a signed,
encrypted *secure archive*.

## First Look

```bash
valt keys                          # create valt.key and valt.pub (and the paper key, once key.info is complete)
valt encrypt taxes.pdf             # writes taxes.pdf.age and taxes.pdf.age.minisig
valt decrypt taxes.pdf.age         # verifies the signature, writes taxes.pdf
valt archive create -C ~/docs .    # writes USER-TIMESTAMP.valt and a shareable .valt.pub
valt decrypt USER-TIMESTAMP.valt   # verifies and extracts into the current directory
valt passphrase --check            # rates a passphrase and checks it against known breaches
```

- Keys default to `valt.key` and `valt.pub` in the valt config directory; most commands take `-i KEY_FILE` to use another.
- Your own key is always a recipient. Add others with `-r AGE_PUBLIC_KEY` or `-R their.pub`, or leave yours out with
  `--no-self`.
- The private key is only as safe as its passphrase, so `valt keys` rejects weak or breached ones. `valt passphrase`
  generates strong, memorable ones.

See the [CLI reference](/valt/cli/) for every command and option.

## Install

```bash
nix profile add github:phoggy/valt        # or: brew tap rayvn-central/brew && brew install valt
```

See the [README](https://github.com/phoggy/valt#readme) for installing Nix and other options.

## Recovery

Whoever holds your paper key needs only [Nix](https://nixos.org/download/), not valt, to recover a file or archive:

```bash
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```

The paper key also explains how to recover without Nix, using `age` and `tar` directly, and how to rebuild the key file
from its QR code or printed text.

## Libraries

### Encryption

| Library | Description |
|---|---|
| [valt/keys](/valt/api/valt-keys) | Key pair generation, verification and recipients. |
| [valt/encrypt](/valt/api/valt-encrypt) | Encryption to public keys or a passphrase. |
| [valt/decrypt](/valt/api/valt-decrypt) | Decryption with a private key or a passphrase. |
| [valt/sign](/valt/api/valt-sign) | File signing and verification with valt keys. |
| [valt/archive](/valt/api/valt-archive) | Signed, encrypted secure archives of files and directories. |

### Paper Keys

| Library | Description |
|---|---|
| [valt/paper-keys](/valt/api/valt-paper-keys) | Paper key PDF generation from key.info, and reminders to keep it current. |
| [valt/pdf](/valt/api/valt-pdf) | PDF generation from HTML. |
| [valt/node](/valt/api/valt-node) | Node.js and npm support, used for PDF generation. |

### Passwords

| Library | Description |
|---|---|
| [valt/password](/valt/api/valt-password) | Password and passphrase generation, secure input and strength estimates. |
| [valt/pwned](/valt/api/valt-pwned) | HaveIBeenPwned breach checking. |
| [valt/pinentry](/valt/api/valt-pinentry) | The valt pinentry program for passphrase input. |

## Related Projects

- [rayvn](/rayvn) — the shared library framework valt is built on
- [wardn](/wardn) — encrypted Bitwarden vault backups *(renovating, coming soon)*
