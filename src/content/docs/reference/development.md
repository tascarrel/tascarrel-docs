---
order: 7
description: Enter the development environment, run focused checks, and build release artifacts.
---

# Contribute to Tascarrel

The source repository uses Nix for its toolchain and packaging environment:

```console
nix develop
```

## Run Focused Checks

For a Rust change, format and check the affected package:

```console
cargo fmt --all -- --check
cargo test -p tascarrel-host
cargo clippy -p tascarrel-host --all-targets -- -D warnings
```

Use full checks only for cross-cutting changes:

```console
cargo test --workspace --all-targets
cargo clippy --workspace --all-targets -- -D warnings
nix flake check
```

The `frontend/` package scripts provide its type checks, linting, and production
build.

## Build Guest Images

```console
nix build .#packages.x86_64-linux.vm-image
nix build .#packages.aarch64-linux.vm-image
```

Guest boot, device, and packaging changes require architecture-relevant checks;
host-only unit tests do not exercise the VM boundary.

## Build a Distribution

```console
nix build .#tascarrel
```

The complete distribution embeds the immutable NixOS store image, Linux kernel,
initrd, guest services, pod tools, the bundled Tasci agent, and compiled web UI
in the native host executable. `nix build .#tascarrel-cli` builds only the host
CLI and daemon.

At startup, Tascarrel verifies and extracts the payload below
`$TASCARREL_HOME/state/payloads/<sha256>/`.

## Override Guest Binaries

Replace packaged Linux guest binaries for one VM boot:

```console
nix develop --command cargo build \
  -p tascarrel-guest \
  -p tascarrel-podd \
  -p tascarrel-podctl \
  -p tasci-exec
nix run .#host -- --local-binaries "$PWD/target/debug"
```

The directory is mounted read-only using virtiofs on Linux, with 9p as a Linux
fallback and as the macOS transport. Replacement binaries must target Linux
and the guest architecture. The directory must contain executable
`tascarrel-guest`, `tascarrel-podd`, `podctl`, and `tasci-exec` files.
