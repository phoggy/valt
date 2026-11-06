---
layout: default
title: "valt/decrypt"
parent: "Encryption"
grand_parent: API Reference
nav_order: 3
---

# valt/decrypt

Decryption with a private key or a passphrase.

## Functions

### decrypt()

Decrypt input using age, via identity key or passphrase.


*usage*

`decrypt -i IDENTITY [-o OUTPUT] [INPUT]`
{: .usage-signature}

| | |
|---|---|
| `decrypt` | `-p [-o OUTPUT] [INPUT]` |
| `-i, --identity IDENTITY` *(file)* | The valt private key file to decrypt with; its passphrase is requested via prompt. Cannot be combined with `-p`. |
| `-p, --passphrase` | Decrypt with a passphrase requested via prompt. Cannot be combined with `-i`. |
| `-o, --output OUTPUT` *(file)* | Write decrypted output to file, replacing any existing file (default: stdout). |
| `[INPUT]` *(file)* | Encrypted input file, binary or armored (detected automatically) (default: stdin). |
{: .usage-table}

### isAgeEncryptedFile()

Succeeds if the file is age encrypted (binary or armored), judged by its header.


*args*

| | |
|---|---|
| `file` *(file)* | The file to check. |
{: .args-table}

