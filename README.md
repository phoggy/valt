# valt

Public key encryption for files and archives, using [age](https://age-encryption.org/) and
[minisign](https://jedisct1.github.io/minisign/).

valt creates a passphrase-protected key pair, plus a printable "paper key" PDF that backs up the key
and explains to your successors how to use it. Files are encrypted to your own key (and optionally to
others), and signed so that tampering is detected on decryption.

## Prerequisites

Requires [Nix](https://nixos.org/).

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

## Installation

**With Homebrew:**

```bash
brew tap rayvn-central/brew
brew install valt
```

**With Nix:**

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
Homebrew installs resolve these automatically, including third-party taps like [mrld](https://github.com/phoggy/mrld)
(used for password strength estimation) - no separate `brew tap` step is needed.

### Recovery

A minimal package that can only decrypt files and extract archives, for use by someone who has
been given a key and an encrypted file:

```bash
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```

## Commands

| Command | Description |
|---------|-------------|
| `valt keys` | Create a key pair with an encrypted private key and a paper key as backup. |
| `valt paper` | Create or regenerate the paper key for an existing key pair. |
| `valt encrypt FILE` | Encrypt and sign a single file. |
| `valt decrypt FILE` | Decrypt a file, or verify and extract a secure archive. |
| `valt archive create INPUT...` | Create a signed, encrypted archive of files and directories. |
| `valt archive verify ARCHIVE` | Verify both signatures of a secure archive without extracting it. |
| `valt archive extract ARCHIVE` | Verify and extract a secure archive. |

Use `valt COMMAND --help` for details. Keys default to `valt.key` and `valt.pub` in the valt
config directory; most commands take `-i KEY_FILE` to use another.

## Quick Start

```bash
valt keys                          # create valt.key and valt.pub (and the paper key, if key.info is complete)
valt paper                         # (re)generate the paper key after editing key.info
valt encrypt taxes.pdf             # writes taxes.pdf.age and taxes.pdf.age.minisig
valt decrypt taxes.pdf.age         # verifies the signature, writes taxes.pdf
valt archive create -C ~/docs .    # writes USER-TIMESTAMP.valt and a shareable .valt.pub
valt decrypt USER-TIMESTAMP.valt   # verifies and extracts into the current directory
```

To encrypt for someone else as well, add `-r AGE_PUBLIC_KEY` or `-R their.pub` (both can be
repeated). Use `--no-self` to leave your own key out.
