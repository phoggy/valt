class Valt < Formula
  desc "Public key encryption for files and archives, using age and minisign"
  homepage "https://github.com/phoggy/valt"
  url "{URL}"
  sha256 "{SHA256}"
  license "GPL-3.0-only"

{DEPENDS_ON}

  def install
    bin.install "bin/valt"
    (share/"valt"/"lib").install Dir["lib/*.sh"]
    (share/"valt"/"etc").install Dir["etc/*"]
    (share/"valt").install "rayvn.pkg"
    bash_completion.install "completions/valt.bash" => "valt"
    zsh_completion.install "completions/valt.zsh" => "_valt"
  end

  test do
    system "#{bin}/valt", "--version"
  end
end
