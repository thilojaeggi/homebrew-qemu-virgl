# Formula created by startergo on version 2025-03-13 02:17:39 UTC
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

  # Add tomli as a resource for Python build dependency
  resource "tomli" do
    url "https://files.pythonhosted.org/packages/c0/3f/d7af728f075fb08564c5949a9c95e44352e23dee646869fa104a3b2060a3/tomli-2.0.1.tar.gz"
    sha256 "de526c12914f0c550d15924c62d72abc48d6fe7364aa87328337a31007fe8a4f"
  end

  # 820KB floppy disk image file of FreeDOS 1.2, used to test QEMU
  resource "test-image" do
    url "https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/official/FD12FLOPPY.zip"
    sha256 "81237c7b42dc0ffc8b32a2f5734e3480a3f9a470c50c14a9c4576a2561a35807"
  end

  # waiting for upstreaming of https://github.com/akihikodaki/qemu/tree/macos
  patch :p1 do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl/refs/heads/master/Patches/qemu-v06.diff"
    sha256 "61e9138e102a778099b96fb00cffce2ba65040c1f97f2316da3e7ef2d652034b"
  end

  def install
    ENV["LIBTOOL"] = "glibtool"
    python3 = Formula["python@3.13"].opt_bin/"python3.13"
    ENV["PYTHON"] = python3

    # Create venv and install tomli
    venv_path = buildpath/"venv"
    system python3, "-m", "venv", venv_path
    venv_python = venv_path/"bin/python"
    
    resource("tomli").stage do
      system venv_python, "-m", "pip", "install", "."
    end

    # Set up environment to use venv
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
      # Explicitly disable GTK and GStreamer to prevent conflicts
      --disable-sdl
      --disable-gtk
      # Extra flags for includes and libraries
      --extra-cflags=-I#{Formula["startergo/homebrew-qemu-virgl/libangle"].opt_prefix}/include
      --extra-cflags=-I#{Formula["startergo/homebrew-qemu-virgl/libepoxy-angle"].opt_prefix}/include
      --extra-cflags=-I#{Formula["startergo/homebrew-qemu-virgl/virglrenderer"].opt_prefix}/include
      --extra-cflags=-march=armv8-a+crc+crypto
      --extra-ldflags=-L#{Formula["startergo/homebrew-qemu-virgl/libangle"].opt_prefix}/lib
      --extra-ldflags=-L#{Formula["startergo/homebrew-qemu-virgl/libepoxy-angle"].opt_prefix}/lib
      --extra-ldflags=-L#{Formula["startergo/homebrew-qemu-virgl/virglrenderer"].opt_prefix}/lib
    ]

    # Update wrapper script with proper indentation and formatting
    (bin/"qemu-wrapper").write <<~EOS
      #!/bin/bash
      
      # Enable core dumps with specific location
      ulimit -c unlimited
      export QEMU_CORE_PATTERN="/tmp/qemu-core-%e-%p-%t"
      
      # ANGLE specific debug flags with error logging
      export ANGLE_CAPTURE_ENABLED=1
      export ANGLE_CAPTURE_FRAME_START=1
      export ANGLE_CAPTURE_FRAME_END=1
      export ANGLE_DEBUG=1
      export ANGLE_TRACE=1
      export ANGLE_LOG_LEVEL=debug
      export ANGLE_BACKEND_LOG_LEVEL=debug
      
      # Enhanced crash debugging with specific paths
      export MallocStackLogging=1
      export MallocStackLoggingNoCompact=1
      export MallocScribble=1
      export MallocPreScribble=1
      export MallocStackLoggingDirectory="/tmp/qemu-malloc-logs"
      
      # Create logging directory
      mkdir -p "$MallocStackLoggingDirectory"
      
      # Set comprehensive debug flags
      export DYLD_PRINT_LIBRARIES=1
      export DYLD_PRINT_BINDINGS=1
      export DYLD_PRINT_INITIALIZERS=1
      export DYLD_PRINT_SEGMENTS=1
      export DYLD_PRINT_APIS=1
      
      # Library paths with validation
      LIBPATH="#{Formula["startergo/homebrew-qemu-virgl/libangle"].opt_lib}"
      LIBPATH="$LIBPATH:#{Formula["startergo/homebrew-qemu-virgl/libepoxy-angle"].opt_lib}"
      LIBPATH="$LIBPATH:#{Formula["startergo/homebrew-qemu-virgl/virglrenderer"].opt_lib}"
      
      # Verify libraries exist
      for lib in $(echo $LIBPATH | tr ':' ' '); do
        if [ ! -d "$lib" ]; then
          echo "Error: Library path does not exist: $lib" >&2
          exit 1
        fi
      done
      
      export DYLD_FALLBACK_LIBRARY_PATH="$LIBPATH:$DYLD_FALLBACK_LIBRARY_PATH"
      export ANGLE_DEFAULT_PLATFORM=metal
      
      # Log both stdout and stderr with timestamps
      LOG_FILE="/tmp/qemu-debug-$(date +%Y%m%d-%H%M%S).log"
      CRASH_FILE="/tmp/qemu-crash-$(date +%Y%m%d-%H%M%S).log"
      
      # Run with enhanced crash handler
      (
        # Redirect output with line buffering
        "#{Formula["coreutils"].opt_bin}/stdbuf" -oL -eL \\
        exec 1> >(while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') [OUT] $line"; done >> "$LOG_FILE")
        exec 2> >(while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') [ERR] $line"; done >> "$LOG_FILE")
        
        echo "=== Starting QEMU wrapper at $(date '+%Y-%m-%d %H:%M:%S') ===" >&2
        echo "Library path: $DYLD_FALLBACK_LIBRARY_PATH" >&2
        echo "Command: #{bin}/$1 ${@:2}" >&2
        echo "Core dumps enabled: $(ulimit -c)" >&2
        echo "Process ID: $$" >&2
        echo "ANGLE platform: $ANGLE_DEFAULT_PLATFORM" >&2
        
        # Run QEMU with debug info and trap errors
        set -x
        trap 'echo "Exit code: $?" >&2' EXIT
        "#{bin}/$1" "${@:2}"
      ) 2> >(tee -a "$CRASH_FILE")
    EOS

    chmod 0755, "#{bin}/qemu-wrapper"

    # Sharing Samba directories in QEMU requires the samba.org smbd which is
    # incompatible with the macOS-provided version. This will lead to
    # silent runtime failures, so we set it to a Homebrew path in order to
    # obtain sensible runtime errors. This will also be compatible with
    # Samba installations from external taps.
    args << "--smbd=#{HOMEBREW_PREFIX}/sbin/samba-dot-org-smbd"
    
    args << "--enable-cocoa" if OS.mac?

    system "./configure", *args
    system "make", "V=1", "install"
  end

  test do
    expected = "QEMU Project"
    # Test system emulators
    %w[
      aarch64 alpha arm cris hppa i386 m68k microblaze microblazeel
      mips mips64 mips64el mipsel nios2 or1k ppc ppc64 riscv32 riscv64
      rx s390x sh4 sh4eb sparc sparc64 tricore x86_64 xtensa xtensaeb
    ].each do |arch|
      assert_match expected, shell_output("#{bin}/qemu-system-#{arch} --version")
    end

    # Test disk image handling
    resource("test-image").stage testpath
    assert_match "file format: raw", shell_output("#{bin}/qemu-img info FLOPPY.img")

    # Test accelerator functionality
    system "#{bin}/qemu-wrapper", "qemu-system-aarch64", "-accel", "help"

    # Test HVF acceleration with minimum configuration
    system "#{bin}/qemu-wrapper", "qemu-system-aarch64", \
           "-machine", "virt,accel=hvf", \
           "-cpu", "host", \
           "-display", "none", \
           "-m", "64"
  end
end