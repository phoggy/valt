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
  end

  test do
    system "#{bin}/valt", "--version"
  end
end
