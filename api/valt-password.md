---
layout: default
title: "valt/password"
parent: API Reference
nav_order: 3
---

# valt/password

## Functions

### generatePassword

**Library:** `valt/password`

Password/phrase generation.
Use via: require 'valt/passwords'
TODO: don't display strength (via mrld) as it is inaccurate. Just pick a threshold and warn is week if below.
Generate a random password of random length within the given range.
Prints the generated password.
Args: [minLength] [maxLength]
  minLength - minimum password length (default: 24)
  maxLength - maximum password length (default: 32)

```bash
generatePassword()
```

### generatePassphrase

**Library:** `valt/password`

Generate a random passphrase using the Orchard Street Long word list via phraze.
Prints the generated passphrase.
Args: [wordCount] [separator]
  wordCount - number of words in the passphrase (default: 5)
  separator - string placed between words (default: space)

```bash
generatePassphrase()
```

### readVerifiedPassword

**Library:** `valt/password`

Interactively prompt for a password twice and verify both entries match.
Stores the verified password in a nameref variable. Fails if entries do not match.
Args: resultVar [checkResult] [retryCount] [timeout]
  resultVar   - nameref variable to receive the verified password
  checkResult - if 'true', check strength and breach status (default: 'true')
  retryCount  - number of times to retry the verification step (default: 3)
  timeout     - seconds to wait for each entry before timing out (default: 30)

```bash
readVerifiedPassword()
```

### readPassword

**Library:** `valt/password`

Interactively prompt for a password with optional strength checking and breach detection.
Stores the entered password in a nameref variable. Visibility controlled by passwordVisibility.
Args: prompt resultVar [timeout] [checkResult]
  prompt      - label displayed before the input field
  resultVar   - nameref variable to receive the entered password
  timeout     - seconds to wait for input before timing out (default: 30)
  checkResult - if 'true', check strength and breach status (default: 'true')

```bash
readPassword()
```

