---
layout: default
title: "valt/archive"
parent: API Reference
nav_order: 999
---

# valt/archive

Secure archives.
Use via: require 'valt/archive'

## Functions

### newSecureArchive()

Create an encrypted, signed archive from one or more files, directories and archives. The archive file path is written to
standard output. Also creates the public version of the archive (same path plus ".pub" suffix). See NOTES below for details.


*usage*

`newSecureArchive ([-C DIR] INPUT...) -i PATH (-r RECIPIENT | -R PATH)... [-f] [-n NAME] [--zone ZONE] [-u TEXT] [-o DIR]`
{: .usage-signature}

| | |
|---|---|
| `-i,` | --identity PATH        The valt.key file used to sign the archive. |
| `-r,` | --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'. |
| `-R,` | --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the |
| `-f,` | --force                Overwrite any existing output file (default: fail). |
| `-n,` | --name NAME            Specify the archive file name prefix (default: ${USER}). |
| `-z,` | --zone ZONE            Specify the timezone to use for timestamps, e.g. PDT (default: UTC). |
| `-u,` | --user-text TEXT       User text to include in readme. Can contain '\n'. |
| `-o,` | --output-dir DIR       Specify the archive destination directory path (default: ${PWD}). |
| `-C` | DIR                     Change to the specified directory before processing the remaining relative INPUT paths. |
| `INPUT...` | File, directory or @<archive> paths to add. An '@' prefixed file path is treated as a tar archive |
{: .usage-table}

*example*

```bash
newSecureArchive project/ -R valt.pub                                 # archive project/ dir to ${USER}.valt in ${PWD}
newSecureArchive project/ -R valt.pub -n backup -t -o ~/backups       # timestamped name, written to ~/backups
newSecureArchive -C ~/dev/ projectX foo.txt -R valt.pub               # -C sets source root ~/dev/ and adds subsequent inputs
newSecureArchive -C ~/dev/ projectX -C ~/docs/ notes.txt -R valt.pub  # each -C sets a new source root for subsequent inputs
```

*notes*


Encryption provides confidentiality while signatures provide authenticity/integrity:

  - Files can be stored somewhere less trusted (cloud, shared NAS).
  - Corruption or tampering can be detected with confidence.
  - Provides a formal provenance chain for legal/financial docs.

Valt File Structure

```bash
backup-2026-05-28_23.14_PDT.valt
│
├── encrypted.tar.xz.age
│   ├── payload.tar
│   ├── payload.tar.minisig
│   ├── minisign.pub
│   ├── age.pub
│   └── README.txt
├── encrypted.tar.xz.age.minisig
├── minisign.pub
├── age.pub
└── README.txt
```

The encrypted tar structure ensures there is always a valid payload signature to use even if the outer one is missing or
tampered with. The unencrypted files can be shared publicly and are packaged as a separate file:

```bash
backup-2026-05-28_23.14_PDT.valt.pub
│
├── encrypted.tar.age.minisig
├── minisign.pub
├── age.pub
└── README.txt
```

This file can be recreated from the original via the extractPublicArchive function.

Only tar, age and minisign are required for access to the contents of a valt archive. The verifySecureArchive and
extractSecureArchive functions simplify the process.

### verifySecureArchive()

Verify the signatures of a secure archive. Checks both the outer encrypted archive signature
and the inner payload signature (requires decryption with the private key).


*usage*

`verifySecureArchive ARCHIVE -i PATH`
{: .usage-signature}

| | |
|---|---|
| `ARCHIVE` | Path to the .valt archive file. |
| `-i,` | --identity PATH  The valt.key file used to decrypt and verify signatures. |
{: .usage-table}

### extractSecureArchive()

Verify and extract the contents of a secure archive into a directory.
Checks both the outer and inner signatures before extracting the payload.


*usage*

`extractSecureArchive ARCHIVE -i PATH [-o DIR]`
{: .usage-signature}

| | |
|---|---|
| `ARCHIVE` | Path to the .valt archive file. |
| `-i,` | --identity PATH  The valt.key file used to decrypt and verify signatures. |
| `-o,` | --output-dir     Directory to extract contents into (default: ${PWD}). |
{: .usage-table}

### extractPublicArchive()

Extract the public portion of a secure archive, creating a .valt.pub file alongside it.
The .valt.pub contains the signature, public keys, and README but not the encrypted payload,
making it safe to share publicly. Useful when the .valt.pub was not retained from creation.


*usage*

`extractPublicArchive ARCHIVE`
{: .usage-signature}

| | |
|---|---|
| `ARCHIVE` | Path to the .valt archive file. |
{: .usage-table}

