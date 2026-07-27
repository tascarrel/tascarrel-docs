---
order: 6
description: Understand how Tascarrel divides authority between the host, workspace VM, and pods.
---

# System Architecture

Tascarrel divides runtime responsibilities across the host, each workspace
virtual machine, and each pod:

```text
Tascarrel UI or tascarrelctl
          │
          ▼
tascarrel server (hostd)
          │  private virtio-serial connection
          ▼
        guestd
          │  runc: pod lifecycle and process supervision
          ▼
         Pod
          ├── podd (PID 1 and pod-local initialization)
          ├── task processes
          └── podctl client
```

## Host Daemon

The `tascarrel` server runs the host daemon (`hostd`). That daemon owns
configuration, QEMU processes, repository credentials and caches, SOPS
providers, network enforcement, the web API, and upstream Git publication. It
is the only component that should need host-side project credentials.

The UI uses local HTTP and WebSocket endpoints. `tascarrelctl` uses a
private Unix socket.

## Workspace Guest

Each workspace VM runs `guestd`, which manages images, Btrfs state, pod
services, network plumbing, processes, chats, and typed requests from the host.
The VM has no general-purpose virtual NIC or host filesystem mount.

The host and guest daemons communicate through a private QEMU virtio-serial
channel. Operations that cross the main trust boundary stay with the component
that owns the authority: for example, a pod proposes a Git update, then `hostd`
applies policy and uses upstream credentials.

## Pod Runtime

The guest daemon uses `runc` to create pod namespaces, mounts, and devices, then
starts and supervises task processes. The `podd` process runs as PID 1 inside
the pod, performs pod-local initialization, and manages optional Docker. It does
not launch or supervise task processes.

The `podctl` client connects through an authenticated pod-private socket whose
listener assigns the workspace and pod identity.

Control calls, subscriptions, and Git smart-protocol streams share that socket
through Tascarrel's multiplexer. A caller cannot select a sibling pod merely by
inventing another identifier.

## Typed Protocol

Sidex schemas define actions, outputs, errors, identifiers, and subscriptions,
then generate Rust and TypeScript bindings. Most subscriptions begin with a
snapshot and emit ordered changes. Large chats bootstrap their turns, timeline,
attachments, and prompt queue in bounded chunks before live changes begin.
Resumable stores let the UI rebuild state after a connection is interrupted.
