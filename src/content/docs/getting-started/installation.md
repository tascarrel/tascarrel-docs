---
order: 2
description: Prepare a supported host, install Tascarrel, and verify its dependencies.
---

# Install Tascarrel

Tascarrel has two distribution forms:

- The **Tascarrel Server and CLI** distribution is recommended. It contains the
  UI and VM guest image. Its `tascarrelctl` companion installs and maintains
  the per-user service.
- **Tascarrel Desktop** is an experimental Electron application for macOS and
  Linux. It bundles the matching server and opens the server-hosted UI in one
  application window.

Both forms use the same state under `~/.tascarrel`. Use the server and CLI
unless you specifically want to evaluate the experimental desktop shell.

## Supported Hosts

Tascarrel currently supports the following hosts:

- Apple Silicon macOS using QEMU's Hypervisor Framework.
- x86-64 and AArch64 Linux using KVM.

## Recommended Installation

On macOS and Linux distributions other than NixOS, run:

```console
curl --proto '=https' --tlsv1.2 -fsSL \
  https://tascarrel.dev/install.sh | sh
```

The installer:

1. Verifies the service manager and Linux KVM access.
2. Installs missing QEMU, Git, and SOPS packages through Homebrew, Pacman, DNF,
   or APT (uses `sudo`).
3. Downloads and verifies the matching Tascarrel release archive.
4. Installs `tascarrel` and `tascarrelctl` under `~/.local/bin`.
5. Enables the per-user service at login and starts it, or restarts an existing
   service.

Ensure `~/.local/bin` is on your `PATH`, or use the complete executable path in
the examples that follow.

To install a particular release:

```console
curl --proto '=https' --tlsv1.2 -fsSL \
  https://tascarrel.dev/install.sh | TASCARREL_VERSION=v0.3.0 sh
```

Replace `v0.3.0` with an available release identifier.

To update an existing installation to the latest release, rerun the unpinned
installer command. The installer restarts the service when it is already
running.

### NixOS

Use Tascarrel's Home Manager module instead of `install.sh`. The installer
refuses to make imperative changes on NixOS. Add Tascarrel to the inputs of
an existing flake that already uses Home Manager:

```nix
inputs.tascarrel = {
  url = "github:tascarrel/tascarrel";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
```

Within the flake's `outputs` function, import the module for the user that will
run Tascarrel. The example assumes that `tascarrel` is an argument to
`outputs`:

```nix
home-manager.users.alice = {
  imports = [ tascarrel.homeManagerModules.default ];
  services.tascarrel.enable = true;
};

users.users.alice.extraGroups = [ "kvm" ];
```

Replace `alice` with the local user name. The module installs Tascarrel, QEMU,
Git, and SOPS, then defines and enables the systemd user service.

## Host Requirements

Tascarrel requires:

- [QEMU](https://www.qemu.org/)
- [Git](https://git-scm.com/)
- [SOPS](https://getsops.io/)
- `systemd` user services on Linux or LaunchAgents on macOS

The recommended installation methods supply the software dependencies. Linux
hosts must also provide hardware virtualization and grant the current user
access to KVM.

### Linux KVM Access

Tascarrel needs read and write access to `/dev/kvm`. The installer checks this
before downloading or changing anything. Check access manually with:

```console
test -r /dev/kvm && test -w /dev/kvm
```

If the device exists but the command fails, add the current user to the `kvm`
group:

```console
sudo usermod -aG kvm "$USER"
```

Sign out and back in after changing group membership. If `/dev/kvm` does not
exist, enable hardware virtualization in the machine firmware and ensure that
the host kernel has KVM enabled. Rerun the installer after correcting either
condition.

## Manual Dependency Installation

Install the host packages manually if you do not want `install.sh` to invoke a
package manager. The installer detects packages installed through these
commands and does not request `sudo` when all dependencies are present.

### macOS

On Apple Silicon macOS, install QEMU, Git, and SOPS with
[Homebrew](https://brew.sh/):

```console
brew install qemu git sops
```

LaunchAgents are part of macOS and do not require a separate package.

### Arch Linux and Derivatives

These instructions apply to Arch Linux and systemd-based derivatives. On an
x86-64 host, install:

```console
sudo pacman -S --needed git qemu-system-x86 qemu-hw-usb-host sops
```

On an AArch64 host, install:

```console
sudo pacman -S --needed git qemu-system-aarch64 qemu-hw-usb-host sops
```

Arch packages QEMU's USB host device separately, so
`qemu-hw-usb-host` is required in addition to the system emulator.

### Fedora

On an x86-64 host, install:

```console
SOPS_VERSION=3.13.3
sudo dnf install \
  git qemu-system-x86 \
  "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-${SOPS_VERSION}-1.x86_64.rpm"
```

On an AArch64 host, install:

```console
SOPS_VERSION=3.13.3
sudo dnf install \
  git qemu-system-aarch64 \
  "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-${SOPS_VERSION}-1.aarch64.rpm"
```

Use the full `qemu-system-*` package rather than its `-core` variant. The full
package includes the QEMU USB host device required by Tascarrel's host checks.
Fedora does not package SOPS in its standard repositories, so these commands
install the official upstream RPM.

### Debian and Ubuntu

First update the package index:

```console
sudo apt update
```

On an x86-64 host, install:

```console
sudo apt install curl git qemu-system-x86
SOPS_VERSION=3.13.3
curl -LO \
  "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_amd64.deb"
sudo apt install "./sops_${SOPS_VERSION}_amd64.deb"
```

On an AArch64 host, install:

```console
sudo apt install curl git qemu-system-arm
SOPS_VERSION=3.13.3
curl -LO \
  "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_arm64.deb"
sudo apt install "./sops_${SOPS_VERSION}_arm64.deb"
```

The `qemu-system-arm` package provides the `qemu-system-aarch64` executable.
Debian and Ubuntu do not package SOPS in their standard repositories, so these
commands install the official upstream DEB.

## Install the Experimental Desktop Application

:::caution[Experimental Desktop Application]

Tascarrel Desktop is experimental and doesn't have an update mechanism. The
macOS application is ad-hoc signed and not notarized. Use the server and CLI
for the recommended installation.

:::

Download the package for your host from the
[latest GitHub release](https://github.com/tascarrel/tascarrel/releases/latest):

- `tascarrel-desktop-aarch64-darwin.dmg` for Apple Silicon macOS.
- `tascarrel-desktop-x86_64-linux.deb` or `.rpm` for x86-64 Linux.
- `tascarrel-desktop-aarch64-linux.deb` or `.rpm` for AArch64 Linux.

On macOS, download both the disk image and its `.sha256` file. Verify the disk
image before opening it:

```console
cd ~/Downloads
shasum -a 256 -c tascarrel-desktop-aarch64-darwin.dmg.sha256
```

Open the disk image and drag **Tascarrel** to Applications. The release is
ad-hoc signed because the project does not use Apple Developer Program
credentials. Before the first launch, remove the quarantine attribute from the
installed app:

```console
xattr -dr com.apple.quarantine /Applications/Tascarrel.app
open /Applications/Tascarrel.app
```

Only remove the quarantine attribute after the checksum succeeds and only for
an app downloaded from the official Tascarrel GitHub release. Replace
`/Applications/Tascarrel.app` with the installation path if Tascarrel was
copied elsewhere.

On Linux, install the package with the normal package manager. It creates a
Tascarrel launcher entry for the desktop environment.

Opening Tascarrel Desktop starts its bundled server when necessary. Opening the
app again focuses its existing window. Closing the window does not stop the
server or workspace VMs.

## Verify the Host

Run the built-in diagnostics:

```console
tascarrelctl doctor
```

The command checks the host architecture, QEMU executable and capabilities,
virtualization acceleration, Git, SOPS, and the service manager. It exits
unsuccessfully when a required check fails.

Use JSON output in scripts:

```console
tascarrelctl doctor --json
```

Executable paths can be overridden with `TASCARREL_QEMU`, `TASCARREL_GIT`, and
`TASCARREL_SOPS`.

Continue with [Run Your First Task](/docs/getting-started/quickstart).
