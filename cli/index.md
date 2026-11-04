---
layout: default
title: CLI Reference
nav_order: 2
---

# valt CLI

valt is a single command with subcommands for creating keys and paper keys, encrypting and decrypting files, and
working with secure archives.

## Usage

```
Public key encryption for files and archives, using age (see https://github.com/filosottile/age).

Usage: valt COMMAND [OPTIONS]

Commands

    keys         Create a key pair with an encrypted private key and a paper key as backup.
    paper        Create or regenerate the paper key for an existing key pair.
    encrypt      Encrypt and sign a single file.
    decrypt      Decrypt a file, or verify and extract a secure archive.
    archive      Create, verify or extract a signed, encrypted archive of files and directories.
    verify       Verify a key pair, and optionally files encrypted or archived with it.
    default-key  Show or set the default private key file, used when no key is given.
    passphrase   Generate random passphrases.
    password     Generate random passwords.
    pass-check   Check a password or passphrase: its strength, and whether it is in a known breach.

Use COMMAND --help for additional details.

Options

    -v               Print the version.
    --version        Print the version and release date.
    -h, --help       Print this help message.

Debug Options

    --debug          Enable debug, write output to log file and show on exit.
    --debug-new      Enable debug, clear log file, write output to log file and show on exit.
    --debug-out      Enable debug, write output to the current terminal.
    --debug-tty TTY  Enable debug, write output to the specified TTY (e.g., /dev/ttys001).
    --debug-tty .    Enable debug, write output to the TTY path read from the '~/.debug.tty' file

Environment Variables

    RAYVN_PROMPT_TIMEOUT  Default prompt timeout seconds (default: 30).
    VALT_KEY_FILE         The default private key file; overrides the 'valt default-key' setting.
```

## Shell Completions

Bash and zsh completions for all commands, subcommands and options are included. Homebrew and Nix installs activate
them automatically once completion is configured in your shell.

## Keys

### valt keys

```
Generate an age key pair, with the private key encrypted by a passphrase, plus a PDF paper key as
backup documentation. A strong passphrase is highly encouraged; advice and an opportunity to
generate one will be offered.

Usage: valt keys [-d | --no-default] [--allow-weak-passphrase] [-f] [-k KEY-INFO] [-n NAME]
                 [--no-advice] [--no-pdf] [--no-verify] [-o OUTPUT-DIR] [-q] [-c STYLE]
                 [-t TEMPLATE]

    -n, --name NAME              Name to use for key files, e.g. bob -> bob.pub, bob.key. (default:
                                 valt)
    -o, --output-dir OUTPUT-DIR  Directory for the key files (default: the valt config directory).
    -f, --force                  Replace existing key files, once the new ones have been created.
    --allow-weak-passphrase      Accept a passphrase that fails the strength and breach check. Not
                                 recommended: the passphrase is all that protects the private key.
    -d, --default                Make the new key the default key (see 'valt default-key') without
                                 asking. Otherwise you are asked, unless it already is the default.
    --no-default                 Do not make the new key the default key, and do not ask.
    --no-verify                  Do not verify keys.
    --no-advice                  Do not show passphrase advice.
    -q, --quick                  Same as --no-advice --no-verify, and the default key is not offered
                                 (--default still applies).
    --no-pdf                     Do not generate the paper key PDF.
    -k, --key-info KEY-INFO      Key info file to use instead of the default for PDF generation.
    -t, --template TEMPLATE      Typst template file to use instead of the default for PDF
                                 generation.
    -c, --style STYLE            Typst file with style overrides to apply for PDF generation.
    -h, --help                   Print this help message.

The PDF contains your keys, also in encrypted form, to serve as a backup for you and/or your
successors, along with detailed usage instructions. Keys are represented as a QR code and again in
a text format (often called "paper keys"). Content is personalized from a key.info file; if it has
not been completed, the PDF is skipped and can be generated later with 'valt paper'.

The PDF is opened when done, so that you can check and print it. Please ensure that you print at
least one copy, then either write your passphrase on the last page or, more securely, say in the
Notes section where to find it, and store copies in secure locations, e.g. safe deposit box/fire
safe and/or with trusted people!

Document Customization

The PDF is typeset by typst (https://typst.app). The template can be replaced, and style overrides
applied, with typst files: the default template (key-doc-template.typ) and an example style file
(key-doc-style.typ) are in the valt 'etc' directory. Every variable set in the key.info file is
available to the template as data.NAME (e.g. data.author); data.generated holds values set by valt.
```

### valt paper

```
Generate the paper key PDF for an existing key pair, personalized from the key.info file. The PDF is
written next to the key and replaces any existing one, so this can be re-run whenever key.info
changes. The passphrase is not required, since the private key is included in its encrypted form.

Usage: valt paper [KEY_FILE] [-k KEY-INFO] [-n NAME] [-c STYLE] [-t TEMPLATE]

    KEY_FILE                 The private key file (default: the default key; see 'valt
                             default-key').
    -n, --name NAME          Use the NAME.key file in the valt config directory, e.g. bob ->
                             bob.key.
    -k, --key-info KEY-INFO  Key info file to use instead of the default.
    -t, --template TEMPLATE  Typst template file to use instead of the default.
    -c, --style STYLE        Typst file with style overrides to apply.
    -h, --help               Print this help message.

The PDF is opened when done, so that you can check and print it. Please ensure that you print at
least one copy, then either write your passphrase on the last page or, more securely, say in the
Notes section where to find it. See 'valt keys --help' for document
customization details.
```

### valt key-info

```
Fill in the paper key's personal information (the key.info file) in a web page: the letter, the
people who can help, and notes. The page opens in your browser with the current values; when you
save it, valt imports it into key.info and offers to regenerate the paper key.

Usage: valt key-info [-d DOWNLOADS] [-k KEY-INFO] [-t TIMEOUT]

    -k, --key-info KEY-INFO    Key info file to write (default: key.info in the valt config
                               directory).
    -d, --downloads DOWNLOADS  Your browser's downloads directory (default: ~/Downloads).
    -t, --timeout TIMEOUT      How many minutes to wait for the page; the page expires then too.
                               (default: 60)
    -h, --help                 Print this help message.

The page works offline and sends nothing anywhere: Save downloads valt-key-info-ID.json,
encrypted with a one-time key, which valt imports and then deletes. Cancel leaves key.info
unchanged. key.info can also be edited by hand.
```

### valt verify

```
Verify a key pair, and optionally files encrypted or archived with it. You will be prompted for the
passphrase that protects the private key, once.

Usage: valt verify [FILE...] [-i IDENTITY]

    FILE...                  Public keys (.pub) to check against the private key, and encrypted
                             files (e.g. .age) and secure archives (.valt) to verify.
    -i, --identity IDENTITY  The private key file (default: the default key; see 'valt
                             default-key').
    -h, --help               Print this help message.

The private key must decrypt with its passphrase. Each public key must match it: the keys it
contains must be the private key's, a file encrypted to it must decrypt with the private key,
and a signature made with the private key must verify. With no public key given, the .pub
file next to the private key is used, if there is one.

Each encrypted file must decrypt with the private key (nothing is written), and its signature
(FILE.minisig) must verify if it has one; a warning is shown if it does not. Each secure
archive must have both of its signatures verify, as with 'valt archive verify'.
```

### valt public-key

```
Recreate the public key file (.pub) for a private key, e.g. if it was lost. The private key contains
everything in the public key file, so the result is identical to the one made with the key. You will
be asked for the private key's passphrase.

Usage: valt public-key [KEY_FILE] [-f] [-o OUTPUT]

    KEY_FILE             The private key file (default: the default key; see 'valt default-key').
    -o, --output OUTPUT  The public key file to write (default: next to the private key, with a .pub
                         suffix).
    -f, --force          Replace an existing public key file.
    -h, --help           Print this help message.
```

### valt default-key

```
Show or set the default private key file, used by any command when no key is given.

Usage: valt default-key [KEY_FILE] [--clear]

    KEY_FILE    The valt private key file to use by default.
    --clear     Remove the setting, so that the built-in default is used.
    -h, --help  Print this help message.

With no arguments, shows the default key and where it comes from. The default is, in order:
the VALT_KEY_FILE environment variable, the setting made here (stored in valt.conf in the
valt config directory), or valt.key in the valt config directory.
```

## Files

### valt encrypt

```
Encrypt a single file to FILE.age and sign it with your private key (FILE.age.minisig). Your own
public key is always a recipient unless --no-self is given. Use 'valt archive create' for
directories or multiple files.

Usage: valt encrypt FILE [-a] [--delete] [-f] [-i IDENTITY] [--no-self] [--no-sign] [-o OUTPUT]
                    [-r RECIPIENT]... [-R RECIPIENT-FILE]... [--verify]

    FILE                                 The file to encrypt.
    -i, --identity IDENTITY              Your private key file, used to sign and to find your public
                                         key (the .pub file next to it); default: the default key
                                         (see 'valt default-key').
    -r, --recipient RECIPIENT            Also encrypt to this recipient (an age public key). Can be
                                         repeated.
    -R, --recipient-file RECIPIENT-FILE  Also encrypt to the recipient(s) in this file, e.g. a valt
                                         .pub file. Can be repeated.
    --no-self                            Do not include your own public key as a recipient.
    --no-sign                            Do not sign the encrypted file.
    -a, --armor                          Write PEM encoded (text) output.
    -o, --output OUTPUT                  The output file ('-' for standard output, which requires
                                         --no-sign); default: FILE.age.
    -f, --force                          Overwrite an existing output file.
    --verify                             Decrypt the result with your private key and confirm it
                                         matches FILE.
    --delete                             Delete FILE after a successful --verify. This is an
                                         ordinary delete, not a secure erase.
    -h, --help                           Print this help message.
```

### valt decrypt

```
Decrypt an encrypted file, or verify and extract a secure archive (.valt). You will be prompted for
the passphrase that protects the private key.

Usage: valt decrypt FILE [-f] [-i IDENTITY] [-o OUTPUT]

    FILE                     The encrypted file (.age) or secure archive (.valt).
    -i, --identity IDENTITY  The private key file (default: the default key; see 'valt
                             default-key').
    -o, --output OUTPUT      For a file, the output file ('-' for standard output; default: FILE
                             without .age). For an archive, the existing directory to extract into
                             (default: the current directory).
    -f, --force              Overwrite an existing output file.
    -h, --help               Print this help message.

If a signature file (FILE.minisig) is present, it is verified before decrypting and decryption
stops if it does not match. A warning is shown if there is no signature. Archives always contain
signatures, which are verified before extracting.
```

## Archives

A secure archive (`.valt`) holds any number of files and directories. It is signed both inside and outside the
encryption, so that the contents can still be verified if the outer signature is lost. A public companion
(`.valt.pub`) containing the outer signature, public keys and README, but no encrypted data, is created alongside it.

### valt archive create

```
Create a signed, encrypted secure archive (.valt) from files and directories, and its public
companion (.valt.pub). Your own public key is always a recipient unless --no-self is given. You will
be prompted for the passphrase that protects your private key.

Usage: valt archive create [INPUT...] [-f] [-i IDENTITY] [-n NAME] [--no-mac-metadata] [--no-self]
                           [-o OUTPUT-DIR] [-r RECIPIENT]... [-R RECIPIENT-FILE]... [-u USER-TEXT]
                           [-z ZONE]

    INPUT...                             Files and directories to add. '-C DIR' changes to DIR
                                         before processing the inputs that follow it; an '@'
                                         prefixed path is a tar archive whose contents are added.
    -i, --identity IDENTITY              Your private key file, used to sign and to find your public
                                         key (the .pub file next to it); default: the default key
                                         (see 'valt default-key').
    -r, --recipient RECIPIENT            Also encrypt to this recipient (an age public key). Can be
                                         repeated.
    -R, --recipient-file RECIPIENT-FILE  Also encrypt to the recipient(s) in this file, e.g. a valt
                                         .pub file. Can be repeated.
    --no-self                            Do not include your own public key as a recipient.
    -n, --name NAME                      The archive file name prefix (default: your user name).
    -z, --zone ZONE                      The time zone for the timestamp in the archive name:
                                         'local' (the system time zone), 'UTC', or a name such as
                                         'America/Los_Angeles' (default: local).
    -u, --user-text USER-TEXT            Text to include in the archive's README. Can contain '\n'.
    -o, --output-dir OUTPUT-DIR          The directory to write the archive to (default: the current
                                         directory).
    -f, --force                          Overwrite an existing archive.
    --no-mac-metadata                    Do not keep the macOS metadata (extended attributes such as
                                         Finder tags, ACLs and file flags) of the files added. It is
                                         kept by default, but only macOS tar restores it; other
                                         tars, e.g. on Linux, may warn about it.
    -h, --help                           Print this help message.

The public companion holds no secrets, only the archive's signature, public keys and README, so it
is safe to share. With it, anyone can confirm that a copy of the archive is authentic and
unchanged, without a key. Keep it apart from the archive (e.g. with your paper key), so that an
archive replaced by one signed with another key would not match it.
```

### valt archive verify

```
Verify both signatures of a secure archive (.valt) without extracting it. The inner signature is
checked after decrypting, so you will be prompted for the passphrase that protects your private key.

Usage: valt archive verify ARCHIVE [-i IDENTITY]

    ARCHIVE                  The secure archive (.valt).
    -i, --identity IDENTITY  Your private key file (default: the default key; see 'valt
                             default-key').
    -h, --help               Print this help message.
```

### valt archive extract

```
Verify and extract a secure archive (.valt). Same as 'valt decrypt ARCHIVE'.

Usage: valt archive extract ARCHIVE [-i IDENTITY] [-o OUTPUT-DIR]

    ARCHIVE                      The secure archive (.valt).
    -i, --identity IDENTITY      Your private key file (default: the default key; see 'valt
                                 default-key').
    -o, --output-dir OUTPUT-DIR  The existing directory to extract into (default: the current
                                 directory).
    -h, --help                   Print this help message.
```

## Passwords

valt rates strength with [mrld](https://github.com/phoggy/mrld), and checks for breaches with the
[HaveIBeenPwned](https://haveibeenpwned.com/Passwords) database.

### valt passphrase

```
Generate random passphrases. Passphrases are made of words chosen at random from a list of 17,576,
so they are much easier to remember than random passwords of similar strength. Use 'valt pass-check'
to check the strength of one.

Usage: valt passphrase [-n COUNT] [-s SEPARATOR] [-w WORDS]

    -w, --words WORDS          The number of words in each passphrase. (default: 5)
    -n, --count COUNT          The number of passphrases to generate. (default: 1)
    -s, --separator SEPARATOR  The text between words (default: a space).
    -h, --help                 Print this help message.
```

### valt password

```
Generate random passwords, using letters, digits and symbols, with a random length between --min and
--max. Use 'valt pass-check' to check the strength of one.

Usage: valt password [-n COUNT] [--max MAX] [--min MIN]

    --min MIN          The minimum length. (default: 24)
    --max MAX          The maximum length. (default: 32)
    -n, --count COUNT  The number of passwords to generate. (default: 1)
    -h, --help         Print this help message.
```

### valt pass-check

```
Check a password or passphrase: rate its strength, and look it up in the HaveIBeenPwned database of
known data breaches. You will be prompted for it; it is read from standard input if that is not a
terminal.

Usage: valt pass-check [-b] [-t THREAT-LEVEL] [-u account|file]

    -u, --use-case account|file      What it protects: 'account' (an online account, whose password
                                     hashes could be stolen and attacked quickly) or 'file' (an
                                     encrypted file or private key, such as a valt key, protected by
                                     age's deliberately slow hashing). (default: account)
    -t, --threat-level THREAT-LEVEL  How capable an attacker to judge strength against. One of:
                                     casual, motivated, professional, nation-state. (default:
                                     professional)
    -b, --breach-only                Only look it up in the breach database; do not rate its
                                     strength.
    -h, --help                       Print this help message.

The exit status is 0 if it appears safe to use, 1 if not, or 2 if it is strong enough but known
breaches could not be checked (e.g. when offline). With --breach-only it is 0 if it was not
found and 1 if it was.

Only the first 5 characters of a SHA-1 hash of it are sent, so neither it nor its full hash
leaves this computer (see https://haveibeenpwned.com/API/v3#PwnedPasswords).
```

## Recovery

The `recover` package contains only what is needed to decrypt files and extract archives, and can be run without
installing anything other than [Nix](https://nixos.org/download/):

```bash
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```
