---
layout: default
title: "valt/keys"
parent: "Encryption"
grand_parent: API Reference
nav_order: 1
---

# valt/keys

Key pair generation, verification and recipients.

## Functions

### newValtKeys()

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

DESIGN NOTES

Valt uses age file encryption system and minisign digital signatures (see https://github.com/filosottile/age and
https://github.com/jedisct1/minisign).

Quantum resistant encryption keys are used exclusively as defense against the real possibility of quantum computers that can
break keys based on 256-bit elliptic curves, the current best practice. A consequence of this choice is significantly larger
public keys, from 63 bytes to 1960 bytes.

A valt key is passphrase encrypted and contains both minisign keys and age public key as comments, along with the age private
key. A valt public key is plaintext and is an Age public key with minisign public key as comment(s).

valt.key: secure private key used by valt for signing and decryption
valt.pub: public key used by valt for signature verification and encryption

All keys can be extracted from valt.key, and signature verification and encryption functions will accept the private key.

Example valt.pub

# created: 2026-04-08T15:20:15-07:00
#
# [minisign.pub] untrusted comment: minisign public key EE5CD48146AE435D
# [minisign.pub] RWRdQ65GgdRc7jF1xg1QozGtd1gWfi7I4RJ58i8ElDvV4qCuzE+zENKo
#
age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]

Example valt.key prior to encryption (not stored)

# created: 2026-03-10T16:57:47-07:00
#
# [minisign.pub] untrusted comment: minisign public key 86DA637D4FBBE4E5
# [minisign.pub] RWTl5LtPfWPahiYfMcUk9+c/cFAfruNplL79ijRei9i1HzJlDa741qHp
#
# [minisign.key] untrusted comment: minisign encrypted secret key
# [minisign.key] RWQAAEIyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA5eS7T31j2oY  [ ... ]
# public key: age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]
AGE-SECRET-KEY-1KVCTA4K9RSW85YHCSE62L9XJ2ULTPG9ZVRF7K6KGGALCGYUDFHGQY2SYX7#

Example valt.key

# age-encryption.org/v1
# -> scrypt WzB5/xdYAB/DggwzorWYPg 18
# tdtd2Ew1tyQU2b34sGgI6o2YajyADGt/0D+eW2GN3bk
# --- VX6tiDvvH5VCkb44Ifnca1R9eUQuk9RauYKrZ9U2Cto
# [... 1565 bytes binary data ...]

Passphrase Encryption

Users are shown password/phrase advice on key gen to encourage strong, memorable passphrase use, then asked if they already
have one. If not, a set of generated ones is shown to choose from. This behavior is suppressed after second key gen.

Valt Key Usage

- Encrypt/sign requires valt.key for PRIVATE signing key and PUBLIC Age key
- Decryption requires valt.key for PRIVATE Age key
- Verify requires valt.pub, for PUBLIC signing key
- Full verify requires valt.key for PUBLIC signing key(s) and PRIVATE Age key
- Extract requires valt.key.

Key Storage

valt.key: local, password manager (bitwarden, etc.)
valt.pub: local, password manager (bitwarden, etc.), user's github, google drive, iCloud, etc.

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
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

allowWeakKeyPassphrase   When set and non-zero, accepts a passphrase that fails the strength and breach check (default:
                         the passphrase is rejected, since it is all that protects the private key).
skipKeyPassphraseAdvice  When set and non-zero, skips the passphrase advice.

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

Outputs an ASCII-armored PEM-style encoding of a key file to stdout.


*usage*

`armorKeyFile keyFile`
{: .usage-signature}

| | |
|---|---|
| `keyFile` *(string)* | Path to the key file to armor. |
{: .usage-table}

