---
layout: default
title: "valt/pwned"
parent: "Passwords"
grand_parent: API Reference
nav_order: 10
---

# valt/pwned

HaveIBeenPwned breach checking.

## Functions

### hasNotBeenPwned()

Check whether a password appears in the HaveIBeenPwned breach database (via k-anonymity API).


*args*

| | |
|---|---|
| `passwordVar` *(stringRef)* | Name of variable containing the password. |
| `apiErrorVar` *(stringRef)* | Name of variable to return any api error. |
| `breachCountVar` *(stringRef)* | Name of variable to return the breach count. |
| `Returns` | 0 if not found, 1 if the API returned an error, 2 if the password has been breached. |
{: .args-table}

