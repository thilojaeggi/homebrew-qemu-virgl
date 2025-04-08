# Formula created by startergo on 2025-03-12 13:25:22 UTC
class Virglrenderer < Formula
  desc "VirGL virtual OpenGL renderer"
  
  head do
    url "https://github.com/akihikodaki/virglrenderer.git", branch: "macos"
  end

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "cmake" => :build
  depends_on "python@3.13" => :build
  depends_on "startergo/homebrew-qemu-virgl/libangle"
  depends_on "startergo/homebrew-qemu-virgl/libepoxy-angle"
  depends_on "spice-protocol"

  def install
    epoxy_formula = Formula["startergo/homebrew-qemu-virgl/libepoxy-angle"]
    epoxy_cellar = epoxy_formula.prefix.parent
    epoxy_version = epoxy_cellar.children.select(&:directory?).max
    epoxy_pc = "#{epoxy_version}/lib/pkgconfig"
    
    ENV["PKG_CONFIG_PATH"] = epoxy_pc

    system "meson", "setup", "build",
           "--prefix=#{prefix}",
           "--buildtype=release",
           "-Dc_args=-I#{Formula["startergo/homebrew-qemu-virgl/libangle"].opt_include} -I#{epoxy_formula.opt_include}",
           "-Dc_link_args=-L#{epoxy_formula.opt_lib}",
           "--pkg-config-path=#{epoxy_pc}"

    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    system "true"
  end
end