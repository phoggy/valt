---
layout: default
title: "valt/pinentry"
parent: API Reference
nav_order: 1
---

# valt/pinentry

## Functions

### useValtPinEntry

**Library:** `valt/pinentry`

Library supporting password/phrase generation
Intended for use via: require 'valt/pinentry'
Set PINENTRY_PROGRAM to valt's custom pinentry binary, enabling passphrase capture.

```bash
useValtPinEntry() {
```

### disableValtPinEntry

**Library:** `valt/pinentry`

Unset PINENTRY_PROGRAM, restoring the default pinentry behavior.

```bash
disableValtPinEntry() {
```

