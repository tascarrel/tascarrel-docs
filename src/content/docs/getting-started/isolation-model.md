---
order: 5
description: Learn which Tascarrel boundaries are intended for security and which provide task isolation only.
---

# Isolation Model

Tascarrel uses isolation as its agent safety model. Coding agents run with broad
permissions inside task pods; the enclosing workspace virtual machine, rather
than command-by-command approvals, provides the main boundary. That boundary
limits what a mistaken or compromised agent can reach; it does not make the
agent's actions correct.

Virtual machines and Linux namespaces serve different purposes. Understanding
the distinction is essential before running unfamiliar code or agents.

:::warning[Active Development]

Tascarrel is under active development. Things may break, and its security
properties have not been independently audited.

:::

## Workspace VMs Provide the Main Safety Boundary

Each workspace runs in a dedicated QEMU virtual machine. The VM is intended to
protect:

- The host from a compromised workspace.
- Other workspace VMs from that workspace.

The VM has no conventional network interface or implicit host filesystem mount.
It receives a private control connection, immutable system image, persistent
state disk, and explicitly attached USB devices. Named host shares are an
explicit exception: configuring one exposes that host directory to every pod in
the workspace according to its required `ReadOnly`, `Overlay`, or `ReadWrite`
mode. `ReadOnly` and `Overlay` keep the VM transport read-only. `Overlay`
retains each pod's changes separately until an exact revision is inspected and
explicitly applied on the host. `ReadWrite` lets every pod modify the host
directory directly.

Crossing this boundary unexpectedly would require a vulnerability in a trusted
component such as the host kernel, hypervisor, QEMU device emulation, host
daemon, or another host-side dependency.

## Pods Add Containment

Pods run untrusted development processes inside the workspace VM. A pod receives
Linux user, mount, PID, network, IPC, UTS, and cgroup namespaces, along with
seccomp, AppArmor, a private mount tree, and a device allowlist.

Root inside a pod maps to an unprivileged ID range in the guest. It is not guest
root and has no relationship to host root.

Optional Docker, Podman, Nix, nested-virtualization, and USB features deliberately
expand a pod's interface to the guest. Enable only what a workspace needs.
Host shares expand the interface through the VM to selected host directories;
`ReadWrite` shares should be treated as direct authority to modify their
contents. An `Overlay` share grants read access and the ability to prepare
changes for separate host-side approval, but not direct write access to the
host directory.

## Pods Trust Their Workspace

Pods in one workspace share the guest kernel and may share writable caches,
credentials, services, and devices. A compromised pod may affect other pods in
that workspace through those resources or through a guest-kernel vulnerability.

Use different workspaces for mutually hostile or differently trusted projects.

## Availability Is Not Isolated

Tascarrel explicitly does not promise availability isolation. A development
workload may consume the CPU, memory, storage, or other resources available to
the workspace or host.

Hypervisor and guest-kernel vulnerabilities remain residual risks. Isolation
also does not make an enabled third-party tool trustworthy.

For vulnerability reporting, see the
[Security Policy](/docs/reference/security-policy).
