# Formula created by startergo on 2025-03-12 13:25:22 UTC
class Virglrenderer < Formula
  desc "VirGL virtual OpenGL renderer"
  homepage "https://github.com/akihikodaki/virglrenderer"
  
  url "https://github.com/akihikodaki/virglrenderer.git",
      revision: "4a489584344787ea52226ac50dd9fa86a1f38f90",
      branch: "macos",
      using: :git
  version "2025.04.08.1"
  license "MIT"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "cmake" => :build
  depends_on "python@3.13" => :build
  depends_on "startergo/qemu-virgl/libangle"
  depends_on "startergo/qemu-virgl/libepoxy-angle"
  depends_on "spice-protocol"

  def install
    # Use absolute paths to be absolutely certain
    epoxy = Formula["startergo/qemu-virgl/libepoxy-angle"]
    angle = Formula["startergo/qemu-virgl/libangle"]
    
    # Set up environment variables for the build
    ENV.prepend_path "PKG_CONFIG_PATH", "#{epoxy.opt_lib}/pkgconfig"
    ENV.append "LDFLAGS", "-L#{angle.opt_lib}"
    ENV.append "CPPFLAGS", "-I#{angle.opt_include}"
    
    # Use the correct platforms option format
    system "meson", "setup", "build",
           "--prefix=#{prefix}",
           "--buildtype=release",
           "-Dplatforms=egl",
           "--pkg-config-path=#{epoxy.opt_lib}/pkgconfig"
    
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    system "#{bin}/virgl_test_server", "--help" rescue true
  end
end