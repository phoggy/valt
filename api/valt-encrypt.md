---
layout: default
title: "valt/encrypt"
parent: "Encryption"
grand_parent: API Reference
nav_order: 2
---

# valt/encrypt

Encryption with public keys or a passphrase.

## Functions

### encrypt()

Encrypt input.


*usage*

`encrypt [INPUT | -v NAME] (-r RECIPIENT | -R PATH)... [-a] [-o PATH]`
{: .usage-signature}

| | |
|---|---|
| `encrypt` | `[INPUT | -v NAME] -p [-a] [-o PATH]` |
| `-r, --recipient RECIPIENT` | Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'. |
| `-R, --recipient-file PATH` | Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the newRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input for decryption. Can be repeated. |
| `-a, --armor` | Encrypt to a PEM encoded format. |
| `-p, --passphrase` | Encrypt with a passphrase which will be requested via prompt. Cannot be combined with recipients. |
| `-v, --var NAME` | Encrypt the value of scalar shell variable NAME. Cannot be combined with INPUT path. |
| `-o, --output PATH` | Write the result to the file at PATH (default: standard output). Any existing file will be overwritten. |
| `[INPUT]` | Optional file path (default: standard input). If INPUT is a directory, it will be converted to a tar file before encryption. Path cannot be combined with `-v` / `--var`. |
{: .usage-table}

*example*

```bash
local test="my secret"
echo "${test}" | encrypt -R "${keyDir}/valt.pub" -o "test.enc"  # Encrypt content of stdin using public key to test.enc file.
encrypt -v test -R "${keyDir}/valt.pub" -o "test.enc"           # Encrypt value of test var using public key to test.enc file.
encrypt "test.txt" -R "${keyDir}/valt.pub" -o "test.enc"        # Encrypt test.txt file to test.enc file.
encrypt "foo" -R "${keyDir}/valt.pub"  -o "foo.tar.xz"          # Encrypt tar file created from foo directory.
```

