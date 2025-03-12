require "download_strategy"

class NoSubmoduleGitDownloadStrategy < GitDownloadStrategy
  def stage
    # Set environment configuration to force detached head advice
    system "git", "config", "advice.detachedHead", "true"
    # Ensure submodules are not initialized or updated
    system "git", "config", "--local", "submodule.recurse", "false"
    # Fetch the main branch explicitly
    system "git", "config", "--replace-all", "remote.origin.fetch", "+refs/heads/main:refs/remotes/origin/main"
    system "git", "fetch", "origin", "main"
    system "git", "checkout", "main"
    super
  end

  def git_env
    {
      "GIT_TERMINAL_PROMPT" => "0",
      "GIT_SSH_COMMAND" => "/usr/bin/ssh -oBatchMode=yes",
      "GIT_ASKPASS" => "/bin/echo"
    }
  end

  def submodule(*)
    # Override submodule method to do nothing
  end

  def submodules
    # Override submodules method to return an empty array
    []
  end

  def update_submodules(ctx = nil)
    # Override update_submodules to skip submodule sync
  end
end

class Libangle < Formula
  desc "Conformant OpenGL ES implementation for Windows, Mac, Linux, iOS and Android"
  homepage "https://chromium.googlesource.com/angle/angle"
  head "https://chromium.googlesource.com/angle/angle.git", using: NoSubmoduleGitDownloadStrategy, branch: "main"
  license "BSD-3-Clause"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "python@3.13" => :build

  def install
    depot_tools_path = HOMEBREW_CACHE/"libangle--depot_tools--git"
    unless File.directory?(depot_tools_path)
      # Manually initialize and fetch depot_tools
      system "git", "init", depot_tools_path
      system "git", "-C", depot_tools_path, "fetch", "https://chromium.googlesource.com/chromium/tools/depot_tools", "--depth", "1"
      system "git", "-C", depot_tools_path, "checkout", "FETCH_HEAD"
    end
    ENV.prepend_path "PATH", depot_tools_path
    ENV["DEPOT_TOOLS_UPDATE"] = "0"

    # Determine the SDKROOT dynamically
    sdkroot = `xcodebuild -sdk macosx -version Path`.strip
    ENV["SDKROOT"] = sdkroot
    macos_deployment_target = "13.3"

    # Manually initialize and fetch angle without submodules
    system "git", "clone", "--depth", "1", "--branch", "main", "https://chromium.googlesource.com/angle/angle", "source/angle"
    cd "source/angle" do
      if File.exist?("scripts/bootstrap.py")
        system "python3", "scripts/bootstrap.py"
      else
        odie "scripts/bootstrap.py not found"
      end

      # Sync the dependencies without hooks
      system "gclient", "sync", "--nohooks", "--no-history", "--shallow", "--no-nag-max"

      # Update clang to the expected version
      system "python3", "tools/clang/scripts/update.py"

      # Add necessary flags to the gn args
      gn_args = %W[
        use_custom_libcxx=true  # Set use_custom_libcxx to true: This is required for PartitionAlloc to work.
        treat_warnings_as_errors=false
        mac_deployment_target="#{macos_deployment_target}"
        extra_cflags="-mmacosx-version-min=#{macos_deployment_target} -isysroot #{sdkroot} -D_LIBCPP_BUILDING_LIBRARY"
        extra_cxxflags="-mmacosx-version-min=#{macos_deployment_target} -isysroot #{sdkroot} -D_LIBCPP_BUILDING_LIBRARY"
        extra_ldflags="-mmacosx-version-min=#{macos_deployment_target} -isysroot #{sdkroot}"
        pdf_use_partition_alloc=false  # Add pdf_use_partition_alloc=false: This setting is added to the GN configuration to disable PartitionAlloc.
      ]
      gn_args << 'target_cpu="arm64"' if Hardware::CPU.arm?

      system "gn", "gen", "angle_build", "--args=#{gn_args.join(' ')}"
      system "ninja", "-C", "angle_build"
      
      lib.install "angle_build/libEGL.dylib"
      lib.install "angle_build/libGLESv2.dylib"      
      include.install Pathname.glob("include/*")
    end
  end

  test do
    system "true"
  end
end