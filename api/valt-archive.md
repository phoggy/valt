---
layout: default
title: "valt/archive"
parent: "Encryption"
grand_parent: API Reference
nav_order: 5
---

# valt/archive

Signed, encrypted secure archives of files and directories.

See [Secure Archives](#secure-archives) below for details.

## Functions

### newSecureArchive()

Create an encrypted, signed archive from one or more files, directories and archives. The archive file path is written to
standard output. Also creates the public version of the archive (same path plus ".pub" suffix) unless --no-public. See
Secure Archives below for details.


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

Extracts the public portion of a secure archive, writing ARCHIVE.pub (e.g. NAME.valt.pub) alongside it. It holds
the signature, public keys and README but not the encrypted payload, so is safe to share publicly. Useful when the
.pub file was not kept from creation.


*args*

| | |
|---|---|
| `archive` *(file)* | Path to the secure archive (.valt) file. |
{: .args-table}


## Secure Archives

A secure archive (a `.valt` file) holds any number of files and directories, encrypted with age to one or more
recipients and signed with minisign. Encryption keeps the contents private; the signatures prove who made it and that
nothing has changed since. So an archive can be stored somewhere less trusted, such as cloud storage or a shared NAS;
corruption or tampering is detected with confidence; and it gives a provenance chain, e.g. for legal or financial
documents.

It is a tar file. The files are packed in a payload, which is signed, then encrypted together with the signature,
the public keys and a README; the encrypted file is signed again, and kept next to its signature, the public keys and
a README with instructions for anyone opening it:

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

The signature inside the encryption means there is always a valid payload signature to check, even if the outer one is
missing or has been tampered with.

The unencrypted parts can be shared publicly, as a separate *public companion* (`.valt.pub`), which shows who made the
archive and lets anyone check its outer signature without being able to open it:

    backup-2026-05-28_23.14_PDT.valt.pub
    │
    ├── encrypted.tar.xz.age.minisig
    ├── minisign.pub
    ├── age.pub
    └── README.txt

`valt archive create` makes both; a missing public companion can be recreated from the archive (extractPublicArchive).

Opening an archive needs only tar, age and minisign, as its README explains; `valt decrypt` (or `valt archive
extract`) verifies both signatures and extracts it in one step, and `valt archive verify` checks it without
extracting.
