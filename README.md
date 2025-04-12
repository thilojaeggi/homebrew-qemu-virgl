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
   
#### Install Xcode from the Mac App Store
#### After installation, open Xcode to accept the license agreement

```sh  
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
brew install startergo/qemu-virgl/libangle
brew install startergo/qemu-virgl/libepoxy-angle
brew install startergo/qemu-virgl/virglrenderer
brew install startergo/qemu-virgl/qemu-virgl
```

> ℹ️ **Note**: You can install everything at once using `brew install startergo/qemu-virgl/qemu-virgl`,
> but installing components separately as shown above can help isolate any potential issues.

The formula will automatically install all required dependencies including:
- libangle (Apple's Metal backend for OpenGL)
- libepoxy-angle (OpenGL dispatch library)
- virglrenderer (OpenGL virtualization library)

Note: The first installation might take some time (15-30 minutes) as it builds several components. Subsequent updates will be faster as they use pre-built bottles.

### Verifying Installation

To verify the installation was successful:

#### Verify QEMU installation
```sh
qemu-system-aarch64 --version  # Should show QEMU version
```

#### Verify virglrenderer installation:
```sh   
which virgl_test_server       
```
Should show /opt/homebrew/bin/virgl_test_server

### Usage
Qemu has many command line options and emulated devices, with specific configurations based on your CPU type (Intel/Apple Silicon).

For the best experience, maximize the qemu window when it starts. To release the mouse, press Ctrl-Alt-g.

### Usage - Apple Silicon Macs

Important: Use `virtio-gpu-gl-pci` command line option instead of `virtio-gpu-pci` for GPU acceleration

First, create a disk image you'll run your Linux installation from (tune image size as needed):

```sh
qemu-img create hdd.raw 64G
```

This command creates a raw disk image named `hdd.raw` with a size of 64 GB. You can adjust the size as needed.

Download an ARM based Fedora image:

```sh
curl -LO https://dl01.fedoraproject.org/pub/fedora/linux/releases/41/Silverblue/aarch64/iso/Fedora-Silverblue-ostree-aarch64-41-1.4.iso
```
Copy the firmware:

```sh
cp $(dirname $(which qemu-img))/../share/qemu/edk2-aarch64-code.fd .
cp $(dirname $(which qemu-img))/../share/qemu/edk2-arm-vars.fd .
```

First, create a helper script to handle environment variables correctly:

```sh
cat > run-qemu.sh <<EOF
#!/bin/bash
exec sudo DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/opt/libangle/lib:\$DYLD_FALLBACK_LIBRARY_PATH" \\
qemu-system-aarch64 "\$@"
EOF
chmod +x run-qemu.sh
```

#### Verify that OpenGL acceleration is working
```
./run-qemu.sh \
  -machine virt,accel=hvf \
  -cpu cortex-a72 -smp 2 -m 1G \
  -device virtio-gpu-gl-pci \
  -display cocoa,gl=es \
  -nodefaults \
  -device VGA,vgamem_mb=64 \
  -monitor stdio
```
When the QEMU monitor appears (shown by the (qemu) prompt), type `info qtree`. The `qtree` output clearly shows that `virtio-gpu-gl-pci` and `virtio-gpu-gl-device` are properly configured in the VM, confirming that your OpenGL acceleration is working correctly through the ANGLE/Metal path. Type quit to exit QEMU.

Install the system from the ISO image:

```sh
./run-qemu.sh \
  -machine virt,accel=hvf \
  -cpu cortex-a72 -smp 2 -m 4G \
  -device intel-hda -device hda-output \
  -device qemu-xhci \
  -device virtio-gpu-gl-pci \
  -device usb-kbd \
  -device virtio-net-pci,netdev=net \
  -device virtio-mouse-pci \
  -display cocoa,gl=es \
  -netdev vmnet-shared,id=net \
  -drive "if=pflash,format=raw,file=./edk2-aarch64-code.fd,readonly=on" \
  -drive "if=pflash,format=raw,file=./edk2-arm-vars.fd,discard=on" \
  -drive "if=virtio,format=raw,file=./hdd.raw,discard=on" \
  -chardev qemu-vdagent,id=spice,name=vdagent,clipboard=on \
  -device virtio-serial-pci \
  -device virtserialport,chardev=spice,name=com.redhat.spice.0 \
  -cdrom Fedora-Silverblue-ostree-aarch64-41-1.4.iso \
  -boot d 
```
This command will start a QEMU virtual machine with the following options:
- `-machine virt,accel=hvf`: Use the virt machine type with Hypervisor.framework acceleration.
- `-cpu cortex-a72`: Use the Cortex-A72 CPU model.
- `-smp 2`: Allocate 2 CPU cores.
- `-m 4G`: Allocate 4 GB of RAM.
- `-device intel-hda -device hda-output`: Use Intel HDA sound device.
- `-device qemu-xhci`: Use QEMU's XHCI USB controller.
- `-device virtio-gpu-gl-pci`: Use the VirtIO GPU with OpenGL acceleration.
- `-device usb-kbd`: Use a USB keyboard device.
- `-device virtio-net-pci,netdev=net`: Use the VirtIO network device.
- `-device virtio-mouse-pci`: Use the VirtIO mouse device.
- `-display cocoa,gl=es`: Use the Cocoa display backend for macOS with OpenGL ES.
- `-netdev vmnet-shared,id=net`: Use shared networking with vmnet.
- `-drive "if=pflash,format=raw,file=./edk2-aarch64-code.fd,readonly=on"`: Use the QEMU EFI firmware as a read-only drive.
- `-drive "if=pflash,format=raw,file=./edk2-arm-vars.fd,discard=on"`: Use the QEMU EFI variables as a discardable drive.
- `-drive "if=virtio,format=raw,file=./hdd.raw,discard=on"`: Use the created disk image as a discardable virtual hard drive.
- `-chardev qemu-vdagent,id=spice,name=vdagent,clipboard=on`: Creates a SPICE agent character device with clipboard sharing enabled
- `device virtio-serial-pci`: Adds a virtio-serial PCI controller for communication
- `-device virtserialport,chardev=spice,name=com.redhat.spice.0`: Connects the SPICE agent to the virtio-serial bus. Note: Inside your Linux guest, you'll need to install the SPICE guest agent if not installed by default.
- `-cdrom Fedora-Silverblue-ostree-aarch64-41-1.4.iso`: Use the Fedora ARM ISO as a CD-ROM.
- `-boot d`: Boot from the CD-ROM.

Run the system without the CD image to boot into the primary partition:
```sh
./run-qemu.sh \
  -machine virt,accel=hvf \
  -cpu cortex-a72 -smp 2 -m 4G \
  -device intel-hda -device hda-output \
  -device qemu-xhci \
  -device virtio-gpu-gl-pci \
  -device usb-kbd \
  -device virtio-net-pci,netdev=net \
  -device virtio-mouse-pci \
  -display cocoa,gl=es \
  -netdev vmnet-shared,id=net \
  -drive "if=pflash,format=raw,file=./edk2-aarch64-code.fd,readonly=on" \
  -drive "if=pflash,format=raw,file=./edk2-arm-vars.fd,discard=on" \
  -drive "if=virtio,format=raw,file=./hdd.raw,discard=on" \
  -chardev qemu-vdagent,id=spice,name=vdagent,clipboard=on \
  -device virtio-serial-pci \
  -device virtserialport,chardev=spice,name=com.redhat.spice.0
```
This command is similar to the previous one but without the `-cdrom` and `-boot d` options, allowing you to boot directly from the installed system on the disk image.

### Usage - Intel Macs
Important: Use virtio-gpu-gl-pci command line option instead of virtio-gpu-pci for GPU acceleration
First, create a disk image you'll run your Linux installation from (tune image size as needed):

```sh
qemu-img create hdd.raw 64G
```
Download an x86 based Fedora image:

```sh
curl -LO https://download.fedoraproject.org/pub/fedora/linux/releases/40/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-40-1.2.iso
```
Copy the firmware:

```sh
cp $(dirname $(which qemu-img))/../share/qemu/edk2-x86_64-code.fd .
cp $(dirname $(which qemu-img))/../share/qemu/edk2-vars.fd .
```
First, create a helper script to handle environment variables correctly:

```sh
cat > run-qemu-x86.sh <<EOF
#!/bin/bash
exec sudo DYLD_FALLBACK_LIBRARY_PATH="/usr/local/opt/libangle/lib:\$DYLD_FALLBACK_LIBRARY_PATH" \\
qemu-system-x86_64 "\$@"
EOF
chmod +x run-qemu-x86.sh
```
Install the system from the ISO image:
```sh
./run-qemu-x86.sh \
  -M q35 \
  -cpu host \
  -smp 4 \
  -m 8G \
  -bios ./edk2-x86_64-code.fd \
  -drive file=hdd.raw,if=virtio,format=raw \
  -netdev vmnet-shared,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -vga virtio-gpu-gl-pci \
  -display cocoa,gl=es \
  -usb -device usb-tablet \
  -cdrom Fedora-Workstation-Live-x86_64-40-1.2.iso \
  -boot d \
  -chardev qemu-vdagent,id=spice,name=vdagent,clipboard=on \
  -device virtio-serial-pci \
  -device virtserialport,chardev=spice,name=com.redhat.spice.0
```
This command will start a QEMU virtual machine with the following options:
- `-M q35`: Use the Q35 machine type.
- `-cpu host`: Use the host CPU model.
- `-smp 4`: Allocate 4 CPU cores.
- `-m 8G`: Allocate 8 GB of RAM.
- `-bios ./edk2-x86_64-code.fd`: Use the QEMU EFI firmware.
- `-drive file=hdd.raw,if=virtio,format=raw`: Use the created disk image as a virtual hard drive.
- `-netdev vmnet-shared,id=net0`: Use shared networking with vmnet.
- `-device virtio-net-pci,netdev=net0`: Use the VirtIO network device.
- `-vga virtio-gpu-gl-pci`: Use the VirtIO GPU with OpenGL acceleration.
- `-display cocoa,gl=es`: Use the Cocoa display backend for macOS with OpenGL ES.
- `-usb -device usb-tablet`: Use a USB tablet device for better mouse handling.
- `-chardev qemu-vdagent,id=spice,name=vdagent,clipboard=on`: Enable clipboard sharing with the host.
- `-device virtio-serial-pci`: Use the VirtIO serial device.
- `-device virtserialport,chardev=spice,name=com.redhat.spice.0`: Use the VirtIO serial port for SPICE.

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

### Common Issues

1. **Missing libEGL.dylib error**:
   If you see: "Couldn't open libEGL.dylib", your environment variables aren't correctly passed to QEMU. Make sure you're using the script method above that correctly sets `DYLD_FALLBACK_LIBRARY_PATH`.

2. **Network Issues**:
   - If running with vmnet-shared fails, make sure your user has proper permissions
   - You might need to grant permissions in System Settings > Privacy & Security > Network

3. **For Best Performance**:
   - Use `-smp` matching your CPU core count (use `sysctl -n hw.ncpu` to see available cores)
   - Increase memory (`-m`) to 8G or more if available on your system
   - For better performance on newer Macs, try increasing CPU and RAM settings

4. **Memory Limitation Errors**:
   If you see "Addressing limited to 32 bits" errors, remove the `highmem=off` option or reduce your VM memory allocation.

5. **Network Backend Errors**:
   QEMU on macOS requires the `vmnet` backend. Do not use `-netdev user` as it may not be compiled into the binary.
