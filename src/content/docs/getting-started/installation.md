---
order: 2
description: Prepare a supported host, install Tascarrel, and verify its dependencies.
---

# Install Tascarrel

Tascarrel has two distribution forms:

- **Tascarrel Desktop** is a native macOS or Linux application. It contains the
  matching server and opens the server-hosted UI in one application window.
- **Tascarrel Server** is an architecture-specific executable containing the
  UI, bundled Tasci agent, Linux guest system, kernel, and initrd. Its
  `tascarrelctl` companion installs and maintains the per-user service.

Both forms use the same state under `~/.tascarrel`.

## Supported Hosts

The initial release supports:

- Apple Silicon macOS using QEMU's Hypervisor Framework.
- x86-64 Linux using KVM.
- AArch64 Linux using KVM.

Linux distributions receive a statically linked executable, including NixOS.
Intel macOS and 32-bit hosts are not supported.

## Host Requirements

Install these dependencies before Tascarrel:

- QEMU with the accelerator required by the host platform.
- Git.
- `systemd` user services on Linux or LaunchAgents on macOS when using the
  installed background service.

SOPS is optional. It is needed only for workspaces that use SOPS-backed secret
providers.

On Linux, the current user must be able to access `/dev/kvm`. On macOS, QEMU
must report Hypervisor Framework support.

## Install Tascarrel Desktop

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

## Install the Server and CLI

For a browser-based or background-service installation, run:

```console
curl --proto '=https' --tlsv1.2 -fsSL \
  https://tascarrel.dev/install.sh | sh
```

The installer detects the host and architecture, verifies the matching release
archive, installs `tascarrel` and `tascarrelctl` under `~/.local/bin`, and
registers the server as a per-user service.

Ensure `~/.local/bin` is on your `PATH`, or use the complete executable path in
the examples that follow.

To install a particular release:

```console
curl --proto '=https' --tlsv1.2 -fsSL \
  https://tascarrel.dev/install.sh | TASCARREL_VERSION=v0.1.0 sh
```

Replace `v0.1.0` with an available release identifier.

## Verify the Host

Run the built-in diagnostics:

```console
tascarrelctl doctor
```

The command checks the host architecture, QEMU executable and capabilities,
virtualization acceleration, Git, the service manager, and optional SOPS
support. It exits unsuccessfully when a required check fails.

Use JSON output in scripts:

```console
tascarrelctl doctor --json
```

Executable paths can be overridden with `TASCARREL_QEMU`, `TASCARREL_GIT`, and
`TASCARREL_SOPS`.

Continue with [Run Your First Task](/docs/getting-started/quickstart).
