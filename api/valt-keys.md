---
layout: default
title: "valt/keys"
parent: "Encryption"
grand_parent: API Reference
nav_order: 1
---

# valt/keys

Key pair generation, verification and recipients.

See the [Design Notes](#design-notes) below for details.

## Functions

### newValtKeys()

Create new valt keys, encrypting the private key with a passphrase. May show passphrase advice and offer to generate
passphrases. Produces keys that combine age and minisign keys:

valt.pub: age public key + minisign public key
valt.key: age public key + minisign public key + age secret key + minisign secret key


*usage*

`newValtKeys [keyName] [keyDir] [valtPubFileResultVar] [valtKeyFileResultVar]`
{: .usage-signature}

| | |
|---|---|
| `A` | '-' may be passed for any arg to enable passing a subsequent value. |
| `keyName` *(string)* | Optional name to use instead of 'valt', e.g. 'test' -> test.key & test.pub. |
| `keyDir` *(string)* | Optional directory path where key files will be written (default: ~/.config/valt). |
| `valtPubFileResultVar` *(stringRef)* | Optional var name to assign the valt.pub file. |
| `valtKeyFileResultVar` *(stringRef)* | Optional var name to assign the valt.key file. |
{: .usage-table}

*example*

```bash
newValtKeys                      # creates valt.pub and valt.key files in the ~/.config/valt/ directory.
newValtKeys - - pubFile keyFile  # same as above but assigns key paths to pubFile keyFile vars.
newValtKeys frodo                # creates frodo.pub and frodo.key in the ~/.config/valt/ directory.
```

*env vars*

| | |
|---|---|
| `allowWeakKeyPassphrase` | When set and non-zero, accepts a passphrase that fails the strength and breach check (default: the passphrase is rejected, since it is all that protects the private key). |
| `skipKeyPassphraseAdvice` | When set and non-zero, skips the passphrase advice. |
{: .args-table}

### verifyValtKeys()

Verifies a valt key pair by encrypting sample text with the public key, then decrypting
with the private key and comparing results. Fails if they do not match. Also signs encrypted
file and verifies the signature.


*usage*

`verifyValtKeys valtPubFile valtKeyFile`
{: .usage-signature}

| | |
|---|---|
| `valtPubFile` *(string)* | Path to the valt.pub file. |
| `valtKeyFile` *(string)* | Path to the valt.key file. |
{: .usage-table}

### keyType()

Outputs the key type suffix for a valt key file, either "pub" or "key".


*usage*

`keyType keyFile`
{: .usage-signature}

| | |
|---|---|
| `keyFile` *(string)* | Path to a valt .pub or .key file. |
{: .usage-table}

### recipient()

Extracts the public encryption key from a valt key file and writes it to standard output.
Will accept a private key that will require passphrase input to decrypt.


*usage*

`recipient keyFile`
{: .usage-signature}

| | |
|---|---|
| `keyFile` *(string)* | Path to the key file. |
{: .usage-table}

### writeValtPublicKey()

Writes the public key file (.pub) for a valt private key, recreating it from the private key, which contains
everything in it: the created line, the public signing key and the public encryption key. The result is identical
to the .pub file made with the key. Requires the private key's passphrase.


*usage*

`writeValtPublicKey keyFile pubFile`
{: .usage-signature}

| | |
|---|---|
| `keyFile` *(file)* | Path to the valt private key file. |
| `pubFile` *(string)* | Path to the public key file to write; it is replaced if it exists. |
{: .usage-table}

### newRecipientsFile()

Convert one or more valt key files into a recipients file. Will accept private keys; each will require passphrase input to
decrypt.


*usage*

`newRecipientsFile recipientsFile keyFile...`
{: .usage-signature}

| | |
|---|---|
| `recipientsFile` *(string)* | Path to the recipients file to create. |
| `keyFile` | (string)...   One or more valt .pub or .key file paths. |
{: .usage-table}

### publicSigningKeyToTempFile()

Extracts the public signing key from a valt private key file into a temp file.


*usage*

`publicSigningKeyToTempFile valtKeyFile resultFileRef`
{: .usage-signature}

| | |
|---|---|
| `valtKeyFile` *(string)* | Path to the valt private key file. |
| `resultFileRef` *(stringRef)* | Name of the variable to receive the path to the temp public signing key file. |
{: .usage-table}

### signingKeyToTempFile()

Extracts the signing key from a valt private key file into a temp file.


*usage*

`signingKeyToTempFile valtKeyFile resultFileRef`
{: .usage-signature}

| | |
|---|---|
| `valtKeyFile` *(string)* | Path to the valt private key file. |
| `resultFileRef` *(stringRef)* | Name of the variable to receive the path to the temp private signing key file. |
{: .usage-table}

### armorKeyFile()

Outputs an ASCII-armored PEM-style encoding of a key file to stdout, in age's armor format: base64 in lines of
exactly 64 characters (but the last), which age requires.


*usage*

`armorKeyFile keyFile`
{: .usage-signature}

| | |
|---|---|
| `keyFile` *(string)* | Path to the key file to armor. |
{: .usage-table}

### assertCompatibleRecipients()

Fail if the recipients mix post-quantum (age1pq1...) and classic age keys, which age refuses to encrypt to (the
file would be open to quantum computers). Recipient files are read for their recipients; others are ignored.


*usage*

`assertCompatibleRecipients (-r RECIPIENT | -R PATH)...`
{: .usage-signature}

| | |
|---|---|
| `-r RECIPIENT` | A recipient (age public key). |
| `-R PATH` | A file of recipients, e.g. a valt .pub file. |
{: .usage-table}

### valtReleaseTag()

Outputs the tag of the valt release current when this valt was built (e.g. v0.1.1), for recovery commands pinned to
it (nix run github:phoggy/valt/TAG#recover ...): this version, if it is a release, or for a development version
(e.g. 0.1.1+, as rayvn's release process marks the versions after a release) the release before it, since its own
commit may not be published. Outputs nothing if the version is neither.


*args*

| | |
|---|---|
| `[pkgFile]` *(file)* | The rayvn.pkg to read the version from (default: valt's own). |
{: .args-table}

### defaultValtKeyFile()

Output the path of the default valt private key file, used when no key is specified: VALT_KEY_FILE if set, else the
defaultKeyFile setting in valt.conf in the valt config directory (see setDefaultValtKeyFile), else valt.key in the
valt config directory.

### defaultValtKeyFileSource()

Output where the default valt private key file comes from: 'VALT_KEY_FILE', the path of the valt.conf file that
sets it, or 'built-in'.

### setDefaultValtKeyFile()

Set the default valt private key file in valt.conf in the valt config directory, or remove the setting.


*args*

| | |
|---|---|
| `[keyFile]` *(file)* | The valt private key file to use by default; omit to remove the setting. |
{: .args-table}


## Design Notes

valt uses the [age](https://github.com/FiloSottile/age) file encryption system and
[minisign](https://github.com/jedisct1/minisign) digital signatures.

### Post-Quantum Encryption

valt keys are always post-quantum age keys (made with `age-keygen -pq`, their public keys starting with `age1pq1`):
a hybrid of ML-KEM-768 and X25519, so that files are protected against future quantum computers, which could break
keys based on elliptic curves alone, the current best practice. This matters for encryption today, since encrypted
files can be recorded now and attacked later. The cost is much larger public keys: about 2,000 characters, where
classic ones have 62. age will not encrypt to both post-quantum and classic keys at once, since the result would be
only as strong as the classic key, so neither does valt.

Signatures use minisign's Ed25519 keys, which are not post-quantum: a signature only needs to resist forgery when it
is checked.

### Key Files

A valt private key (`valt.key`) is encrypted with a passphrase, and holds the age private key, with both minisign
keys and the age public key as comments. A valt public key (`valt.pub`) is plain text: the age public key, with the
minisign public key as comments. Since the private key holds every key, signature verification and encryption also
accept it.

An example `valt.pub`:

    # created: 2026-04-08T15:20:15-07:00
    #
    # [minisign.pub] untrusted comment: minisign public key EE5CD48146AE435D
    # [minisign.pub] RWRdQ65GgdRc7jF1xg1QozGtd1gWfi7I4RJ58i8ElDvV4qCuzE+zENKo
    #
    age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]

A `valt.key` before it is encrypted (never stored like this):

    # created: 2026-03-10T16:57:47-07:00
    #
    # [minisign.pub] untrusted comment: minisign public key 86DA637D4FBBE4E5
    # [minisign.pub] RWTl5LtPfWPahiYfMcUk9+c/cFAfruNplL79ijRei9i1HzJlDa741qHp
    #
    # [minisign.key] untrusted comment: minisign encrypted secret key
    # [minisign.key] RWQAAEIyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA5eS7T31j2oY  [ ... ]
    # public key: age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]
    AGE-SECRET-KEY-PQ-1KVCTA4K9RSW85YHCSE62L9XJ2ULTPG9ZVRF7K6KGGALCGYUDFHGQY2SYX7

And as stored, encrypted with the passphrase:

    age-encryption.org/v1
    -> scrypt WzB5/xdYAB/DggwzorWYPg 18
    tdtd2Ew1tyQU2b34sGgI6o2YajyADGt/0D+eW2GN3bk
    --- VX6tiDvvH5VCkb44Ifnca1R9eUQuk9RauYKrZ9U2Cto
    [... 1565 bytes binary data ...]

### Which Key Each Operation Needs

- Encrypting and signing: `valt.key`, for the private signing key and the public age key.
- Decrypting: `valt.key`, for the private age key.
- Verifying a signature: `valt.pub`, for the public signing key.
- Full verification (decrypting too): `valt.key`, for the public signing keys and the private age key.
- Extracting an archive: `valt.key`.

### Storing Keys

Keep backup copies of `valt.key`: being encrypted, it is safe in a password manager, on a USB drive or in cloud
storage, and the paper key is a printed copy. `valt.pub` can be shared anywhere, e.g. on GitHub.

### Passphrases

When making a key, valt shows advice on strong, memorable passphrases, then asks whether the user already has one;
if not, it offers generated ones to choose from. After the second key, the advice is no longer shown.
