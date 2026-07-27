---
slug: how-tascarrel-isolates-coding-agents
title: Tascarrel's Isolation Model
description: |
  Tascarrel combines a VM boundary around the complete development environment
  with container-based pods for disposable tasks. This article explains how
  layered isolation, reusable environment definitions, network controls,
  credential mediation, and Git publication form one coherent isolation model,
  along with its trust assumptions and limits.
date: 2026-07-26
tags: [tascarrel, coding agents, isolation, architecture]
author:
  name: Maximilian Köhl
  href: https://silitics.com/
---

In [Isolating Coding Agents](/blog/isolating-coding-agents), we concluded that
choosing an isolated execution substrate is only half of the design. A complete
isolation boundary must contain the agent and the entire development workflow.
It must also control every permitted path to files, services, networks,
credentials, and publication outside that environment.

Tascarrel is built around that conclusion. It places each persistent
development context inside a dedicated virtual machine, then creates a
container-based pod for every task. The VM separates trust domains, while pods
make clean, parallel tasks practical within one. Agents receive broad
permissions inside their pods. Network connections, upstream Git operations,
selected credentials, and other external interactions pass through explicit,
host-owned interfaces.

This separation is the core of Tascarrel's isolation model. Routine development
can proceed without command approvals, while access outside the development
environment remains mediated. This article explains how the pieces fit together
and where the model's limits lie.

Tascarrel is under active development. Things may break, and its security
properties have not been independently audited.

<!-- truncate -->

## The Isolation Boundary

Tascarrel organizes development at two levels. A **workspace** is a persistent
development context and trust domain. It contains repositories, tools,
configuration, caches, agent credentials, and network controls. A **pod** is a
disposable environment for one task, with its own writable filesystems,
processes, chats, working trees, and network namespace.

The workspace VM is the primary isolation boundary. Each workspace runs in a
dedicated QEMU VM with its own Linux kernel. QEMU uses KVM on Linux and Apple's
Hypervisor Framework on Apple Silicon macOS. The guest boots from an immutable
EROFS system image and stores persistent state on a sparse Btrfs disk.

The VM has no conventional network interface and no mount of the host
filesystem. Host and guest communicate over one private virtio-serial
connection. Tascarrel materializes repositories from host-owned Git caches into
storage inside the VM rather than bind-mounting working trees from the trusted
machine. The host daemon performs upstream Git operations using host-owned
credentials and transfers repository data through Tascarrel's private
transport. The workspace receives the repository data, not the credentials.

This topology puts the complete development workflow behind the same boundary.
The agent, its built-in tools, package managers, compilers, build scripts,
tests, language servers, development servers, and any code they load all run
inside the workspace VM. Working-tree changes stay there until they pass
through Tascarrel's Git transport. Processes cannot browse the trusted
machine's home directory or scan its network through an ordinary virtual
network interface because neither path exists.

## VMs and Containers

Tascarrel deliberately combines VMs and containers because their strengths are
complementary. The VM provides the stronger isolation boundary. Its separate
guest kernel and hardware-virtualized interface protect the trusted machine and
other workspaces, even when development code may actively attack the boundary.
That strength comes with higher startup, memory, storage, and operational costs.

Container-based pods provide the inner layer. Tascarrel creates them with
`runc`, Linux namespaces, private mount trees, device allowlists, seccomp, and
AppArmor. They start quickly, use copy-on-write snapshots to create private
writable state without duplicating the prepared environment, and retain the
filesystem and tool compatibility expected of a normal development environment.
Each task receives separate writable state, processes, and networking without
requiring another VM.

The layers do not make equivalent security claims. Pods share the workspace
VM's guest kernel and are not security boundaries between mutually hostile
tasks. If code escapes a pod through a guest-kernel or container-runtime
vulnerability, it may compromise the workspace and its sibling pods. It still
faces the outer VM boundary before it can reach the trusted machine or another
workspace. This provides defense in depth: a hostile workload generally has to
defeat both the pod containment and the VM boundary before it can reach the
trusted machine through an isolation escape. It can still use any external
resources deliberately exposed to the workspace, which is why Tascarrel
controls those paths separately.

This places each mechanism where its trade-offs fit. The VM boundary separates
trust domains. Container isolation makes concurrent, disposable tasks practical
inside a trust domain. Projects that cannot safely share a guest kernel,
credentials, caches, services, or devices belong in different workspaces.

### Why One VM per Workspace?

A VM for every task can provide stronger task-to-task isolation and is a good
fit for hosted systems built around short-lived jobs. Tascarrel instead targets
local, persistent development contexts on Linux and macOS. Those contexts may
contain large repository caches, custom toolchains, Docker data, Nix stores,
editor state, and long-running services.

Tascarrel therefore amortizes one VM across a trust domain. Btrfs snapshots and
Linux namespaces make disposable tasks cheap within it. This trades
task-to-task isolation for lower resource use, faster task creation, and broad
development-tool compatibility. Separate workspaces restore the VM boundary
where that trust relationship is not acceptable.

## Reusable Declarative Environments

An isolated environment must also be practical to define, share, and recreate.
Tascarrel describes a workspace with a standard Dockerfile and configuration
for repositories, overlay files, setup and initialization steps, caches, and
access rules. Teams can version and review those inputs like other project
configuration.

Tascarrel builds the Dockerfile inside the workspace VM and stores the resulting
root filesystem as an immutable Btrfs snapshot. It then materializes the
configured repositories, applies overlay files, runs setup steps, and freezes
the result as a reusable workspace seed.

Every new pod receives private writable snapshots of that image and seed.
Existing pods remain pinned to their original generation when an image is
rebuilt or repositories are refreshed. A task can therefore modify its tools,
working trees, and other private state without changing the starting point for
later tasks.

## No Command Approvals

Tascarrel supports Codex and Claude Code, along with its own harness for local
models and direct model API access. It starts all of them without per-command or
per-file approval prompts. The agent can inspect and edit files, install
dependencies, execute builds, run repository scripts, launch tests, and start
applications without waiting for the user. Every path to execution remains within
the same isolation boundary. Model-generated shell commands, build tooling, and
malicious dependency scripts all run inside the selected pod and workspace VM.

The rest of the development workflow stays inside as well. Tascarrel starts its
browser-based Code editor inside the selected pod, so language servers and
editor automation receive the pod's access rather than the developer's ambient
access. When Docker is enabled, a confined Docker daemon runs inside each pod
instead of exposing a Docker socket from the trusted machine. Repository
working trees are stored inside the VM, not shared through a writable host
mount.

Optional features still expand what a pod can reach inside its workspace.
Rootless Podman increases the guest-kernel interface available to the pod. The
optional pod-facing Nix daemon is a workspace service shared by all pods. It is
separate from the guest system's own Nix daemon. Nested virtualization exposes
the VM's KVM device, and USB forwarding places the selected device inside the
workspace trust domain. Tascarrel keeps these integrations behind the VM
boundary, but they should be enabled only when the development environment
needs them.

Broad permissions inside the pod allow the agent to complete the normal
inspect, edit, build, and test loop unattended. The user can return to review
files, diffs, commits, logs, and running applications. Authority outside the
workspace is handled separately.

## External Access Is Mediated

The workspace VM supplies the execution substrate, but it is not the complete
isolation design. Every permitted interaction with external resources also
forms part of the boundary. Tascarrel routes those interactions through
host-owned services that enforce the workspace configuration and retain the
origin information needed for each decision.

### Controlled Network Access

Tascarrel controls network access by omitting a conventional virtual network
interface. The guest captures DNS and TCP traffic, attributes each connection
to its source, and sends the request to the host daemon. The host applies the
workspace's destination rules before opening an external connection.

The default permits public TCP destinations on ports 80 and 443 while blocking
local, private, and link-local addresses. Arbitrary external UDP and external
IPv6 are unavailable. A workspace that may run actively hostile code should
instead deny egress by default and allow only the destinations it needs:

```toml
[network]
default = "deny"
allow-hosts = [
  "api.github.com",
  "*.npmjs.org",
]
allow-ports = [80, 443]
```

Tascarrel evaluates hostname rules using the HTTP `Host` header and, for HTTPS,
TLS SNI. It requires the two hostnames to agree before forwarding an HTTPS
request.

An allowlist limits destinations, not behavior. A permitted service may still
be used to exfiltrate data, and any credential accepted by that service retains
its own authority. Network and credential controls must therefore be designed
together.

Access to services on the trusted machine is also explicit. A workspace may
map selected host-loopback ports into pods, while other local services remain
inaccessible.

### Development Servers

Development servers remain inside their pods. A user or workload can run
`podctl http publish <port>` to publish an HTTP service already listening on the
pod's loopback interface. The host daemon assigns the route a unique hostname,
accepts browser requests, and proxies them through Tascarrel's private transport
to the service.

The development server never needs to bind a port on the trusted machine, and
the workload does not choose or manage a host port. Tascarrel can present the
route directly in the pod's workbench, making applications available for
testing without adding a general network path into the workspace VM.

For non-HTTP services, Tascarrel can instead publish a raw TCP service. The host
daemon chooses an available host port dynamically and forwards it to the
service inside the pod, avoiding host port conflicts.

### Proxied Git Operations

The host daemon is the only component that contacts upstream Git servers. It
maintains host-owned object caches and uses host-owned credentials to fetch and
publish repository data. When a repository is refreshed, Tascarrel transfers
the prepared repository state into the workspace without exposing the
credentials.

Inside a pod, remote Git operations use an authenticated Tascarrel transport.
Fetches, pulls, and rebases are served from the prepared repository state. A
push travels through the workspace VM to the host, where it becomes a proposal
to update specific upstream refs. The host evaluates ordered branch and tag
rules, with approval required by default:

```toml
[git]
default-policy = "require-approval"

[[git.branches]]
pattern = "main"
policy = "deny"

[[git.branches]]
pattern = "automation/**"
policy = "allow"
```

This is the kind of approval for which a human can make a meaningful decision.
It covers a specific ref update at the publication boundary, not an arbitrary
command and everything that command may execute. The development environment
can prepare commits without automatically receiving authority to publish them.

Tascarrel records the exact upstream object IDs observed before approval and
uses them as leases when applying the update. A concurrent upstream change
fails closed, and multi-ref updates remain atomic.

### HTTP Secret Injection

Tascarrel can keep selected HTTP credentials on the trusted machine and inject
them into matching HTTP/1.1 requests after they leave the VM. The workload
sends a placeholder instead of the credential:

```toml
[[network.secret-injection]]
host = "api.example.com"
header = "authorization"
placeholder = "replace-with-api-token"
secret = "project.API_TOKEN"
```

For HTTPS, Tascarrel installs a per-workspace certificate authority and
terminates TLS at the host boundary. The current secret-injection path supports
HTTP/1.1, including upgrades, but not HTTP/2, QUIC, or `CONNECT`.

Unlike a token stored in an environment variable, the injected value is not
available to every process in the task. The workload still sees the remote
response and can exercise the credential's authority through that service.
Protocols outside the supported HTTP path require a different design.

HTTP secret injection covers only credentials used through that path. Codex
and Claude Code credentials persist at workspace scope and are shared by the
workspace's pods. Model API credentials used by Tascarrel's own harness are
passed only to the selected pod's harness process. Secrets explicitly
interpolated into environment variables are also available inside the
workspace. These credentials belong to the workspace trust domain and are not
protected from a guest compromise.

## Trust Assumptions and Limits

Tascarrel is designed to contain development code that actively tries to
escape. A workspace receives no mount of the trusted machine's filesystem and
no general-purpose virtual network interface. A workload starts inside a
container-based pod, behind a separate guest kernel and hardware-virtualized VM
boundary. Upstream Git credentials, publication decisions, and selected HTTP
secrets remain on the trusted side. Together, these properties provide strong
defense in depth and a materially stronger boundary than a command sandbox or
native development container.

Every software isolation boundary rests on trusted components. Tascarrel's
outer boundary trusts the kernel of the machine running it, the
hardware-virtualization stack, QEMU and its device model, the host daemon, and
the private control protocol. A vulnerability in one of those components could
defeat the VM boundary. Tascarrel reduces the exposed surface by omitting a
virtual network interface and host filesystem mount, and by routing external
interactions through explicit services.

Inside the VM, a workspace is one deliberate trust domain. Pods have separate
filesystems, processes, and networks, while sharing the guest kernel and any
configured workspace resources. A compromised pod may poison a shared cache,
use shared credentials, attack a workspace service, or exploit the guest kernel
to reach a sibling pod. The outer VM continues to protect the trusted machine
and other workspaces. The compromised workload can still use resources
explicitly granted to its workspace. Projects that require protection from one
another belong in separate workspaces.

A workload has full authority over the state deliberately placed in its pod. It
may delete or corrupt that state. Data sent to a hosted model or an allowed
network destination also leaves the workspace under that service's controls.
Tascarrel keeps upstream Git publication separate and makes external network
and credential access configurable, allowing these grants to remain narrower
than the pod's internal permissions.

Tascarrel does not currently provide availability isolation. A workload may
exhaust CPU, memory, storage, or other resources available to its workspace or
the trusted machine. Tascarrel's security properties have not been independently
audited. Its architecture defines strong boundaries and small external
interfaces. Deployment decisions should also account for its availability
limits.

## Conclusion

Tascarrel treats isolation as a property of the complete development system,
not a wrapper around selected agent commands. A workspace VM contains the agent
and everything it causes to run. Reusable environment definitions make that
workspace reproducible, while copy-on-write snapshots and pods provide cheap,
disposable task state.

The paths out of the VM are part of the same design. Network connections cross
host-enforced destination controls. Git publication uses host-owned credentials
and ref-specific rules. Selected HTTP credentials can remain outside the
workspace, and access to services and devices must be exposed explicitly.

The central trade-off is the placement of the VM boundary. Tascarrel uses one
VM per trust domain rather than one per task. We believe this is the right
trade-off for development. Large codebases often depend on expensive shared
state such as compiler outputs, package stores, `sccache` data, and Yocto build
trees. Rebuilding or duplicating that state for every task would make many
workflows impractical. Sharing it means that pods within a workspace trust one
another, so projects with different trust requirements belong in separate
workspaces. Within that boundary, agents can work without babysitting. At the
boundary, external access follows explicit, enforceable paths.
