---
layout: default
title: "valt/pwned"
parent: API Reference
nav_order: 3
---

# valt/pwned

## Functions

### hasNotBeenPwned

**Library:** `valt/pwned`

shellcheck disable=SC2155
Library supporting password/phrase breach testing
Intended for use via: require 'valt/pwned'
Check whether a password appears in the HaveIBeenPwned breach database via k-anonymity API.
Returns 0 if not found, 1 if the API could not be reached, 2 if the password has been breached.
Args: pass
  pass - plain-text password to check

```bash
hasNotBeenPwned() {
```

