# valt

Public key file encryption using [rage](https://github.com/str4d/rage)/[age](https://age-encryption.org/).

## Prerequisites

Requires [Nix](https://nixos.org/). To install:

```bash
curl -L https://nixos.org/nix/install | sh
```

## Installation

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

