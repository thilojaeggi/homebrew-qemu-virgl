# Formula created by startergo on version 2025-03-13 03:43:41 UTC
class QemuVirgl < Formula
  desc "Emulator for x86 and PowerPC"
  homepage "https://www.qemu.org/"
  url "https://github.com/qemu/qemu.git", using: :git, revision: "ea35a5082a5fe81ce8fd184b0e163cd7b08b7ff7"
  version "2025.03.13"
  license "GPL-2.0-only"

  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.13" => :build

  depends_on "coreutils"
  depends_on "glib"
  depends_on "gnutls"
  depends_on "jpeg"
  depends_on "startergo/homebrew-qemu-virgl/libangle"
  depends_on "startergo/homebrew-qemu-virgl/libepoxy-angle"
  depends_on "startergo/homebrew-qemu-virgl/virglrenderer"
  depends_on "libpng"
  depends_on "libssh"
  depends_on "libusb"
  depends_on "lzo"
  depends_on "ncurses"
  depends_on "nettle"
  depends_on "pixman"
  depends_on "snappy"
  depends_on "spice-protocol"
  depends_on "vde"

  resource "tomli" do
    url "https://files.pythonhosted.org/packages/c0/3f/d7af728f075fb08564c5949a9c95e44352e23dee646869fa104a3b2060a3/tomli-2.0.1.tar.gz"
    sha256 "de526c12914f0c550d15924c62d72abc48d6fe7364aa87328337a31007fe8a4f"
  end

  resource "test-image" do
    url "https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/official/FD12FLOPPY.zip"
    sha256 "81237c7b42dc0ffc8b32a2f5734e3480a3f9a470c50c14a9c4576a2561a35807"
  end

  patch :p1 do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl/refs/heads/master/Patches/qemu-v06.diff"
    sha256 "61e9138e102a778099b96fb00cffce2ba65040c1f97f2316da3e7ef2d652034b"
  end

  def install
    ENV["LIBTOOL"] = "glibtool"
    python3 = Formula["python@3.13"].opt_bin/"python3.13"
    ENV["PYTHON"] = python3

    venv_path = buildpath/"venv"
    system python3, "-m", "venv", venv_path
    venv_python = venv_path/"bin/python"
    
    resource("tomli").stage do
      system venv_python, "-m", "pip", "install", "."
    end

    ENV["PYTHON"] = venv_python
    ENV.prepend_path "PYTHONPATH", venv_path/"lib/python3.13/site-packages"

    args = %W[
      --prefix=#{prefix}
      --cc=#{ENV.cc}
      --host-cc=#{ENV.cc}
      --enable-curses
      --enable-libssh
      --enable-vde
      --enable-virtfs
      --disable-sdl
      --disable-gtk
      --extra-cflags=-I#{Formula["startergo/homebrew-qemu-virgl/libangle"].opt_prefix}/include
      --extra-cflags=-I#{Formula["startergo/homebrew-qemu-virgl/libepoxy-angle"].opt_prefix}/include
      --extra-cflags=-I#{Formula["startergo/homebrew-qemu-virgl/virglrenderer"].opt_prefix}/include
      --extra-cflags=-march=armv8-a+crc+crypto
      --extra-ldflags=-L#{Formula["startergo/homebrew-qemu-virgl/libangle"].opt_prefix}/lib
      --extra-ldflags=-L#{Formula["startergo/homebrew-qemu-virgl/libepoxy-angle"].opt_prefix}/lib
      --extra-ldflags=-L#{Formula["startergo/homebrew-qemu-virgl/virglrenderer"].opt_prefix}/lib
    ]

    (bin/"qemu-wrapper").write <<~EOS
      #!/bin/bash
      set -e
      
      # Basic setup - use user's home directory to avoid permission issues
      QEMU_DIR="$HOME/.qemu-virgl"
      QEMU_LOG_DIR="$QEMU_DIR/logs"
      QEMU_CORE_DIR="$QEMU_DIR/cores"
      mkdir -p "$QEMU_LOG_DIR" "$QEMU_CORE_DIR"
      
      # Enable core dumps without changing system settings
      ulimit -c unlimited
      export QEMU_COREFILE="$QEMU_CORE_DIR/core.%e.%p"
      
      # Library paths - essential for operation
      LIBPATH="#{Formula["startergo/homebrew-qemu-virgl/libangle"].opt_lib}"
      LIBPATH="$LIBPATH:#{Formula["startergo/homebrew-qemu-virgl/libepoxy-angle"].opt_lib}"
      LIBPATH="$LIBPATH:#{Formula["startergo/homebrew-qemu-virgl/virglrenderer"].opt_lib}"
      export DYLD_FALLBACK_LIBRARY_PATH="$LIBPATH:$DYLD_FALLBACK_LIBRARY_PATH"
      
      # Basic ANGLE config
      export ANGLE_DEFAULT_PLATFORM=metal
      
      # Enable crash reporting
      export QEMU_DEBUG_CRASH=1
      
      # Verify and execute QEMU
      if [ -z "$1" ]; then
        echo "Error: No QEMU command specified"
        exit 1
      fi
      
      QEMU_CMD="#{bin}/$1"
      if [ ! -x "$QEMU_CMD" ]; then
        echo "Error: QEMU command not found: $QEMU_CMD"
        exit 1
      fi
      
      # Print diagnostic info
      echo "QEMU directories:"
      echo "  Logs: $QEMU_LOG_DIR"
      echo "  Cores: $QEMU_CORE_DIR"
      echo "Library path: $DYLD_FALLBACK_LIBRARY_PATH"
      
      shift
      exec "$QEMU_CMD" "$@"
    EOS

    chmod 0755, "#{bin}/qemu-wrapper"

    args << "--smbd=#{HOMEBREW_PREFIX}/sbin/samba-dot-org-smbd"
    args << "--enable-cocoa" if OS.mac?

    system "./configure", *args
    system "make", "V=1", "install"
  end

  test do
    expected = "QEMU Project"
    %w[
      aarch64 alpha arm cris hppa i386 m68k microblaze microblazeel
      mips mips64 mips64el mipsel nios2 or1k ppc ppc64 riscv32 riscv64
      rx s390x sh4 sh4eb sparc sparc64 tricore x86_64 xtensa xtensaeb
    ].each do |arch|
      assert_match expected, shell_output("#{bin}/qemu-system-#{arch} --version")
    end

    resource("test-image").stage testpath
    assert_match "file format: raw", shell_output("#{bin}/qemu-img info FLOPPY.img")

    system "#{bin}/qemu-wrapper", "qemu-system-aarch64", "-accel", "help"

    system "#{bin}/qemu-wrapper", "qemu-system-aarch64", \
           "-machine", "virt,accel=hvf", \
           "-cpu", "host", \
           "-display", "none", \
           "-m", "64"
  end
end