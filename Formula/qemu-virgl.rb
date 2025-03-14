# Formula created by startergo on version 2025-03-14 02:01:29 UTC
class QemuVirgl < Formula
  desc "Emulator for x86 and PowerPC with macOS-specific optimizations"
  homepage "https://www.qemu.org/"
  
  # Using akihikodaki's macos branch directly instead of patching
  url "https://github.com/akihikodaki/qemu.git", branch: "macos"
  version "2025.03.14"
  license "GPL-2.0-only"

  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.13" => :build

  depends_on "coreutils"
  depends_on "dtc"
  depends_on "glib"
  depends_on "gnutls"
  depends_on "jpeg"
  depends_on "startergo/qemu-virgl/libangle"
  depends_on "startergo/qemu-virgl/libepoxy-angle"
  depends_on "startergo/qemu-virgl/virglrenderer"
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

    # Define arguments without comments that were causing build failures
    args = [
      "--prefix=#{prefix}",
      "--cc=#{ENV.cc}",
      "--host-cc=#{ENV.cc}",
      "--disable-bsd-user",
      "--disable-guest-agent",
      "--disable-sdl",
      "--disable-gtk",
      "--enable-debug",
      "--enable-debug-info",
      "--enable-trace-backends=log,simple",
      "--enable-malloc=system",
      "--enable-fdt=system",
      "--extra-cflags=-I#{Formula["libangle"].opt_prefix}/include",
      "--extra-cflags=-I#{Formula["libepoxy-angle"].opt_prefix}/include",
      "--extra-cflags=-I#{Formula["virglrenderer"].opt_prefix}/include",
      "--extra-cflags=-I#{Formula["spice-protocol"].opt_prefix}/include/spice-1",
      "--extra-cflags=-DNCURSES_WIDECHAR=1",
      "--extra-ldflags=-L#{Formula["libangle"].opt_prefix}/lib",
      "--extra-ldflags=-L#{Formula["libepoxy-angle"].opt_prefix}/lib",
      "--extra-ldflags=-L#{Formula["virglrenderer"].opt_prefix}/lib"
    ]
    
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

    # Test standard VM
    system "#{bin}/qemu-wrapper", "qemu-system-aarch64", \
           "-machine", "virt,accel=hvf", \
           "-cpu", "host", \
           "-display", "none", \
           "-m", "64"

    # Test coroutine debugging
    system "#{bin}/qemu-wrapper", "qemu-system-aarch64", \
           "-machine", "virt", \
           "-cpu", "cortex-a72", \
           "-display", "none", \
           "-m", "64"
  end
end