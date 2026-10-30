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

        # Build puppeteer node_modules at derivation time (no runtime npm install).
        # PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1: on Linux we use pkgs.chromium; on macOS
        # pkgs.chromium is unavailable so pdf.sh detects a system browser at runtime.
        pdfNodeDeps = pkgs.buildNpmPackage {
          name = "valt-pdf-node-deps";
          src = ./node;
          npmDepsHash = "sha256-F9ofvmPKcFZJi9VN5Rb2jk8fv2Wnzmrqh9c/KxzLqAc=";
          dontNpmBuild = true;
          npmInstallFlags = [ "--production" ];
          env = {
            PUPPETEER_SKIP_DOWNLOAD = "1";
            PUPPETEER_SKIP_CHROME_DOWNLOAD = "1";
          };
          installPhase = ''
            mkdir -p $out
            cp -r node_modules $out/
          '';
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
          pkgs.nodejs
          pkgs.jq
          pkgs.minisign
        ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
          pkgs.chromium
        ] ++ [
          pkgs.qrtool
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

        # Fonts for PDF generation
        fonts = [
          pkgs.google-fonts  # Includes Indie Flower and Fira Code
        ];

        valt = pkgs.stdenv.mkDerivation {
          pname = "valt";
          version = "0.1.1";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/valt "$out/bin/valt"
            install -Dm755 bin/valt-pinentry "$out/bin/valt-pinentry"

            # Install lib/
            mkdir -p "$out/share/valt/lib"
            cp lib/*.sh "$out/share/valt/lib/"

            # Install etc/
            mkdir -p "$out/share/valt/etc"
            cp -r etc/* "$out/share/valt/etc/"

            # Install node/
            mkdir -p "$out/share/valt/node"
            cp node/*.js "$out/share/valt/node/"

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

            # Wrap valt with runtime dependencies on PATH and font config.
            # Include $out/bin so rayvn.up can find 'rayvn.up' and 'valt' via
            # PATH lookup for project root resolution.
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}" \
              --set FONTCONFIG_FILE "${pkgs.makeFontsConf { fontDirectories = fonts; }}" \
              ${pkgs.lib.optionalString pkgs.stdenv.isLinux "--set PUPPETEER_EXECUTABLE_PATH \"${pkgs.chromium}/bin/chromium\""} \
              --set VALT_PDF_DEPS_HOME "${pdfNodeDeps}"

            # Wrap valt-pinentry similarly
            wrapProgram "$out/bin/valt-pinentry" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}"

            runHook postInstall
          '';

          # patchShebangs rewrites #!/usr/bin/env bash to the non-interactive
          # bash, which lacks builtins like compgen. Restore the shebangs so
          # they resolve via PATH, where the wrapper provides bash-interactive.
          postFixup = ''
            for f in "$out/bin/.valt-wrapped" "$out/bin/.valt-pinentry-wrapped" "$out/share/valt/lib/"*.sh; do
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
          version = "0.1.1";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install only what's needed for decryption
            install -Dm755 bin/valt "$out/bin/valt"
            install -Dm755 bin/valt-pinentry "$out/bin/valt-pinentry"

            mkdir -p "$out/share/valt/lib"
            cp lib/*.sh "$out/share/valt/lib/"

            mkdir -p "$out/share/valt/etc"
            cp -r etc/* "$out/share/valt/etc/"

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
            # Include $out/bin for rayvn.up project root resolution.
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath recoverDeps}"

            wrapProgram "$out/bin/valt-pinentry" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath recoverDeps}"

            # For decoding the paper key QR code (see etc/key-doc-template.html).
            ln -s "${pkgs.qrtool}/bin/qrtool" "$out/bin/qrtool"

            runHook postInstall
          '';

          postFixup = ''
            for f in "$out/bin/.valt-wrapped" "$out/bin/.valt-pinentry-wrapped" "$out/share/valt/lib/"*.sh; do
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
          buildInputs = runtimeDeps ++ fonts ++ [
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
