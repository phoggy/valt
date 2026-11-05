---
layout: default
title: "valt/paper-keys"
parent: "Paper Keys"
grand_parent: API Reference
nav_order: 6
---

# valt/paper-keys

Paper key PDF generation from your key info, and reminders to keep it current.

## Functions

### preparePaperKey()

Loads key info from a file to prepare a paper key PDF, sourcing key metadata
needed for QR and PEM generation.


*args*

| | |
|---|---|
| `[keyInfoFile]` *(string)* | Path to the key info file (default: ${valtConfigDir}/key-info.json) |
{: .args-table}

### isKeyInfoComplete()

Returns 0 if the key info file has been marked completed, 1 otherwise. If the file does not
exist, it is created from the template so that it can be edited.


*args*

| | |
|---|---|
| `[keyInfoFile]` *(string)* | Path to the key info file (default: ${valtConfigDir}/key-info.json) |
{: .args-table}

### remindPaperKey()

Warns if a valt private key has no paper key, or if its paper key is older than the key or
the key info file. Does nothing for files that are not valt private keys.


*args*

| | |
|---|---|
| `keyFile` *(string)* | Path to a private key file. |
| `[keyInfoFile]` *(string)* | Path to the key info file (default: ${valtConfigDir}/key-info.json) |
{: .args-table}

### paperKeyCommand()

Outputs the paper command for a private key file, omitting the path if it is the default key.


*args*

| | |
|---|---|
| `keyFile` *(string)* | Path to a private key file. |
{: .args-table}

### newPaperKey()

Generates a paper key PDF from a private key file, storing the output path in a result variable.


*args*

| | |
|---|---|
| `privateKeyFile` *(string)* | Path to the private key file. |
| `resultVarRef` *(string)* | Name of the variable to receive the output paper key file path. |
| `[keyInfoFile]` *(string)* | Path to the key info file (default: ${valtConfigDir}/key-info.json). |
| `[cssOverride]` *(string)* | Path to an optional CSS override file. |
| `[htmlTemplate]` *(string)* | Path to an HTML template file (default: ${valtHome}/etc/key-doc-template.html). |
{: .args-table}

