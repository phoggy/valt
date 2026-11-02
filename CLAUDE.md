# valt

@~/.config/rayvn/claude-rayvn.md

The import above loads the rayvn guide for Claude Code, which rayvn generates. If it is missing, run
`rayvn index --claude` to create it.

## About valt

valt provides public key encryption for files and secure archives using age (encryption) and minisign (signatures).
Private keys are passphrase protected and backed up as printable paper keys (PDF), which include recovery instructions
for whoever inherits them.

- `bin/valt` is a single CLI with a generated parser: after changing `cliSpec` or its doc comments, run `rayvn args valt`.
- The `recover` Nix package is what heirs run (`nix run github:phoggy/valt#recover`); it must keep working with only the
  tools in `recoverDeps` in `flake.nix`. All runtime tools must be declared in `flake.nix`.
- The paper key template is `etc/key-doc-template.typ`, compiled to PDF by typst 0.15+ (the first with variable font
  support) with the fonts in `etc/fonts`; its instructions are read by non-technical heirs. nixpkgs 26.05 has typst
  0.14, so `flake.nix` packages typst's release binary (`typstPkg`). Code is set with ligatures
  off, so that the armored key and options print exactly as typed.

## Test hooks

- `rayvnTest_ValtKeyPassphrase` - supplies the key passphrase instead of prompting for it
- `rayvnTest_CheckKeyPassphraseStrength` - checks the strength of the supplied passphrase when creating keys (normally
  only typed passphrases are checked)
- `rayvnTest_PwnedApiUrl` - uses a local (e.g. `file://`) copy of the HaveIBeenPwned range API, so tests run offline
