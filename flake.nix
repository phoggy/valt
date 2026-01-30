{
  description = "valt - Public key file encryption";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rayvn.url = "github:phoggy/rayvn";
  };

  outputs = { self, nixpkgs, flake-utils, rayvn }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        rayvnPkg = rayvn.packages.${system}.default;

        # Build mrld from source (not in nixpkgs)
        mrld = pkgs.rustPlatform.buildRustPackage rec {
          pname = "mrld";
          version = "0.1.0";
          src = pkgs.fetchFromGitHub {
            owner = "phoggy";
            repo = "mrld";
            rev = "v${version}";
            hash = pkgs.lib.fakeHash;
          };
          cargoHash = pkgs.lib.fakeHash;
          meta = with pkgs.lib; {
            description = "Password strength evaluator";
            homepage = "https://github.com/phoggy/mrld";
            license = licenses.gpl3Only;
          };
        };

        # Pre-build Puppeteer node_modules to avoid runtime npm install
        puppeteerNodeModules = pkgs.buildNpmPackage {
          pname = "valt-puppeteer";
          version = "1.0.0";

          # Create a minimal package.json for puppeteer
          src = pkgs.writeTextDir "package.json" (builtins.toJSON {
            name = "valt-puppeteer";
            version = "1.0.0";
            dependencies = {
              puppeteer = "*";
            };
          });

          npmDepsHash = pkgs.lib.fakeHash;
          dontNpmBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/lib
            cp -r node_modules $out/lib/node_modules
            runHook postInstall
          '';
        };

        # Runtime dependencies
        runtimeDeps = [
          pkgs.bash
          rayvnPkg
          pkgs.rage
          pkgs.phraze
          mrld
          pkgs.curl
          pkgs.nodejs
          pkgs.qrencode
          pkgs.exiftool
          pkgs.qpdf
        ];

        # Fonts for PDF generation
        fonts = [
          pkgs.google-fonts  # Includes Indie Flower and Fira Code
        ];

        valt = pkgs.stdenv.mkDerivation {
          pname = "valt";
          version = "0.1.0";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/valt "$out/bin/valt"
            install -Dm755 bin/valt-pinentry "$out/bin/valt-pinentry"

            # Install lib/
            mkdir -p "$out/lib"
            cp lib/*.sh "$out/lib/"

            # Install etc/
            mkdir -p "$out/etc"
            cp -r etc/* "$out/etc/"

            # Install rayvn.pkg
            cp rayvn.pkg "$out/"

            # Set up pre-built Puppeteer node_modules
            mkdir -p "$out/share/valt/node-js"
            cp "$out/etc/generate-pdf.js" "$out/share/valt/node-js/"
            ln -s "${puppeteerNodeModules}/lib/node_modules" "$out/share/valt/node-js/node_modules"

            # Wrap valt with runtime dependencies on PATH and font config
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}" \
              --set FONTCONFIG_FILE "${pkgs.makeFontsConf { fontDirectories = fonts; }}" \
              --set VALT_NIX_NODE_JS_HOME "$out/share/valt/node-js"

            # Wrap valt-pinentry similarly
            wrapProgram "$out/bin/valt-pinentry" \
              --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Public key file encryption using rage/age";
            homepage = "https://github.com/phoggy/valt";
            license = licenses.gpl3Only;
            platforms = platforms.unix;
          };
        };

        # Minimal recovery package with just decryption deps
        valtRecover = pkgs.stdenv.mkDerivation {
          pname = "valt-recover";
          version = "0.1.0";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install only what's needed for decryption
            install -Dm755 bin/valt "$out/bin/valt"
            install -Dm755 bin/valt-pinentry "$out/bin/valt-pinentry"

            mkdir -p "$out/lib"
            cp lib/*.sh "$out/lib/"

            mkdir -p "$out/etc"
            cp etc/decrypt "$out/etc/"

            cp rayvn.pkg "$out/"

            # Wrap with minimal deps for recovery
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.bash rayvnPkg pkgs.rage ]}"

            wrapProgram "$out/bin/valt-pinentry" \
              --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.bash rayvnPkg ]}"

            runHook postInstall
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
        };

        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ fonts ++ [
            pkgs.shellcheck
          ];
          shellHook = ''
            export PATH="${self}/bin:$PATH"
            echo "valt dev shell ready"
          '';
        };
      }
    );
}
