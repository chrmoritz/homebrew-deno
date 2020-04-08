class Deno < Formula
  desc "Command-line JavaScript / TypeScript engine"
  homepage "https://deno.land/"
  url "https://github.com/denoland/deno/releases/download/v0.39.0/deno_src.tar.gz"
  sha256 "d2ed15722d7e114870979709bf1606e0da42ba5a3972c5838540b94909414efc"
  
  bottle do
    cellar :any_skip_relocation
    root_url "https://github.com/chrmoritz/homebrew-deno/releases/download/0.39.0/"
    sha256 "7d107670ff8c8022322dec70f44277fd86b60ab3603f5c2239e6072be38f2b7a" => :x86_64_linux
  end

  depends_on "llvm" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "pypy" => :build
  depends_on "rust" => :build
  depends_on "xz" => :build
  depends_on "glib"

  # Use older revision on Linux, newer does not work.
  resource "gn" do
    url "https://gn.googlesource.com/gn.git",
      :revision => "fd3d768bcfd44a8d9639fe278581bd9851d0ce3a"
  end

  def install
    # build gn with llvm clang too (g++ is too old)
    ENV["CXX"] = Formula["llvm"].opt_bin/"clang++"
    # use pypy for Python 2 build scripts
    ENV["PYTHON"] = Formula["pypy"].opt_bin/"pypy"
    mkdir "pypyshim" do
      ln_s Formula["pypy"].opt_bin/"pypy", "python"
      ln_s Formula["pypy"].opt_bin/"pypy", "python2"
    end
    ENV.prepend_path "PATH", buildpath/"pypyshim"

    # build rusty_v8 from source
    ENV["V8_FROM_SOURCE"] = "1"
    # overwrite Chromium minimum sdk version of 10.15
    ENV["FORCE_MAC_SDK_MIN"] = "10.13"
    # build with llvm and link against system libc++ (no runtime dep)
    ENV["CLANG_BASE_PATH"] = Formula["llvm"].prefix
    ENV.remove "HOMEBREW_LIBRARY_PATHS", Formula["llvm"].opt_lib

    cd "cli" do
      system "cargo", "install", "-vv", "--locked", "--root", prefix, "--path", "."
    end

    # Install bash and zsh completion
    output = Utils.popen_read("#{bin}/deno completions bash")
    (bash_completion/"deno").write output
    output = Utils.popen_read("#{bin}/deno completions zsh")
    (zsh_completion/"_deno").write output
  end

  test do
    (testpath/"hello.ts").write <<~EOS
      console.log("hello", "deno");
    EOS
    hello = shell_output("#{bin}/deno run hello.ts")
    assert_includes hello, "hello deno"
    cat = shell_output("#{bin}/deno run --allow-read=#{testpath} https://deno.land/std/examples/cat.ts #{testpath}/hello.ts")
    assert_includes cat, "console.log"
  end
end
