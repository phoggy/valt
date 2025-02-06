![image]({_LOGO_PATH})

# About

This document contains a &ldquo;private key&rdquo; that can unlock files encrypted with the associated
public key. This document is intended as a backup and **must** be kept in a safe place.  It contains instructions for using the (private) key to
unlock a file &mdash; these instructions
are a bit technical, so it includes some ways to get help if needed.
                                    
Know that the key *itself* is locked, so it cannot be used without the passphrase used to create it. That
passphrase might be written down below, or it might be stored somewhere else that you are expected to know.

If you *don't have or can't get the passphrase*, stop here. Yes, really.

If this all seems over the top, sorry... welcome to the modern world of digital security.

<br>

Alright then, moving on&hellip;  

If you just generated this document, see [Next Steps](#next-steps).

If you know your way around a terminal and need to decrypt an `.age` file, see [Instructions](#instructions).

If all of this has you thinking *uh&hellip; what?*, see [Getting Help](#getting-help).

<br><br><br><br>

*{CLOSING}*

<h5>{AUTHOR}</h5>

*{_DATE}*     

<p class="break-before">

# Next Steps

</p>
TODO 
                                                           
passphrase can be stored in password manager
pdf file can be stored in password manager (e.g. bitwarden)

1. Write the passphrase [below](#the-passphrase) for you or your successor, but ONLY if it will be kept in a very secure 
place like a safe-deposit box.
2. Put this in the safe place *now*: don't leave it laying around! 
                              
# Getting Help

The following are people that I trust and who have agreed to help if needed:

{CONTACTS}

If none of them are available, hopefully one of them can suggest someone else; if not, you'll have to find 
someone else&hellip; 

- Try looking online for TODO 

<p class="break-before">

# Instructions

</p>

## The Key

This page contains the *encrypted* `age` public key pair, in two forms: as a QR code and as raw `pem` text. 
The text form is provided just for the unlikely case that the QR code does not work as it can be copied 
from the PDF or, worst case, typed in. 

To use the QR code, just open the camera app on your phone and point it at the image. You should see 
the same text as below (maybe just the beginning). Just copy it, send it to the computer on which you 
want to use the key and save it as a file with whatever name you like.


{_QR_CODE}

```
{_ARMORED_KEY}
```

<p class="break-before">

## The Prerequisites

</p>

The key is encrypted, so to use it you must know the passphrase. It may be written down 
[here](#the-passphrase). 

You also need a command line tool that performs [age fle encryption](
https://github.com/C2SP/C2SP/blob/main/age.md):

- [rage](https://github.com/str4d/rage)
- [age](https://github.com/FiloSottile/age)

The code used to create this document is a wrapper around `rage` and can also encrypt/decrypt files. The 
source code and instructions for it can be found [here](todo).

There are other implementations to choose from [here](https://github.com/FiloSottile/age).

## Decrypting A File

TODO

## The Passphrase

---

---

---


