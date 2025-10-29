class Xamrock < Formula
  desc "AI-powered mobile app testing from your terminal"
  homepage "https://github.com/Xamrock/CLI"
  url "https://github.com/Xamrock/CLI/archive/refs/tags/0.3.0.tar.gz"
  sha256 "" # You'll need to calculate this after creating the release
  license "MIT"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/XamrockCLI" => "xamrock"
  end

  test do
    assert_match "USAGE: xamrock", shell_output("#{bin}/xamrock --help")
  end
end
