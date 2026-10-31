---
layout: default
title: "valt/sign"
parent: "Encryption"
grand_parent: API Reference
nav_order: 4
---

# valt/sign

File signing and verification with valt keys.

## Functions

### signFile()

Sign a file using a valt private key, creating a detached signature file.


*usage*

`signFile keyFile targetFile [signatureFile]`
{: .usage-signature}

| | |
|---|---|
| `keyFile` *(string)* | Path to the valt private key file. |
| `targetFile` *(string)* | Path to the file to sign. |
| `signatureFile` *(string)* | Optional path for the signature output file (default: targetFile.minisig). |
{: .usage-table}

### verifyFileSignature()

Verify the signature of a file using a valt key. Accepts either a public or private key.


*usage*

`verifyFileSignature keyFile targetFile [signatureFile]`
{: .usage-signature}

| | |
|---|---|
| `keyFile` *(string)* | Path to a valt .pub or .key file. |
| `targetFile` *(string)* | Path to the file to verify. |
| `signatureFile` *(string)* | Optional path to the signature file (default: targetFile.minisig). |
{: .usage-table}

