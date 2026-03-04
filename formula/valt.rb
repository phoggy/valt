class Valt < Formula
  desc "Public key file encryption using rage/age"
  homepage "https://github.com/phoggy/valt"
  url "{URL}"
  sha256 "{SHA256}"
  license "GPL-3.0-only"

{DEPENDS_ON}

  def install
    bin.install "bin/valt"
    bin.install "bin/valt-pinentry"
    (share/"valt"/"lib").install Dir["lib/*.sh"]
    (share/"valt"/"etc").install Dir["etc/*"]
    (share/"valt").install "rayvn.pkg"

    # Install puppeteer + its bundled Chromium directly into ~/.config/valt/node-js/.
    node_js_dir = Pathname.new(Dir.home)/".config"/"valt"/"node-js"
    node_js_dir.mkpath
    (node_js_dir/"package.json").write((buildpath/"etc/package.json").read)
    (node_js_dir/"package-lock.json").write((buildpath/"etc/package-lock.json").read)
    Dir.chdir(node_js_dir) do
      system "npm", "ci", "--production"
    end
  end

  test do
    system "#{bin}/valt", "--version"
  end
end
