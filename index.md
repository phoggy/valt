---
layout: home
title: Home
nav_order: 1
---

# valt

Public key encryption for files and archives, using [age](https://age-encryption.org/) and
[minisign](https://jedisct1.github.io/minisign/), designed so that what you encrypt today can still be opened years, or
decades, from now: by you, or by the people who come after you, such as your heirs, your executor and whoever helps
them. Built on [rayvn](/rayvn).

That goal shapes the design:

- **A paper key for your successors.** valt creates a passphrase-protected key pair, plus a printable *paper key*: a
  PDF that backs up the key and explains, step by step, how to use it
  ([see a sample](/valt/assets/sample-paper-key.pdf)).
- **Recovery without valt, or expertise.** One [Nix](https://nixos.org/download/) command recovers your files, with
  the versions of valt and its tools that were tested together, and installs nothing (see [Recovery](#recovery)). The
  paper key also explains how to recover with `age` and `tar` alone.
- **Standard, long-lived tools.** Files are encrypted with age and signed with minisign, open formats with more than
  one implementation, and archives are tar files. valt itself is written in bash: ubiquitous, stable and small,
  maintained and improved for decades, and almost elemental in computing, so it should be around long into the future.
  As a script, valt is also readable: anyone can check what it does, or ask an AI assistant to explain it (they are
  fluent in bash).
- **Post-quantum from the start.** Keys are always age's hybrid of ML-KEM-768 and X25519, so files encrypted today stay
  protected against future quantum computers, even if recorded now and attacked later (see the
  [design notes](/valt/api/valt-keys#design-notes)).
- **Tampering is detected.** Files are encrypted to your own key (and optionally to others), and signed, so that any
  change is detected on decryption. Any number of files and directories can be kept together in a signed, encrypted
  [*secure archive*](/valt/api/valt-archive#secure-archives).

## First Look

```bash
valt keys                          # create USER.key and USER.pub (and the paper key, once your key info is complete)
valt encrypt taxes.pdf             # writes taxes.pdf.age and taxes.pdf.age.minisig
valt decrypt taxes.pdf.age         # verifies the signature, writes taxes.pdf
valt archive create -C ~/docs .    # writes USER-TIMESTAMP.valt and a shareable .valt.pub
valt decrypt USER-TIMESTAMP.valt   # verifies and extracts into the current directory
valt pass-check -u file            # rates a passphrase and checks it against known breaches
```

- Keys are named after your user name, e.g. `alex.key` and `alex.pub` for user `alex` (or another name with
  `--name`), so that the public keys you share, and the ones others share with you, say whose they are. Your first key
  is the default; most commands take `-i KEY_FILE` to use another.
- Your own key is always a recipient. Add others with `-r AGE_PUBLIC_KEY` or `-R their.pub`, or leave yours out with
  `--no-self`.
- The private key is only as safe as its passphrase, so `valt keys` rejects weak or breached ones. `valt passphrase`
  generates strong, memorable ones.
- An archive made by another program, such as a [wardn](/wardn) vault backup, can say how to restore it, in its
  [manifest](/valt/api/valt-archive#manifests): `valt decrypt` then offers to restore it with that program (installed,
  or with Nix or Homebrew) rather than extracting its files.
- **Back up your private key.** It is encrypted with its passphrase, so copies are safe to keep: put one in a password
  manager, on a USB drive or in cloud storage. Without a copy, losing your computer leaves only the paper key.

See the [CLI reference](/valt/cli/) for every command and option.

## Install

With [Homebrew](https://brew.sh):

```bash
brew tap rayvn-central/tap
brew trust --tap rayvn-central/tap
brew install valt
```

Homebrew installs formulae from taps other than its own only once you trust them, hence `brew trust`.

Or with [Nix](https://nixos.org/download/):

```bash
nix profile add github:phoggy/valt
```

See the [README](https://github.com/phoggy/valt#installation) for installing Nix, upgrading and other options.

## Recovery

*Recovery* is what someone else does to get at your files when you can't: typically an heir, an executor or a person
helping them, using your paper key and its passphrase to decrypt a file or extract an archive you left. They don't need
valt installed, only [Nix](https://nixos.org/download/):

```bash
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```

We suggest this for recovery, rather than installing valt, because it doesn't depend on what the computer has (Nix runs
valt with exactly the versions of age and its other tools that valt pins and has tested together), it installs nothing,
and it does only what recovery needs.

The paper key ([sample](/valt/assets/sample-paper-key.pdf)) explains this step by step, how to rebuild the key file from its QR code or printed text, and how to
recover without Nix, using `age` and `tar` directly.

## Best Practices

Your files stay private as long as no one gets all three of: the encrypted files (archives, `.age` files, backups),
your private key (the key file, or the paper key) and its passphrase. Any two are not enough. These practices keep
the three apart, while making sure the right people can still bring them together.

- **Keep encrypted files apart from the paper key.** For example, archives and backups on a NAS or in cloud storage,
  and the paper key in a fire safe or a safe deposit box, so that no single theft or loss gets both.
- **A paper key with the passphrase written on it is a complete key.** If you write the passphrase on a copy (see
  [where to keep the passphrase](https://rayvn.ink/valt/guide/#where-to-keep)), keep that copy in your most secure
  place, never with your encrypted files, and give out copies with a note saying where to find it instead.
- **Use a strong passphrase:** one from `valt passphrase`, or checked with `valt pass-check`. Keep it in your head, or
  somewhere apart from the paper key.
- **A password manager is a good place for the passphrase, but not the only one.** Its emergency access can let
  someone you choose reach it. But a disaster that takes your computer may take the password manager too, e.g. if its
  two-step login is on a lost phone, so keep another copy you can reach without it: memorized, or in a sealed envelope.
- **Type the passphrase only on a computer you trust.** Malware that captures it, and finds your key file and encrypted
  files on the same computer, gets everything. To recover, use your own computer, or that of someone you trust, not a
  shared or public one.
- **Practice a recovery.** Once in a while, say yearly, open an archive using only a paper key and its passphrase, the
  way someone else would (see Recovery). It shows that the passphrase still works, the QR code still scans and the
  instructions still make sense, while you can still fix them.
- **Regenerate the paper key when its information changes** (`valt paper`), and destroy the old copies.

## Libraries

### Encryption

| Library | Description |
|---|---|
| [valt/keys](/valt/api/valt-keys) | Key pair generation, verification and recipients. |
| [valt/encrypt](/valt/api/valt-encrypt) | Encryption with public keys or a passphrase. |
| [valt/decrypt](/valt/api/valt-decrypt) | Decryption with a private key or a passphrase. |
| [valt/sign](/valt/api/valt-sign) | File signing and verification with valt keys. |
| [valt/archive](/valt/api/valt-archive) | Signed, encrypted secure archives of files and directories. |

### Paper Keys

| Library | Description |
|---|---|
| [valt/paper-keys](/valt/api/valt-paper-keys) | Paper key PDF generation from your key info, and reminders to keep it current. |
| [valt/key-info](/valt/api/valt-key-info) | The paper key's personal information (the key info file), and filling it in. |

### Passwords

| Library | Description |
|---|---|
| [valt/password](/valt/api/valt-password) | Password and passphrase generation, secure input and strength estimates. |
| [valt/pwned](/valt/api/valt-pwned) | HaveIBeenPwned breach checking. |

## Related Projects

- [rayvn](/rayvn) — the shared library framework valt is built on
- [wardn](/wardn) — encrypted Bitwarden vault backup and restore, using valt's [secure archives](/valt/api/valt-archive#secure-archives)
