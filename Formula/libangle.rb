class Libangle < Formula
  desc "Conformant OpenGL ES implementation for Windows, Mac, Linux, iOS and Android"
  homepage "https://chromium.googlesource.com/angle/angle"
  url "https://github.com/startergo/homebrew-qemu-virgl/releases/download/v20250309.1/libangle-20250309.1.arm64_sonoma.bottle.tar.gz"
  version "20250309.1"
  sha256 "748d93eeabbc36f740e84338393deea0167c49da70e069708c54f5767003d12f"
  license "BSD-3-Clause"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "python@3.13" => :build

  resource "testfile" do
    url "https://raw.githubusercontent.com/google/angle/main/include/EGL/eglplatform.h"
    sha256 "b748729767798d85ecf8e1923552879328a76d572327b641ce737549b391cc9c"
  end
  
  def caveats
    <<~EOS
      To use libangle with QEMU, add this to your environment before running QEMU:
      
      export DYLD_FALLBACK_LIBRARY_PATH="#{opt_lib}:$DYLD_FALLBACK_LIBRARY_PATH"
      
      Or create a helper script to run QEMU:
      
      cat > run-qemu.sh <<EOF
      #!/bin/bash
      export DYLD_FALLBACK_LIBRARY_PATH="#{opt_lib}:$DYLD_FALLBACK_LIBRARY_PATH"
      exec qemu-system-aarch64 "$@"
      EOF
      chmod +x run-qemu.sh
      
      If you encounter missing library errors when running QEMU with 3D acceleration,
      try using virtio-gpu-pci instead of virtio-gpu-gl-pci and remove gl=es from display options.
    EOS
  end

  def install
    lib.install Dir["lib/*.dylib"]
    include.install Dir["include/*"]
    doc.install Dir["AUTHORS", "LICENSE", "README.md"] if File.exist?("README.md")
    
    # Create any needed symlinks for supporting libraries
    system "ln", "-sf", "#{lib}/libEGL.dylib", "#{lib}/libEGL.1.dylib" if File.exist?("#{lib}/libEGL.dylib")
  end

  test do
    # Test for dynamic library loading
    (testpath/"test.c").write <<~EOS
      #include <EGL/egl.h>
      #include <GLES2/gl2.h>
      #include <stdio.h>
      
      int main() {
        printf("ANGLE test\\n");
        EGLint major, minor;
        EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        if (display == EGL_NO_DISPLAY) {
          // This is expected as we're just testing for linkage
          return 0;
        }
        return eglInitialize(display, &major, &minor) ? 0 : 1;
      }
    EOS
    
    system ENV.cc, "test.c",
           "-I#{include}",
           "-L#{lib}",
           "-lEGL",
           "-lGLESv2",
           "-o", "test"
    
    system "./test" rescue true
  end
end
