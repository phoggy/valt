---
layout: home
title: Home
nav_order: 1
---

# valt

Encrypted file archives using [age](https://github.com/FiloSottile/age) encryption, built on [rayvn](/rayvn).

valt creates encrypted `.tar.xz` archives protected with age key pairs. Private keys are themselves passphrase-encrypted for safe storage anywhere.

## Libraries

| Library | Description |
|---|---|
| [valt/age](/valt/api/valt-age) | age key pair creation, verification, and file armoring |
| [valt/password](/valt/api/valt-password) | Password and passphrase generation and secure input |
| [valt/pwned](/valt/api/valt-pwned) | HaveIBeenPwned breach checking |
| [valt/pinentry](/valt/api/valt-pinentry) | Custom pinentry integration |
| [valt/pdf](/valt/api/valt-pdf) | PDF generation from HTML |

## Getting Started

```bash
# Install via Nix
nix run github:phoggy/valt

# Create an encrypted archive
valt create myarchive.age myfiles/
```

## Related Projects

- [rayvn](/rayvn) — the shared library framework valt is built on
- [wardn](/wardn) — encrypted Bitwarden vault backups
