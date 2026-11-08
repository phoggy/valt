---
layout: default
title: "valt/archive"
parent: "Encryption"
grand_parent: API Reference
nav_order: 5
---

# valt/archive

Signed, encrypted secure archives of files and directories.

## Functions

### newSecureArchive()

Create an encrypted, signed archive from one or more files, directories and archives. The archive file path is written to
standard output. Also creates the public version of the archive (same path plus ".pub" suffix) unless --no-public. See
NOTES below for details.


*usage*

`newSecureArchive ([-C DIR] INPUT...) -i PATH (-r RECIPIENT | -R PATH)... [-f] [-n NAME] [-z ZONE] [-u TEXT] [-o DIR]`
{: .usage-signature}

| | |
|---|---|
| `-i, --identity PATH` | The valt private key file used to sign the archive. |
| `-r, --recipient RECIPIENT` | Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'. |
| `-R, --recipient-file PATH` | Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the newRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input for decryption. Can be repeated. |
| `-f, --force` | Overwrite any existing output file (default: fail). |
| `-n, --name NAME` | Specify the archive file name prefix (default: ${USER}). |
| `-z, --zone ZONE` | The time zone for the timestamp in the name: 'local' (the system time zone), 'UTC', or a zone name such as 'America/Los_Angeles' (default: local). |
| `-u, --user-text TEXT` | User text to include in readme. Can contain '\n'. |
| `-o, --output-dir DIR` | Specify the archive destination directory path (default: ${PWD}). |
| `--no-mac-metadata` | Do not keep the macOS metadata (extended attributes such as Finder tags, ACLs and file flags) of the INPUT files. It is kept by default, but only macOS tar restores it; other tars may warn about it. Metadata is never kept for the archive's own files. |
| `--no-public` | Do not create the public companion (ARCHIVE.pub). |
| `-C DIR` | Change to the specified directory before processing the remaining relative INPUT paths. |
| `INPUT...` | File, directory or @<archive> paths to add. An '@' prefixed file path is treated as a tar archive whose contents should be extracted and added. |
{: .usage-table}

*example*

```bash
newSecureArchive project/ -R bob.pub                                  # archive project/ dir to ${USER}.valt in ${PWD}
newSecureArchive project/ -R bob.pub -n backup -t -o ~/backups        # timestamped name, written to ~/backups
newSecureArchive -C ~/dev/ projectX foo.txt -R bob.pub                # -C sets source root ~/dev/ and adds subsequent inputs
newSecureArchive -C ~/dev/ projectX -C ~/docs/ notes.txt -R bob.pub   # each -C sets a new source root for subsequent inputs
```

*notes*


Encryption provides confidentiality while signatures provide authenticity/integrity:

  - Files can be stored somewhere less trusted (cloud, shared NAS).
  - Corruption or tampering can be detected with confidence.
  - Provides a formal provenance chain for legal/financial docs.

**Valt file structure**

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

The encrypted tar structure ensures there is always a valid payload signature to use even if the outer one is missing or
tampered with. The unencrypted files can be shared publicly and are packaged as a separate file:

    backup-2026-05-28_23.14_PDT.valt.pub
    │
    ├── encrypted.tar.xz.age.minisig
    ├── minisign.pub
    ├── age.pub
    └── README.txt

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
| `-i, --identity PATH` | The valt private key file used to decrypt and verify signatures. |
{: .usage-table}

### extractSecureArchive()

Verify and extract the contents of a secure archive into a directory.
Checks both the outer and inner signatures before decrypting and extracting the payload.


*usage*

`extractSecureArchive -i PATH [-o DIR] ARCHIVE`
{: .usage-signature}

| | |
|---|---|
| `ARCHIVE` *(file)* | The secure archive file to extract. |
| `-i, --identity PATH` *(file)* | The valt key file used to decrypt and verify signatures. |
| `-o, --output-dir DIR` *(dir)* | Directory to extract contents into (default: ${PWD}). |
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

