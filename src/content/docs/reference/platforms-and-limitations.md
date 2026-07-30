---
order: 4
description: Check supported hosts and current product limitations.
---

# Platform Support

:::warning[Active Development]

Tascarrel is under active development. Things may break, and its security
properties have not been independently audited.

:::

The initial release supports:

- Apple Silicon macOS with QEMU's Hypervisor Framework.
- x86-64 Linux with KVM.
- AArch64 Linux with KVM.

Intel macOS, 32-bit systems, and hosts without the required virtualization
accelerator are unsupported. USB forwarding is Linux-host-only.

## Distribution Status

The server and CLI installed through `install.sh` are the recommended
distribution. Tascarrel Desktop is experimental on every host and does not have
an integrated update mechanism. Its macOS package is ad-hoc signed and not
notarized.

## Isolation and Availability

One QEMU VM separates each workspace from the host and other workspaces. Pods
inside a workspace share the guest kernel and are not mutual security
boundaries. Tascarrel focuses on containment, not availability: hostile code
can exhaust resources or make its own workspace unusable.

## Network Limits

- Local and private destinations are blocked unless explicitly enabled.
- Arbitrary external UDP is unavailable except for captured DNS.
- External IPv6 TCP and UDP are not implemented.
- HTTP policy and secret injection support HTTP/1.1, including upgrades, but
  not HTTP/2, QUIC, or `CONNECT`.
- HTTP request activity is available for inspected HTTP and HTTPS traffic.
  HTTPS connections relayed without TLS termination remain opaque.
- Every secret-injection rule must explicitly list its admitted HTTP methods;
  requests not admitted by any rule matching the host, optional path globs, and
  method are rejected.
- Nix builds currently perform egress as the workspace VM daemon, so network
  events are not attributed to the requesting pod.

## Workflow Limits

- Git ref deletion is not supported.
- Archived chats cannot currently be restored through the interface.
- Queued prompts do not survive an agent-engine restart.
- Tasci does not yet support steering or atomic interrupt-and-send. Its native
  session journal belongs to the associated pod; deleting the pod or journal
  prevents the stored chat from resuming its model context.
- Tasci MCP support is limited to Streamable HTTP servers and text tool
  results. MCP prompts, resources, local standard-I/O servers, and rich result
  content are not supported.
- Existing pods do not receive a rebuilt image, refreshed seed, or updated
  workspace agent inputs.
- Host-share changes require a VM restart. Linux hosts prefer virtiofs; macOS
  and Linux fallback use virtio-9p with an ownership-normalizing bridge.
- USB attachments last only for the current VM runtime.
- Incompatible persistent state has no automatic migration or rollback layer.

Check the project release notes before depending on any limitation or interface
remaining unchanged.
