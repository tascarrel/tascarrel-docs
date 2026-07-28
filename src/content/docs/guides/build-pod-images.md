---
order: 2
description: Define the pod image, prepare reusable project state, and initialize new pods.
---

# Build Pod Images

Tascarrel separates reusable software from project state:

- The **image** is built from `image/Dockerfile`.
- The **workspace seed** contains repositories, overlay files, and setup output.
- **Initialization** runs for each new pod.

## Define the Image

Use a standard Dockerfile:

```dockerfile
FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
```

Tascarrel builds the image with BuildKit and stores its root filesystem as an
immutable Btrfs snapshot. Code should use Tascarrel's workspace paths rather
than assume a numeric user ID.

Image builds use the workspace network policy. The creation page automatically
allows the Debian package host plus the build and API hosts required by
selected runtimes, tools, and developer services when restricted access is
selected.
A selected Python stack copies the pinned `uv` and `uvx` binaries from Astral's
official image. A selected JavaScript and TypeScript stack installs a pinned
Node 20-compatible pnpm version.
A selected Rust stack creates the non-root `develop` account, installs the
official, checksum-verified rustup binary for the image architecture, and uses
it to install the stable Rust toolchain and Cargo under
`/home/develop/.cargo`. The generated Dockerfile does not install Debian's
`rustc` or `cargo` packages.
A selected mise tool uses the official installer after switching to the
non-root `develop` account. The generated image stores mise and its Zsh
completion under `/home/develop/.local`. Tascarrel's terminal shell loads that
completion when mise is available. Mise's configuration, cache, state, and
tool data use a shared `~/.mise` workspace cache so installed toolchains remain
available across pods.
A selected Podman capability shares `~/.local/share/containers` across pods,
preserving its rootless container storage.
A host-level sandbox can still make an external registry or package repository
unreachable; in that case workspace creation succeeds and the image build
reports the network failure when a pod is created.

## Prepare the Seed

Setup steps run synchronously while the reusable seed is prepared:

```toml
[[setup.steps]]
script = """
corepack enable
pnpm install --frozen-lockfile
"""
```

Regular files in `hooks/setup/` run afterward in lexical order. Put expensive
preparation here when future pods can share the result.

## Initialize Each Pod

```toml
[[init.steps]]
script = "pnpm run dev"
wait = false
```

Set `wait = true` when the command must finish before startup continues.
Otherwise, Tascarrel supervises it asynchronously. Regular non-hidden files in
`hooks/init/` run afterward as one asynchronous group.

## Refresh the Base State

Use **Workspace → Images**:

- **Build Image** forces a build and runs setup, even when the Dockerfile digest
  is unchanged.
- **Update Workspace Seed** refreshes configured repositories without
  rebuilding the image or rerunning setup.

A build is published only after synchronous setup succeeds. Existing pods
remain pinned to their original generation; create a new pod to use the new
state.
