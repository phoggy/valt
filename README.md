# valt

Public key encryption for files and archives, using [age](https://age-encryption.org/) and
[minisign](https://jedisct1.github.io/minisign/).

valt creates a passphrase-protected key pair, plus a printable "paper key" PDF that backs up the key
and explains to your successors how to use it
([see a sample](https://rayvn.ink/valt/assets/sample-paper-key.pdf)). Files are encrypted to your own
key (and optionally to others), and signed so that tampering is detected on decryption.

New to keys and passphrases? The [guide](https://rayvn.ink/valt/guide/) explains how valt's keys and paper key
work, where to keep the passphrase, and what makes a passphrase strong.

## Installation

**With Homebrew:**

```bash
brew tap rayvn-central/brew
brew install valt
```

To upgrade to the latest version:

```bash
brew upgrade valt
```

Homebrew installs valt's dependencies too, including those from other taps, such as
[mrld](https://github.com/phoggy/mrld) (used for password strength estimation): no separate `brew tap` is needed.

**With Nix:**

If you don't have [Nix](https://nixos.org/) yet, install it first:

**Mac with Apple silicon:** Download and run the [Determinate Nix installer](https://dtr.mn/determinate-nix).

**Mac x86:**

```bash
curl -L https://nixos.org/nix/install | sh
```

**Linux:**

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

All installers create a `/nix` volume and take a few minutes to complete. Answer yes to any
prompts and allow any system dialogs that pop up. Once complete, open a new terminal before
continuing.

If you used the Mac x86 installer, enable flakes:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

**Windows:** Nix runs in Windows' own Linux environment, WSL. In PowerShell as administrator, run `wsl --install`,
restart, open Ubuntu from the Start menu, and follow the Linux step above inside it (see
[Install WSL](https://learn.microsoft.com/windows/wsl/install)). Windows files are under `/mnt/c` there.

To remove Nix later: after the Determinate installer, run `/nix/nix-installer uninstall`; after the Mac x86 one, see
[Uninstalling Nix](https://nix.dev/manual/nix/latest/installation/uninstall).

Then:

```bash
nix profile add github:phoggy/valt
```

To install a specific version:

```bash
nix profile add github:phoggy/valt/v0.1.1
```

To upgrade to the latest version:

```bash
nix profile upgrade valt
```

To run without installing:

```bash
nix run github:phoggy/valt
```

All dependencies are declared in the `flake.nix` file in the `runtimeDeps` list. New dependencies must be added there.

### Recovery

*Recovery* is what someone else does to get at your files when you can't: typically an heir, an executor or a person
helping them, using your paper key (or your private key file) and its passphrase to decrypt a file or extract an archive
you left. They don't need valt installed, and shouldn't have to learn it. With [Nix](https://nixos.org/download/), one
command does it:

```bash
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```

The first run downloads what it needs (about 1 GB), so it can take several minutes; later runs start at once.

We suggest this for recovery, rather than installing valt, because:

- **It doesn't depend on what the computer has.** Nix runs valt with exactly the versions of age and its other tools
  that this repository pins and has tested together, whatever Homebrew or a system ships by then.
- **It installs nothing.** It is fetched, run and done: nothing to set up beforehand, or clean up after.
- **It does only what recovery needs:** decrypting files and extracting archives (and decoding the paper key's QR code),
  without valt's prompts about the owner's own paper key.

The paper key ([sample](https://rayvn.ink/valt/assets/sample-paper-key.pdf)) explains all of this step by step, how to rebuild the key file from its QR code or printed text, and how
to recover without Nix, using `age` and `tar` directly.

## Commands

| Command | Description |
|---------|-------------|
| `valt keys` | Create a key pair with an encrypted private key and a paper key as backup. |
| `valt paper` | Create or regenerate the paper key for an existing key pair. |
| `valt key-info` | Fill in the paper key's personal information (`key-info.json`) in a web page, or your editor. |
| `valt encrypt FILE` | Encrypt and sign a single file. |
| `valt decrypt FILE` | Decrypt a file, or verify and extract a secure archive. |
| `valt archive create INPUT...` | Create a signed, encrypted archive of files and directories. |
| `valt archive verify ARCHIVE` | Verify both signatures of a secure archive without extracting it. |
| `valt archive extract ARCHIVE` | Verify and extract a secure archive. |
| `valt verify [FILE...]` | Verify a key pair (the private key decrypts, and matches its public key), and optionally encrypted files and secure archives. |
| `valt public-key [KEY_FILE]` | Recreate a lost public key file (`.pub`) from its private key. |
| `valt default-key [KEY_FILE]` | Show or set the default private key file, used when no key is given. |
| `valt passphrase` | Generate random passphrases. |
| `valt password` | Generate random passwords. |
| `valt pass-check` | Check a password or passphrase: rate its strength, and look it up in known data breaches. |

Use `valt COMMAND --help` for details. Commands that need a private key use `-i KEY_FILE`, or the default key: the
`VALT_KEY_FILE` environment variable, else the key set with `valt default-key`, else `valt.key` in the valt config
directory.

## Quick Start

```bash
valt keys                          # create valt.key and valt.pub (and the paper key, if your key info is complete)
valt paper                         # (re)generate the paper key after changing your key info
valt encrypt taxes.pdf             # writes taxes.pdf.age and taxes.pdf.age.minisig
valt decrypt taxes.pdf.age         # verifies the signature, writes taxes.pdf
valt archive create -C ~/docs .    # writes USER-TIMESTAMP.valt and a shareable .valt.pub
valt decrypt USER-TIMESTAMP.valt   # verifies and extracts into the current directory
```

**Back up your private key.** `valt.key` is encrypted with your passphrase, so copies are safe to
keep: put one in a password manager, on a USB drive or in cloud storage. Without a copy, losing your
computer leaves only the paper key to recover your files with.

To encrypt for someone else as well, add `-r AGE_PUBLIC_KEY` or `-R their.pub` (both can be
repeated). Use `--no-self` to leave your own key out.
