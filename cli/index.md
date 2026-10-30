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

    keys        Create a key pair with an encrypted private key and a paper key as backup.
    paper       Create or regenerate the paper key for an existing key pair.
    encrypt     Encrypt and sign a single file.
    decrypt     Decrypt a file, or verify and extract a secure archive.
    archive     Create, verify or extract a signed, encrypted archive of files and directories.
    passphrase  Generate random passphrases, or check the strength of one you enter.
    password    Generate random passwords, or check the strength of one you enter.
    pwned       Check whether a password or passphrase appears in a known data breach.

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

Usage: valt keys [--css CSS] [--force] [--key-info KEY-INFO] [--name NAME] [--no-advice] [--no-pdf]
                 [--no-verify] [--output-dir OUTPUT-DIR] [--quick] [--template TEMPLATE]

    --name, -n NAME              Name to use for key files, e.g. bob -> bob.pub, bob.key. (default:
                                 valt)
    --output-dir, -o OUTPUT-DIR  Directory for the key files (default: the valt config directory).
    --force, -f                  Overwrite existing key files.
    --no-verify                  Do not verify keys.
    --no-advice                  Do not show passphrase advice.
    --quick, -q                  Same as --no-advice --no-verify.
    --no-pdf                     Do not generate the paper key PDF.
    --key-info, -k KEY-INFO      Key info file to use instead of the default for PDF generation.
    --template, -t TEMPLATE      HTML template file to use instead of the default for PDF
                                 generation.
    --css, -c CSS                CSS file with style overrides to apply for PDF generation.
    --help, -h                   Print this help message.

The PDF contains your keys, also in encrypted form, to serve as a backup for you and/or your
successors, along with detailed usage instructions. Keys are represented as a QR code and again in
a text format (often called "paper keys"). Content is personalized from a key.info file; if it has
not been completed, the PDF is skipped and can be generated later with 'valt paper'.

Please ensure that you print at least one copy of the PDF file and write your passphrase on the
last page (or leave the passphrase blank and add instructions on where to find it in the Notes
section), then store copies in secure locations, e.g. safe deposit box/fire safe and/or with
trusted people!

Document Customization

The HTML template can be changed from the default and CSS style overrides can be applied. The
default template and primary CSS file can be found in the valt 'etc' directory. Template
substitutions are performed with variables defined in the key.info file. Note that keys prefixed
with an underscore are reserved for system use.
```

### valt paper

```
Generate the paper key PDF for an existing key pair, personalized from the key.info file. The PDF is
written next to the key and replaces any existing one, so this can be re-run whenever key.info
changes. The passphrase is not required, since the private key is included in its encrypted form.

Usage: valt paper [KEY_FILE] [--css CSS] [--key-info KEY-INFO] [--name NAME] [--template TEMPLATE]

    KEY_FILE                 The private key file (default: valt.key in the valt config directory).
    --name, -n NAME          Use the NAME.key file in the valt config directory, e.g. bob ->
                             bob.key.
    --key-info, -k KEY-INFO  Key info file to use instead of the default.
    --template, -t TEMPLATE  HTML template file to use instead of the default.
    --css, -c CSS            CSS file with style overrides to apply.
    --help, -h               Print this help message.

Please ensure that you print at least one copy of the PDF file and write your passphrase on the
last page (or leave the passphrase blank and add instructions on where to find it in the Notes
section). See 'valt keys --help' for document customization details.
```

## Files

### valt encrypt

```
Encrypt a single file to FILE.age and sign it with your private key (FILE.age.minisig). Your own
public key is always a recipient unless --no-self is given. Use 'valt archive create' for
directories or multiple files.

Usage: valt encrypt FILE [--armor] [--delete] [--force] [--identity IDENTITY] [--no-self]
                    [--no-sign] [--output OUTPUT] [--recipient RECIPIENT]... [--recipient-file
                    RECIPIENT-FILE]... [--verify]

    FILE                                 The file to encrypt.
    --identity, -i IDENTITY              Your private key file, used to sign and to find your public
                                         key (the .pub file next to it); default: valt.key in the
                                         valt config directory.
    --recipient, -r RECIPIENT            Also encrypt to this recipient (an age public key). Can be
                                         repeated.
    --recipient-file, -R RECIPIENT-FILE  Also encrypt to the recipient(s) in this file, e.g. a valt
                                         .pub file. Can be repeated.
    --no-self                            Do not include your own public key as a recipient.
    --no-sign                            Do not sign the encrypted file.
    --armor, -a                          Write PEM encoded (text) output.
    --output, -o OUTPUT                  The output file ('-' for standard output, which requires
                                         --no-sign); default: FILE.age.
    --force, -f                          Overwrite an existing output file.
    --verify                             Decrypt the result with your private key and confirm it
                                         matches FILE.
    --delete                             Delete FILE after a successful --verify. This is an
                                         ordinary delete, not a secure erase.
    --help, -h                           Print this help message.
```

### valt decrypt

```
Decrypt an encrypted file, or verify and extract a secure archive (.valt). You will be prompted for
the passphrase that protects the private key.

Usage: valt decrypt FILE [--force] [--identity IDENTITY] [--output OUTPUT]

    FILE                     The encrypted file (.age) or secure archive (.valt).
    --identity, -i IDENTITY  The private key file (default: valt.key in the valt config directory).
    --output, -o OUTPUT      For a file, the output file ('-' for standard output; default: FILE
                             without .age). For an archive, the existing directory to extract into
                             (default: the current directory).
    --force, -f              Overwrite an existing output file.
    --help, -h               Print this help message.

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
Create a signed, encrypted secure archive (.valt) from files and directories. A public companion
(.valt.pub) that is safe to share is also created. Your own public key is always a recipient unless
--no-self is given. You will be prompted for the passphrase that protects your private key.

Usage: valt archive create [INPUT...] [--force] [--identity IDENTITY] [--name NAME] [--no-self]
                           [--output-dir OUTPUT-DIR] [--recipient RECIPIENT]... [--recipient-file
                           RECIPIENT-FILE]... [--user-text USER-TEXT] [--zone ZONE]

    INPUT...                             Files and directories to add. '-C DIR' changes to DIR
                                         before processing the inputs that follow it; an '@'
                                         prefixed path is a tar archive whose contents are added.
    --identity, -i IDENTITY              Your private key file, used to sign and to find your public
                                         key (the .pub file next to it); default: valt.key in the
                                         valt config directory.
    --recipient, -r RECIPIENT            Also encrypt to this recipient (an age public key). Can be
                                         repeated.
    --recipient-file, -R RECIPIENT-FILE  Also encrypt to the recipient(s) in this file, e.g. a valt
                                         .pub file. Can be repeated.
    --no-self                            Do not include your own public key as a recipient.
    --name, -n NAME                      The archive file name prefix (default: your user name).
    --zone, -z ZONE                      The timezone for the timestamp in the archive name, e.g.
                                         PDT (default: UTC).
    --user-text, -u USER-TEXT            Text to include in the archive's README. Can contain '\n'.
    --output-dir, -o OUTPUT-DIR          The directory to write the archive to (default: the current
                                         directory).
    --force, -f                          Overwrite an existing archive.
    --help, -h                           Print this help message.
```

### valt archive verify

```
Verify both signatures of a secure archive (.valt) without extracting it. The inner signature is
checked after decrypting, so you will be prompted for the passphrase that protects your private key.

Usage: valt archive verify ARCHIVE [--identity IDENTITY]

    ARCHIVE                  The secure archive (.valt).
    --identity, -i IDENTITY  Your private key file (default: valt.key in the valt config directory).
    --help, -h               Print this help message.
```

### valt archive extract

```
Verify and extract a secure archive (.valt). Same as 'valt decrypt ARCHIVE'.

Usage: valt archive extract ARCHIVE [--identity IDENTITY] [--output-dir OUTPUT-DIR]

    ARCHIVE                      The secure archive (.valt).
    --identity, -i IDENTITY      Your private key file (default: valt.key in the valt config
                                 directory).
    --output-dir, -o OUTPUT-DIR  The existing directory to extract into (default: the current
                                 directory).
    --help, -h                   Print this help message.
```

## Passwords

valt rates strength with [mrld](https://github.com/phoggy/mrld), and checks for breaches with the
[HaveIBeenPwned](https://haveibeenpwned.com/Passwords) database.

### valt passphrase

```
Generate random passphrases, or check the strength of one you enter. Passphrases are made of words
chosen at random from a list of 17,576, so they are much easier to remember than random passwords of
similar strength.

Usage: valt passphrase [--check] [--count COUNT] [--separator SEPARATOR] [--threat-level
                       THREAT-LEVEL] [--use-case file|account] [--words WORDS]

    --words, -w WORDS                The number of words in each passphrase. (default: 5)
    --count, -n COUNT                The number of passphrases to generate. (default: 1)
    --separator, -s SEPARATOR        The text between words (default: a space).
    --check, -c                      Instead of generating, prompt for a passphrase and report its
                                     strength and whether it appears in a known breach. Reads from
                                     standard input if it is not a terminal.
    --use-case, -u file|account      What the passphrase protects: 'file' (an encrypted file or
                                     private key, open to unlimited offline guessing) or 'account'
                                     (an online account). (default: file)
    --threat-level, -t THREAT-LEVEL  How capable an attacker to judge strength against. One of:
                                     casual, motivated, professional, nation-state. (default:
                                     professional)
    --help, -h                       Print this help message.

With --check, the exit status is 0 if the passphrase appears safe to use, or 1 if not.
```

### valt password

```
Generate random passwords, or check the strength of one you enter. Passwords use letters, digits and
symbols, with a random length between --min and --max.

Usage: valt password [--check] [--count COUNT] [--max MAX] [--min MIN] [--threat-level THREAT-LEVEL]
                     [--use-case account|file]

    --min MIN                        The minimum length. (default: 24)
    --max MAX                        The maximum length. (default: 32)
    --count, -n COUNT                The number of passwords to generate. (default: 1)
    --check, -c                      Instead of generating, prompt for a password and report its
                                     strength and whether it appears in a known breach. Reads from
                                     standard input if it is not a terminal.
    --use-case, -u account|file      What the password protects: 'account' (an online account) or
                                     'file' (an encrypted file or private key, open to unlimited
                                     offline guessing). (default: account)
    --threat-level, -t THREAT-LEVEL  How capable an attacker to judge strength against. One of:
                                     casual, motivated, professional, nation-state. (default:
                                     professional)
    --help, -h                       Print this help message.

With --check, the exit status is 0 if the password appears safe to use, or 1 if not.
```

### valt pwned

```
Check whether a password or passphrase appears in a known data breach, using the HaveIBeenPwned
database. You will be prompted for it; it is read from standard input if that is not a terminal.

Usage: valt pwned

    --help, -h  Print this help message.

Only the first 5 characters of a SHA-1 hash of the password are sent, so neither the password
nor its full hash leaves this computer (see https://haveibeenpwned.com/API/v3#PwnedPasswords).
The exit status is 0 if it was not found, or 1 if it was.
```

## Recovery

The `recover` package contains only what is needed to decrypt files and extract archives, and can be run without
installing anything other than [Nix](https://nixos.org/download/):

```bash
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```
