class Deno < Formula
  desc "Command-line JavaScript / TypeScript engine"
  homepage "https://deno.land/"
  url "https://github.com/denoland/deno/releases/download/v1.4.4/deno_src.tar.gz"
  sha256 "43e0a03c59065fe9fb1eeec98eb35d327897a3bb0f54c164513e90adeae0ecef"

  bottle do
    root_url "https://github.com/chrmoritz/homebrew-deno/releases/download/bottles"
    cellar :any_skip_relocation
    sha256 "a5a739024073396983c8972b87d5e28a6b9048bebec79a14973b158219d57ee7" => :x86_64_linux
  end

  depends_on "llvm" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "pypy" => :build
  depends_on "rust" => :build
  depends_on "xz" => :build
  depends_on "glib"

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
    ENV["DENO_BUILD_ARGS"] = "use_sysroot=false use_glib=false"
    ENV.remove "HOMEBREW_LIBRARY_PATHS", Formula["llvm"].opt_lib

    cd "cli" do
      system "cargo", "install", "-vv", "--locked", "--root", prefix, "--path", "."
    end

    # Install bash and zsh completion
    output = Utils.safe_popen_read("#{bin}/deno completions bash")
    (bash_completion/"deno").write output
    output = Utils.safe_popen_read("#{bin}/deno completions zsh")
    (zsh_completion/"_deno").write output
  end

  test do
    (testpath/"hello.ts").write <<~EOS
      console.log("hello", "deno");
    EOS
    hello = shell_output("#{bin}/deno run hello.ts")
    assert_includes hello, "hello deno"
    assert_match "console.log",
      shell_output("#{bin}/deno run --allow-read=#{testpath} https://deno.land/std@0.50.0/examples/cat.ts " \
                   "#{testpath}/hello.ts")
  end
end
