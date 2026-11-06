---
layout: default
title: "valt/pwned"
parent: "Passwords"
grand_parent: API Reference
nav_order: 11
---

# valt/pwned

HaveIBeenPwned breach checking.

## Functions

### hasNotBeenPwned()

Check whether a password appears in the HaveIBeenPwned breach database via k-anonymity API.


*args*

| | |
|---|---|
| `passRef` *(stringRef)* | Name of var containing the password to check. |
| `apiErrorRef` *(intRef)* | Name of var to receive the curl exit code (default: 0). |
| `breachCountRef` *(intRef)* | Name of var to receive the breach count (default: 0). |
{: .args-table}

*returns*

| | |
|---|---|
| `0` | Password not found in breach database. |
| `1` | API request failed; apiErrorRef contains the curl exit code. |
| `2` | Password found; breachCountRef contains the number of times it appeared. |
{: .args-table}

