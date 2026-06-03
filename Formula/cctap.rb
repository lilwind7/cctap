class Cctap < Formula
  desc "macOS notification bridge for Claude Code sessions"
  homepage "https://github.com/jcong830/cctap"
  url "https://github.com/jcong830/cctap/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_ON_RELEASE"
  license "MIT"
  head "https://github.com/jcong830/cctap.git", branch: "main"

  depends_on "jq"
  depends_on "terminal-notifier"

  def install
    libexec.install "lib"
    pkgshare.install "share/install"

    # Patch bin/cctap so PROJECT_ROOT/INSTALL_SHARE point at brew-managed paths.
    # Leaves LIB_DIR="$PROJECT_ROOT/lib" unchanged — that now correctly resolves
    # to #{libexec}/lib because libexec.install "lib" installs the directory.
    inreplace "bin/cctap" do |s|
      s.gsub! 'PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"',
              %Q(PROJECT_ROOT="#{libexec}"\nINSTALL_SHARE="#{pkgshare}/install")
      s.gsub! '"$PROJECT_ROOT/share/install/merge_hooks.sh"', '"$INSTALL_SHARE/merge_hooks.sh"'
    end

    bin.install "bin/cctap"
  end

  test do
    # Smoke: doctor returns 0 when deps are present, prints expected lines.
    output = shell_output("#{bin}/cctap doctor")
    assert_match "terminal-notifier", output
    assert_match "jq", output
  end
end
