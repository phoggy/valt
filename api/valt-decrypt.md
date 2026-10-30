---
layout: default
title: "valt/decrypt"
parent: API Reference
nav_order: 999
---

# valt/decrypt

Encryption using age.
Use via: require 'valt/decrypt'

## Functions

### decrypt()

Decrypt input.


*usage*

`decrypt -i PATH [-o PATH] [INPUT]`
{: .usage-signature}

| | |
|---|---|
| `decrypt` | --passphrase [-o PATH] [INPUT] |
| `-i,` | --identity PATH  Use the valt private key file (identity) at PATH; requires passphrase input to decrypt. Can be repeated. |
| `-p,` | --passphrase     Decrypt with a passphrase which will be requested via prompt. Cannot be combined with an identity. |
| `-o,` | --output PATH    Write the result to PATH. Any existing file will be overwritten (default: standard output). |
| `[INPUT]` | Optional path to encrypted file (default: standard input). |
{: .usage-table}

