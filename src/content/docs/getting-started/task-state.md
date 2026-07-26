---
order: 6
description: Understand how reusable workspace inputs become private task state.
---

# How Task State Works

Tascarrel separates reusable workspace preparation from writable task state.
This keeps new pods consistent while allowing each task to change its own files.

## Images Supply the Tools

The workspace's `image/Dockerfile` defines the base operating system and tools.
Tascarrel builds and stores the result as an immutable Btrfs snapshot.

## Seeds Prepare Project State

After building the root filesystem, Tascarrel prepares a workspace seed:

1. Configured repositories are materialized from host-owned caches and checked
   out on their advertised upstream default branches.
2. The optional overlay is copied into `/workspace`.
3. Declared setup steps and files under `hooks/setup/` run in order.
4. The resulting root filesystem and workspace state are frozen for reuse.

New pods receive writable snapshots of the prepared image and seed. Existing
pods are never overwritten when a newer generation is published.

## Generations Keep Existing Pods Stable

Tascarrel reuses an image with matching input. After an input change, the next
pod creates a new generation while existing pods keep the old one. Use
[Build Pod Images](/docs/guides/build-pod-images) to build or refresh a
generation explicitly.

## The State Disk Persists Workspace Data

The workspace VM uses:

- An immutable EROFS system image.
- Ephemeral root, runtime, temporary, log, and cache filesystems.
- A sparse persistent Btrfs state disk.

The state disk retains images, seeds, pod filesystems and records, repository
state, and the optional Nix store. Configured caches use separate,
workspace-level subvolumes shared by all pods.

Tascarrel currently does not migrate incompatible state formats. Read
[Maintain Workspace State](/docs/operations/maintain-workspace-state) before
resetting or upgrading an experimental installation.
