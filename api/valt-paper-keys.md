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

Checks that the key info file is complete, so that a paper key PDF can be made from it, exiting with what it still
needs if not (see keyInfoProblems).


*args*

| | |
|---|---|
| `[keyInfoFile]` *(string)* | Path to the key info file (default: ${valtConfigDir}/key-info.json) |
{: .args-table}

### remindPaperKey()

Warns if a valt private key has no paper key, or if its paper key is older than the key or
the key info file. Otherwise, when at a terminal, asks whether the paper key has been printed
and its copies stored securely, and whether the private key file has been backed up, offering
to be reminded in a number of days or to stop asking.
The answers are kept per paper key, so a regenerated paper key is asked about again. Does
nothing for files that are not valt private keys.


*args*

| | |
|---|---|
| `keyFile` *(string)* | Path to a private key file. |
| `[keyInfoFile]` *(string)* | Path to the key info file (default: ${valtConfigDir}/key-info.json) |
{: .args-table}

*env vars*

| | |
|---|---|
| `rayvnTest_PaperKeyAnswers` | Test hook: answers to use instead of prompting, in order, separated by spaces: 'yes', 'stop', 'remind:DAYS' or 'timeout'. |
{: .args-table}

### paperKeyCommand()

Outputs the paper command for a private key file, omitting the path if it is the default key.


*args*

| | |
|---|---|
| `keyFile` *(file)* | Path to a private key file. |
{: .args-table}

### newPaperKey()

Generates a paper key PDF from a private key file, storing the output path in a result variable.


*args*

| | |
|---|---|
| `privateKeyFile` *(string)* | Path to the private key file. |
| `resultVarRef` *(string)* | Name of the variable to receive the output paper key file path. |
| `[keyInfoFile]` *(string)* | Path to the key info file (default: ${valtConfigDir}/key-info.json). |
| `[styleFile]` *(string)* | Path to an optional typst style override file (see etc/key-doc-style.typ). |
| `[templateFile]` *(string)* | Path to a typst template file (default: ${valtHome}/etc/key-doc-template.typ). |
{: .args-table}

### showPaperKeyNextSteps()

Shows the steps to take after a paper key is generated, as a numbered list, and that valt will ask about them
later (see remindPaperKey).


*args*

| | |
|---|---|
| `keyFile` *(string)* | Path to the private key file the paper key was made from, for the step to back it up. |
| `[replacing]` *(bool)* | 1 if the paper key replaced an earlier one, adding a step to destroy its printed copies (default: 0). |
{: .args-table}

### showKeyBackupAdvice()

Shows why and how to back up a private key file: copies are safe to keep, since it is encrypted with its
passphrase, and without one, losing the computer leaves only the paper key (if any) to recover files with.


*args*

| | |
|---|---|
| `keyFile` *(string)* | Path to the private key file. |
{: .args-table}

