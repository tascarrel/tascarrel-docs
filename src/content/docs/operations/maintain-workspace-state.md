---
order: 2
description: Understand retained state before replacing images or removing pods, caches, and workspaces.
---

# Maintain Workspace State

Tascarrel retains state at different scopes:

- Workspace configuration and host-owned repository caches remain when its VM
  is stopped.
- VM disks, images, seeds, harness profiles, editor profiles, and declared
  caches remain until the workspace is deleted.
- A pod's writable files and chats persist until the pod is destroyed.
- USB attachments last for the current VM runtime. Prompt queues last until the
  agent engine restarts.

## Replace a Pod Generation

Image and seed updates affect only new pods. Existing pods remain pinned to
their original files, hooks, and agent inputs. Review and publish valuable
changes before destroying an old pod.

See [Build Pod Images](/docs/guides/build-pod-images) for image and seed
actions.

## Remove a Pod or Workspace

Destroying a pod permanently removes its private state. Deleting a workspace
removes all of its pods and retained workspace state:

```console
tascarrelctl workspace delete demo
```

The CLI requests confirmation. `--force` skips it but does not make the data
recoverable.

## Retain Shared Caches

Removing a `[[caches]]` declaration unmounts the cache from new pods without
deleting its backing contents. Reusing the same cache name makes those contents
visible again.

Tascarrel has no general state-migration framework. Back up repositories and
configuration before upgrading, and follow release-specific compatibility
instructions.
