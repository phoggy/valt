---
layout: default
title: API Reference
nav_order: 2
has_children: true
---

# API Reference

Documentation for all public functions in rayvn's shared libraries.

### Encryption

| Library | Description |
|---|---|
| [valt/keys](/valt/api/valt-keys) | Key pair generation, verification and recipients. |
| [valt/encrypt](/valt/api/valt-encrypt) | Encryption with public keys or a passphrase. |
| [valt/decrypt](/valt/api/valt-decrypt) | Decryption with a private key or a passphrase. |
| [valt/sign](/valt/api/valt-sign) | File signing and verification with valt keys. |
| [valt/archive](/valt/api/valt-archive) | Signed, encrypted secure archives of files and directories. |

### Paper Keys

| Library | Description |
|---|---|
| [valt/paper-keys](/valt/api/valt-paper-keys) | Paper key PDF generation from your key info, and reminders to keep it current. |
| [valt/pdf](/valt/api/valt-pdf) | PDF generation from HTML. |
| [valt/node](/valt/api/valt-node) | Node.js and npm support, used for PDF generation. |

### Passwords

| Library | Description |
|---|---|
| [valt/password](/valt/api/valt-password) | Password and passphrase generation, secure input and strength estimates. |
| [valt/pwned](/valt/api/valt-pwned) | HaveIBeenPwned breach checking. |
| [valt/pinentry](/valt/api/valt-pinentry) | The valt pinentry program for passphrase input. |
