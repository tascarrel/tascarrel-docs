---
order: 4
description: Decide when work belongs in a separate workspace or a separate pod.
---

# Choose the Right Boundary

Tascarrel separates persistent development context from individual tasks. A
workspace holds the context; a pod holds one task.

## Use a Workspace for a Trust Domain

A workspace groups projects, tools, access, and preferences for one trust
domain, such as an employer, customer, or product.

Each workspace runs in a dedicated QEMU virtual machine. Its configuration,
repository caches, images, shared caches, agent credentials, and settings
persist across tasks and VM restarts.

The workspace name is its stable identity. Names contain 1–64 ASCII letters,
digits, underscores, or hyphens.

## Use a Pod for a Task

A pod is a disposable environment for one task. It starts from an immutable
workspace image and prepared repository state, then receives private writable
filesystems for its root, `/workspace`, Docker data, and temporary data.

A pod owns its processes, chats, network namespace, published services, working
trees, and uncommitted changes.

Stopping a pod retains those resources. Destroying it permanently removes its
private filesystems and retained processes.

## Account for Shared Resources

Pods in one workspace share:

- The workspace virtual machine's Linux kernel.
- Explicitly configured caches.
- Workspace agent credentials and harness installations.
- Workspace services such as the optional Nix daemon.
- Any USB device attached to the workspace.

Shared resources improve efficiency but form a trust relationship. A pod can
poison a writable shared cache, and pods are not security boundaries from one
another.

## Make the Decision

Create a separate workspace when work must not share a guest kernel,
credentials, caches, network policy, or hardware. Create a separate pod when the
work is trusted at the workspace level but needs a clean and independently
reviewable task state.

Read the [Isolation Model](/docs/getting-started/isolation-model) before
deciding which boundary to use.
