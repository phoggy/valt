---
layout: default
title: "valt/password"
parent: "Passwords"
grand_parent: API Reference
nav_order: 10
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

Interactively prompts for a password twice and stores the verified result in resultVarRef.
Fails if the entries do not match or the first entry is empty. Returns 1 if the strength test (when requested)
finds the first entry unsafe, after showing why.


*args*

| | |
|---|---|
| `prompt` *(string)* | Prompt label displayed before each entry. |
| `resultVarRef` *(stringRef)* | Name of the variable to receive the verified password. |
| `[testUseCase]` *('account'\|'file')* | Test password strength and breach status if provided (default: ''). |
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
| `[strengthUseCase]` *(string)* | Estimate password strength and breach status if provided, either 'account' (online/offline attacks against a service whose password hashing you don't control) or 'file' (offline attacks against an Age-encrypted file or private key, at Age's default scrypt work factor). |
| `[threatLevel]` *(string)* | How much guessing power to judge the strength verdict against: 'casual', 'motivated', 'professional', or 'nation-state' (default: 'professional'). |
| `[timeout]` *(int)* | Seconds to wait for input (default: 30). |
{: .args-table}

*env vars*

passwordVisibility          Controls input display: 'none' hides input, 'hide' masks it, 'show' reveals it (default: 'none').
skipReadPasswordStrength    When set and non-zero, disables strength checking.

*returns*

| | |
|---|---|
| `0` | password accepted (with a warning shown if known breaches could not be checked) |
| `1` | password is unsafe |
{: .args-table}

### passwordStrength()

Returns a formatted password strength estimate as an array of description strings. Element 0 is a summary, subsequent elements
provide additional detail.


*args*

| | |
|---|---|
| `passVar` *(string)* | Name of the variable holding the password to check. |
| `useCase` *(string)* | Either 'account' (online/offline attacks against a service whose password hashing you don't control) or 'file' (offline attacks against an Age-encrypted file or private key, at Age's default scrypt work factor). |
| `threatLevel` *(string)* | How much guessing power to judge the strength verdict against: 'casual', 'motivated', 'professional', or 'nation-state' (default: 'professional'). |
| `strengthRef` *(intRef)* | Name of the variable to return the 0-4 strength value. |
| `resultArrayRef` *(arrayRef)* | Name of an array variable to populate with the formatted strength report. |
{: .args-table}

*returns*

| | |
|---|---|
| `0` | password appears safe to use. |
| `1` | password is unsafe to use: it appears in a known breach, or strength < 3. |
| `2` | password is strong enough, but whether it appears in a known breach could not be checked (e.g. offline). |
{: .args-table}

