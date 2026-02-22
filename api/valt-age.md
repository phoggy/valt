---
layout: default
title: "valt/age"
parent: API Reference
nav_order: 4
---

# valt/age

## Functions

### showAgeKeyPairAdvice

**Library:** `valt/age`

Library supporting age file encryption via rage
Intended for use via: require 'valt/age'
Print guidance about creating an age key pair, including passphrase strength advice.

```bash
showAgeKeyPairAdvice() {
```

### createAgeKeyPair

**Library:** `valt/age`

Generate a new rage key pair, encrypting the private key with a passphrase via rage -p.
Args: keyFile publicKeyFile [captureVarName]
  keyFile        - path where the passphrase-encrypted private key file will be written
  publicKeyFile  - path where the plain-text public key will be written
  captureVarName - optional variable name to receive the passphrase entered during encryption

```bash
createAgeKeyPair() {
```

### verifyAgeKeyPair

**Library:** `valt/age`

Verify an age key pair by encrypting sample text and decrypting it, then comparing.
Fails if decryption does not reproduce the original (e.g. wrong passphrase).
Args: keyFile publicKeyFile
  keyFile       - path to the passphrase-encrypted private key file
  publicKeyFile - path to the plain-text public key file

```bash
verifyAgeKeyPair() {
```

### armorAgeFile

**Library:** `valt/age`

Convert a binary age-encrypted file to PEM-style ASCII-armored text and store in a nameref variable.
Fails if the file does not appear to be a valid age-encrypted file.
Args: ageFile resultVar
  ageFile   - path to the binary age-encrypted file
  resultVar - nameref variable to receive the armored text

```bash
armorAgeFile() {
```

### setSampleText

**Library:** `valt/age`

Populate a nameref variable with a multi-line sample text if not already set.
Args: resultVar
  resultVar - nameref variable to populate (only written if currently empty)

```bash
setSampleText() {
```

