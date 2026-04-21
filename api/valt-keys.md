---
layout: default
title: "valt/keys"
parent: API Reference
nav_order: 2
---

# valt/keys

## Functions

### createValtKeys

**Library:** `valt/keys`

Encryption (Age) and signing (minisign) key generation and usage.
Use via: require 'valt/keys'
Create new valt keys, encrypting the private key with a passphrase. May show passphrase advice and offer to generate passphrase.
Produces keys that combine minisign keys (as comments) and Age keys:
  [name-]valt.pub: minisign public key comment + Age public key
  [name-]valt.key: minisign public key comment + Age public key comment + encrypted minisign secret key comment + Age secret key
Args: [keyName] [keyDir] [valtPubFileResultVar] [valtKeyFileResultVar] [testPassResultVar]
Passing '?' for any arg will ensure the default behavior.
  keyName               optional name prefix for keys
  keyDir                optional directory path where key files will be written, default: ~/.config/valt
  valtPubFileResultVar  optional var name to assign the valt.pub file
  valtKeyFileResultVar  optional var name to assign the valt.key file
  testPassResultVar     optional var name to assign the password for testing

```bash
createValtKeys()
```

### verifyValtKeys

**Library:** `valt/keys`

Verify keys by encrypting sample text, signing, verify signature and decrypting, then comparing.
Fails if decryption does not reproduce the original (e.g. wrong passphrase).
Args: keyFile valtPubFile valtKeyFile
  valtPubFile  path to the valt.pub file
  valtKeyFile  path to the valt.key file

```bash
verifyValtKeys()
```

### keyType

**Library:** `valt/keys`

accepts either valt.pub or valt.key, echos 'valt.pub', 'valt.key'

```bash
keyType()
```

### publicEncryptionKey

**Library:** `valt/keys`

accepts either valt.pub or valt.key

```bash
publicEncryptionKey()
```

### publicSigningKeyToTempFile

**Library:** `valt/keys`

accepts either valt.pub or valt.key

```bash
publicSigningKeyToTempFile()
```

### signingKeyToTempFile

**Library:** `valt/keys`

accepts valt.key only

```bash
signingKeyToTempFile()
```

### offerPassphraseAdvice

**Library:** `valt/keys`

```bash
offerPassphraseAdvice()
```

