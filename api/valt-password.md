---
layout: default
title: "valt/password"
parent: "Passwords"
grand_parent: API Reference
nav_order: 8
---

# valt/password

Password and passphrase generation, secure input and strength estimates.

## Functions

### generatePassword()

Generates a random password of random length within a given range.


*args*

| | |
|---|---|
| `resultVarName` *(string)* | Name of the variable to receive the password. |
| `[minLength]` *(int)* | Minimum password length (default: 24). |
| `[maxLength]` *(int)* | Maximum password length (default: 32). |
{: .args-table}

### generatePassphrase()

Generates a random passphrase using the Orchard Street Long word list (17,576 words) via phraze.


*args*

| | |
|---|---|
| `resultVarName` *(string)* | Name of the variable to receive the passphrase. |
| `[wordCount]` *(int)* | Number of words in the passphrase (default: 5). |
| `[separator]` *(string)* | String placed between words (default: ' '). |
{: .args-table}

### readConfirmedPassword()

Interactively prompts for a password twice and stores the confirmed result in resultVarRef.
Fails if the first entry is empty or the two entries do not match. Returns 1 if the strength test (when requested)
finds the first entry unsafe, after showing why.


*args*

| | |
|---|---|
| `prompt` *(string)* | Label displayed before the first entry; 'Confirm' is shown, aligned, before the second. |
| `resultVarRef` *(stringRef)* | Name of the variable to receive the confirmed password. |
| `[testUseCase]` *('account'\|'file')* | Test the first entry's strength and breach status if provided (default: ''). |
| `[testThreatLevel]` *('casual'\|'motivated'\|'professional'\|'nation-state')* | How much guessing power to judge strength against (default: 'professional'). |
| `[timeout]` *(int)* | Seconds to wait for each entry (default: 30). |
{: .args-table}

### readPassword()

Interactively prompts for a password, storing the result in resultVarRef.


*args*

| | |
|---|---|
| `prompt` *(string)* | Label displayed before the input field. |
| `resultVarRef` *(string)* | Name of the variable to receive the entered password. |
| `[strengthUseCase]` *(string)* | If provided, estimates password strength and breach status; either 'account' (online/offline attacks against a service whose password hashing you don't control) or 'file' (offline attacks against an Age-encrypted file or private key, at Age's default scrypt work factor). |
| `[threatLevel]` *(string)* | Guessing power to judge the strength verdict against: 'casual', 'motivated', 'professional', or 'nation-state' (default: 'professional'). |
| `[timeout]` *(int)* | Seconds to wait for input (default: 30). |
{: .args-table}

*env vars*

| | |
|---|---|
| `passwordVisibility` | Controls input display: 'none' hides input, 'hide' masks it, 'show' reveals it (default: 'none'). [R/W] |
| `skipReadPasswordStrength` | When set and non-zero, disables strength checking. |
{: .args-table}

*returns*

| | |
|---|---|
| `0` | password accepted (with a warning shown if known breaches could not be checked) |
| `1` | password is unsafe: too weak, or found in a known breach |
{: .args-table}

### passwordStrength()

Evaluates password strength and breach status, populating a formatted report array: element 0 is a summary, and
later elements give more detail.


*args*

| | |
|---|---|
| `passVar` *(stringRef)* | Name of the variable holding the password to check. |
| `useCase` *(string)* | 'account' (online/offline attacks against a service whose password hashing you don't control) or 'file' (offline attacks against an Age-encrypted file or private key, at Age's default scrypt work factor). |
| `threatLevel` *(string)* | Guessing power to judge the strength verdict against: 'casual', 'motivated', 'professional', or 'nation-state' (default: 'professional'). |
| `scoreRef` *(intRef)* | Name of the variable to receive the 0-4 strength score. |
| `resultArrayRef` *(arrayRef)* | Name of the array variable to populate with the formatted strength report. |
{: .args-table}

*returns*

| | |
|---|---|
| `0` | Password appears safe to use. |
| `1` | Password is unsafe: present in a known breach, or strength score is below 3. |
| `2` | Password is strong enough but breach status could not be checked (e.g. offline). |
{: .args-table}

