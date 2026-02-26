# valt

Public key file encryption using [rage](https://github.com/str4d/rage)/[age](https://age-encryption.org/).

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

### Recovery

```bash
nix run github:phoggy/valt#recover
```

## Commands

- **keys** - Manage encryption keys
- **encrypt** - Encrypt files using public keys
- **decrypt** - Decrypt files using private keys
- **pass** - Password-based encryption/decryption
