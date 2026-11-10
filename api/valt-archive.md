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
| `-m, --manifest PATH` | A manifest (JSON) saying what the archive is and how to restore it, for an archive made by another program, e.g. a wardn vault backup (default: one saying that it is a valt secure archive). See Manifests below. |
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
and the inner payload signature (requires decryption with the private key), and the manifest's, if any.


*usage*

`verifySecureArchive ARCHIVE -i PATH [--manifest-handler FN]`
{: .usage-signature}

| | |
|---|---|
| `ARCHIVE` | Path to the .valt archive file. |
| `-i, --identity PATH` | The valt private key file used to decrypt and verify signatures. |
| `--manifest-handler FN` | A function to call with the path of the archive's verified manifest, if it has one. |
{: .usage-table}

### extractSecureArchive()

Verify and extract the contents of a secure archive into a directory.
Checks both the outer and inner signatures before decrypting and extracting the payload.


*usage*

`extractSecureArchive -i PATH [-o DIR] [--manifest-handler FN] ARCHIVE`
{: .usage-signature}

| | |
|---|---|
| `ARCHIVE` *(file)* | The secure archive file to extract. |
| `-i, --identity PATH` *(file)* | The valt key file used to decrypt and verify signatures. |
| `-o, --output-dir DIR` *(dir)* | Directory to extract contents into (default: ${PWD}). |
| `--manifest-handler FN` | A function to call with the path of the archive's verified manifest, if it has one (see Manifests below), before extracting: extracting goes ahead only if it succeeds. |
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

### archiveRestorePathways()

Set the named array to the ways an archive's manifest offers to restore it that are available here, in order of
preference: 'installed' (its program is on the PATH), 'nix' (with Nix, running the program's pinned release without
installing it) and 'brew' (with Homebrew, installing the program first). Empty if it offers none, or none of them is
available.


*args*

| | |
|---|---|
| `manifestFile` *(file)* | The archive's manifest (see Manifests in the notes). |
| `pathwaysRef` *(arrayRef)* | Name of the array to set. |
{: .args-table}

*env vars*

| | |
|---|---|
| `rayvnTest_ArchiveCommands` | Test hook: the commands to treat as available, separated by spaces, instead of looking them up on the PATH. |
{: .args-table}

### runArchiveRestore()

Restore an archive the way its manifest says, by one of the ways archiveRestorePathways lists. Returns the
restoring program's status.


*args*

| | |
|---|---|
| `manifestFile` *(file)* | The archive's manifest. |
| `pathway` *(string)* | 'installed', 'nix' or 'brew'. |
| `archiveFile` *(file)* | The archive to restore. |
| `keyFile` *(file)* | The private key file to restore it with. |
{: .args-table}

### showArchiveRestoreCommands()

Output the commands to restore an archive the way its manifest says, one way per paragraph (with the program
installed, with Nix, with Homebrew), whether or not each is available here.


*args*

| | |
|---|---|
| `manifestFile` *(file)* | The archive's manifest. |
| `archive` *(string)* | The archive's path or name, as shown in the commands. |
| `keyFile` *(string)* | The private key file's path, or a placeholder such as '<private-key-file>'. |
| `[indent]` *(int)* | Spaces to indent by (default: 0). |
{: .args-table}


## Secure Archives

A secure archive (a `.valt` file) holds any number of files and directories, encrypted with age to one or more
recipients and signed with minisign. Encryption keeps the contents private; the signatures prove who made it and that
nothing has changed since. So an archive can be stored somewhere less trusted, such as cloud storage or a shared NAS;
corruption or tampering is detected with confidence; and it gives a provenance chain, e.g. for legal or financial
documents.

It is a tar file. The files are packed in a payload, which is signed, then encrypted together with the signature, a
signed manifest (see Manifests below), the public keys and a README; the encrypted file is signed again, and kept next
to its signature, the public keys and a README with instructions for anyone opening it:

    backup-2026-05-28_23.14_PDT.valt
    │
    ├── encrypted.tar.xz.age
    │   ├── payload.tar
    │   ├── payload.tar.minisig
    │   ├── manifest.json
    │   ├── manifest.json.minisig
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

### Manifests

Every archive has a manifest (`manifest.json`, inside the encryption and signed) saying what it is, with the valt and
archive format versions it was made with; by default, a valt secure archive:

    { "kind": "valt secure archive", "tool": "valt", "version": "0.3.0", "valtVersion": "0.3.0", "archiveVersion": "1.0" }

An archive made by another program, e.g. a wardn vault backup, can give its own, saying what it is and how to restore
it (valt adds the versions): restoring a vault backup means importing it with wardn, not extracting the vault's
unencrypted export. For example:

    {
      "kind": "wardn vault backup",
      "tool": "wardn",
      "version": "0.2.0",
      "extract": "discouraged",
      "restore": {
        "args": ["restore", "{archive}", "-i", "{identity}"],
        "nix": "github:phoggy/wardn/v0.2.0#restore",
        "brew": "rayvn-central/brew/wardn"
      }
    }

Before extracting, `valt decrypt` says what the archive is and offers to restore it with the program, in whichever
ways this computer can: the program if it is installed, Nix (running the pinned release without installing it), or
Homebrew (installing it first). It extracts the files only if asked to (`--extract`), and warns when the manifest
discourages it. Nothing in the archive is run: the manifest only names a published program. Like the rest of the
archive, it is only accepted when signed by the key that decrypts it. The archive's README gives the same commands.
