# 3D accelerated qemu on MacOS

![ubuntu](https://user-images.githubusercontent.com/6728841/111193747-90da1a00-85cb-11eb-9517-36c1a19c19be.gif)

## What is it for

If you own a Mac (x86 or ARM) and want to have a full Linux desktop for development or testing, you'll find that having a responsive desktop is a nice thing. The graphical acceleration is possible thanks to [the work](https://gist.github.com/akihikodaki/87df4149e7ca87f18dc56807ec5a1bc5) of [Akihiko Odaki](https://github.com/akihikodaki). I've only packaged it into an easily-installable brew repository while the changes are not yet merged into upstream.

Features:

- Support for both ARM and X86 acceleration with Hypervisor.framework (works without root or kernel extensions)
- Support for OpenGL acceleration in the guest (both X11 and Wayland)
- Works on large screens (5k+)
- Dynamically changing guest resolution on window resize
- Properly handle sound output when plugging/unplugging headphones

## Installation

### Prerequisites

1. **Xcode**:
   ```sh
   # Install Xcode from the Mac App Store
   # After installation, open Xcode to accept the license agreement
   sudo xcodebuild -license accept
   ```
   Note: The Command Line Tools alone are not sufficient; full Xcode is required for building QEMU and its dependencies.

2. **Homebrew**:
   If you haven't installed Homebrew yet:
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

### Installation Steps

1. Add the tap and install QEMU with GPU acceleration:
   ```sh
   brew tap startergo/qemu-virgl
   brew install qemu-virgl
   ```

   Or install it directly:
   ```sh
   brew install startergo/qemu-virgl/qemu-virgl
   ```

The formula will automatically install all required dependencies including:
- libangle (Apple's Metal backend for OpenGL)
- libepoxy-angle (OpenGL dispatch library)
- virglrenderer (OpenGL virtualization library)

Note: The first installation might take some time (15-30 minutes) as it builds several components. Subsequent updates will be faster as they use pre-built bottles.

### Verifying Installation

To verify the installation was successful:
```sh
qemu-system-x86_64 --version  # Should show QEMU version
virgl_test_server_android    # Should be available if virglrenderer installed correctly
```

### Troubleshooting

If you encounter installation issues:

1. Ensure Xcode is properly installed:
   ```sh
   xcode-select -p  # Should point to full Xcode path, not Command Line Tools
   ```

2. Check Homebrew's health:
   ```sh
   brew doctor
   brew update && brew upgrade
   ```

3. Try a verbose installation:
   ```sh
   HOMEBREW_NO_AUTO_UPDATE=1 brew install -v qemu-virgl
   ```

4. If you see build errors, try cleaning and retrying:
   ```sh
   brew cleanup
   brew uninstall qemu-virgl
   brew install qemu-virgl
   ```