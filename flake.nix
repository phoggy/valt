{
  description = "valt - Public key file encryption";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    flake-utils.url = "github:numtide/flake-utils";
    rayvn = {
      url = "github:phoggy/rayvn";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    mrld = {
      url = "github:phoggy/mrld";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rayvn, mrld }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        rayvnPkg = rayvn.packages.${system}.default;
        mrldPkg = mrld.packages.${system}.default;

        # The paper key PDF needs typst 0.15 or later, the first to support variable fonts (see etc/fonts), but
        # nixpkgs 26.05 has 0.14. Use typst's release binary until nixpkgs catches up, then switch to pkgs.typst.
        typstVersion = "0.15.1";
        typstReleases = {
          x86_64-darwin = { target = "x86_64-apple-darwin"; hash = "sha256-f5/dlYSGYkXemnngrdj5I2+ub0CopF4sR3HMwU204Po="; };
          aarch64-darwin = { target = "aarch64-apple-darwin"; hash = "sha256-SPYu0DSqOnl4MJV5rGygAEXi7w2nMRToryfP2OdNwFo="; };
          x86_64-linux = { target = "x86_64-unknown-linux-musl"; hash = "sha256-ptB30Kle7VouunFbLa4GvpVPYkzL+FdYoD84ne0zEYw="; };
          aarch64-linux = { target = "aarch64-unknown-linux-musl"; hash = "sha256-WqjXSj2QbmDqEqZqwvN/ju8bFMutcYKnReOToQwj3O4="; };
        };
        typstPkg = let release = typstReleases.${system}; in pkgs.stdenv.mkDerivation {
          pname = "typst";
          version = typstVersion;
          src = pkgs.fetchurl {
            url = "https://github.com/typst/typst/releases/download/v${typstVersion}/typst-${release.target}.tar.xz";
            inherit (release) hash;
          };
          sourceRoot = "typst-${release.target}";
          dontConfigure = true;
          dontBuild = true;
          installPhase = ''
            install -Dm755 typst "$out/bin/typst"
            install -Dm644 LICENSE "$out/share/licenses/typst/LICENSE"
          '';
          meta = with pkgs.lib; {
            description = "Markup-based typesetting system";
            homepage = "https://typst.app";
            license = licenses.asl20;
            platforms = builtins.attrNames typstReleases;
          };
        };

        # Runtime dependencies
        runtimeDeps = [
          pkgs.bash
          rayvnPkg
          pkgs.age
          pkgs.gawk
          pkgs.gnused
          pkgs.gnugrep
          pkgs.coreutils
          pkgs.gnutar
          pkgs.xz
          pkgs.phraze
          mrldPkg
          pkgs.curl
          pkgs.openssl
          pkgs.jq
          pkgs.minisign
          pkgs.qrtool
          typstPkg
          pkgs.exiftool
          pkgs.qpdf
        ];

        # Minimal runtime dependencies for recovery (decryption and archive extraction)
        recoverDeps = [
          pkgs.bash
          rayvnPkg
          pkgs.age
          pkgs.minisign
          pkgs.gawk
          pkgs.gnused
          pkgs.gnugrep
          pkgs.coreutils
          pkgs.gnutar
          pkgs.xz
        ];

        valt = pkgs.stdenv.mkDerivation {
          pname = "valt";
          version = "0.2.0";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/valt "$out/bin/valt"

            # Install lib/
            mkdir -p "$out/share/valt/lib"
            cp lib/*.sh "$out/share/valt/lib/"

            # Install etc/
            mkdir -p "$out/share/valt/etc"
            cp -r etc/* "$out/share/valt/etc/"

            # Install shell completions
            install -Dm644 completions/valt.bash "$out/share/bash-completion/completions/valt"
            install -Dm644 completions/valt.zsh "$out/share/zsh/site-functions/_valt"

            # Install rayvn.pkg with version metadata
            sed '/^projectVersion=/d; /^projectReleaseDate=/d; /^projectFlake=/d; /^projectBuildRev=/d; /^projectNixpkgsRev=/d' \
                rayvn.pkg > "$out/share/valt/rayvn.pkg"
            cat >> "$out/share/valt/rayvn.pkg" <<EOF

# Version metadata (added by Nix build)
projectVersion='$version'
projectReleaseDate='$(date "+%Y-%m-%d %H:%M:%S %Z")'
projectFlake='github:phoggy/valt/v$version'
projectBuildRev='${self.shortRev or "dev"}'
projectNixpkgsRev='${nixpkgs.shortRev}'
EOF

            # Wrap valt with runtime dependencies on PATH. Include $out/bin so rayvn.up can find 'rayvn.up' and 'valt'
            # via PATH lookup for project root resolution. The paper key PDF uses the fonts in etc/fonts.
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}"

            runHook postInstall
          '';

          # patchShebangs rewrites #!/usr/bin/env bash to the non-interactive
          # bash, which lacks builtins like compgen. Restore the shebangs so
          # they resolve via PATH, where the wrapper provides bash-interactive.
          postFixup = ''
            for f in "$out/bin/.valt-wrapped" "$out/share/valt/lib/"*.sh; do
              if [ -f "$f" ]; then
                sed -i "1s|^#\\!.*/bin/bash.*|#!/usr/bin/env bash|" "$f"
              fi
            done
          '';

          meta = with pkgs.lib; {
            description = "Public key file encryption using age";
            homepage = "https://github.com/phoggy/valt";
            license = licenses.gpl3Only;
            platforms = platforms.unix;
          };
        };

        # Minimal recovery package with just decryption deps
        valtRecover = pkgs.stdenv.mkDerivation {
          pname = "valt-recover";
          version = "0.2.0";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install only what's needed for decryption
            install -Dm755 bin/valt "$out/bin/valt"

            mkdir -p "$out/share/valt/lib"
            cp lib/*.sh "$out/share/valt/lib/"

            # etc/ without the fonts, which only the paper key PDF uses
            mkdir -p "$out/share/valt/etc"
            cp -r etc/* "$out/share/valt/etc/"
            rm -rf "$out/share/valt/etc/fonts"

            # Install rayvn.pkg with version metadata
            sed '/^projectVersion=/d; /^projectReleaseDate=/d; /^projectFlake=/d; /^projectBuildRev=/d; /^projectNixpkgsRev=/d' \
                rayvn.pkg > "$out/share/valt/rayvn.pkg"
            cat >> "$out/share/valt/rayvn.pkg" <<EOF

# Version metadata (added by Nix build)
projectVersion='$version'
projectReleaseDate='$(date "+%Y-%m-%d %H:%M:%S %Z")'
projectFlake='github:phoggy/valt/v$version'
projectBuildRev='${self.shortRev or "dev"}'
projectNixpkgsRev='${nixpkgs.shortRev}'
EOF

            # Wrap with minimal deps for recovery.
            # Include $out/bin for rayvn.up project root resolution. Heirs recover with another's key, so they are
            # not reminded about paper keys.
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath recoverDeps}" \
              --set VALT_NO_PAPER_KEY_REMINDERS 1

            # For decoding the paper key QR code (see etc/key-doc-template.typ).
            ln -s "${pkgs.qrtool}/bin/qrtool" "$out/bin/qrtool"

            runHook postInstall
          '';

          postFixup = ''
            for f in "$out/bin/.valt-wrapped" "$out/share/valt/lib/"*.sh; do
              if [ -f "$f" ]; then
                sed -i "1s|^#\\!.*/bin/bash.*|#!/usr/bin/env bash|" "$f"
              fi
            done
          '';

          meta = with pkgs.lib; {
            description = "valt recovery tool - minimal decryption support";
            homepage = "https://github.com/phoggy/valt";
            license = licenses.gpl3Only;
            platforms = platforms.unix;
          };
        };
      in
      {
        packages = {
          default = valt;
          valt = valt;
          recover = valtRecover;
        };

        apps = {
          default = {
            type = "app";
            program = "${valt}/bin/valt";
          };
          valt = {
            type = "app";
            program = "${valt}/bin/valt";
          };
          recover = {
            type = "app";
            program = "${valtRecover}/bin/valt";
          };
          qrtool = {
            type = "app";
            program = "${valtRecover}/bin/qrtool";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [
            pkgs.shellcheck
          ];
          shellHook = ''
            export PATH="${self}/bin:$PATH"
            [[ $- == *i* ]] && echo "valt dev shell ready"
          '';
        };
      }
    );
}
