---
order: 2
description: Prepare a supported host, install Tascarrel, and verify its dependencies.
---

# Install Tascarrel

Tascarrel is distributed as one architecture-specific executable containing the
CLI, host daemon, web-based UI, bundled Tasci agent, Linux guest system, kernel,
and initrd.

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
- A Chromium-family web browser.
- `systemd` user services on Linux or LaunchAgents on macOS when using the
  installed background service.

SOPS is optional. It is needed only for workspaces that use SOPS-backed secret
providers.

On Linux, the current user must be able to access `/dev/kvm`. On macOS, QEMU
must report Hypervisor Framework support.

## Install the Latest Release

Run the same installer on macOS or Linux:

```console
curl --proto '=https' --tlsv1.2 -fsSL \
  https://tascarrel.dev/install.sh | sh
```

The installer detects the host and architecture, downloads the matching archive
and SHA-256 checksum from the latest GitHub release, verifies the archive,
installs the executable at `~/.local/bin/tascarrel`, and runs
`tascarrel install`.

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
tascarrel doctor
```

The command checks the host architecture, QEMU executable and capabilities,
virtualization acceleration, Git, the service manager, and optional SOPS
support. It exits unsuccessfully when a required check fails.

Use JSON output in scripts:

```console
tascarrel doctor --json
```

Executable paths can be overridden with `TASCARREL_QEMU`, `TASCARREL_GIT`, and
`TASCARREL_SOPS`.

Continue with [Run Your First Task](/docs/getting-started/quickstart).
