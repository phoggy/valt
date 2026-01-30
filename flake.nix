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
            hash = "sha256-0GlCSXalb6lheUW/MH2dM0LcAh4lrxvzo81NQ+ELUJY=";
          };
          cargoHash = "sha256-8IKe8Ps//m3yvG5EQjA/DadZ9mdmuoW7MA6DgMMLrdU=";
          meta = with pkgs.lib; {
            description = "Password strength evaluator";
            homepage = "https://github.com/phoggy/mrld";
            license = licenses.gpl3Only;
          };
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

            # Wrap valt with runtime dependencies on PATH and font config.
            # Include $out/bin so rayvn.up can find 'rayvn.up' and 'valt' via
            # PATH lookup for project root resolution.
            # Note: Puppeteer/npm install happens at runtime in ~/.config/valt/node-js/
            # via pdf.sh's _init_valt_pdf — nodejs (with npm) is on PATH for this.
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}" \
              --set FONTCONFIG_FILE "${pkgs.makeFontsConf { fontDirectories = fonts; }}"

            # Wrap valt-pinentry similarly
            wrapProgram "$out/bin/valt-pinentry" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}"

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

            # Wrap with minimal deps for recovery.
            # Include $out/bin for rayvn.up project root resolution.
            wrapProgram "$out/bin/valt" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath [ pkgs.bash rayvnPkg pkgs.rage ]}"

            wrapProgram "$out/bin/valt-pinentry" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath [ pkgs.bash rayvnPkg ]}"

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
