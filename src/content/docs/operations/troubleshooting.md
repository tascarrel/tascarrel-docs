---
order: 4
description: Resolve common installation, VM, network, image, agent, and editor failures.
---

# Troubleshoot Tascarrel

Start with the smallest check that identifies the failing layer.

## Tascarrel Does Not Start

Run:

```console
tascarrelctl doctor
tascarrelctl daemon status
tascarrelctl daemon logs
```

On Linux, confirm that the user can access `/dev/kvm`. On macOS, confirm that
the installed QEMU supports the Hypervisor Framework. The browser startup page
and experimental desktop application show these checks before the application
loads. If a foreground server reports an occupied runtime, stop the installed
service first.

## macOS Rejects the Experimental Desktop Application

Tascarrel Desktop is ad-hoc signed, so Gatekeeper may reject the downloaded app
even when the disk image is intact. Follow the checksum verification and
quarantine removal steps under
[Install the Experimental Desktop Application](/docs/getting-started/installation/#install-the-experimental-desktop-application).
Do not remove quarantine from an app whose checksum does not match the official
release.

## A Workspace VM Does Not Start

Inspect daemon logs for QEMU or disk errors. Recheck configured memory and disk
values, especially after moving configuration between different hosts.
Configuration validation errors must be corrected before restart.

After a guest startup or runtime-service failure, Tascarrel briefly keeps QEMU
running so remaining guest diagnostics can reach the daemon log before the VM
stops.

## An Image Build Fails

Open the Images view and find the first failing Dockerfile, setup step, or setup
hook. Setup is synchronous, so Tascarrel keeps the previously published image
and seed when preparation fails.

## A Pod Is Ready but a Tool Is Missing

Check the pod's pinned image generation. An existing pod does not receive a
newly built image. Create a new pod after the build completes.

A pod can report ready before its managed Docker daemon becomes available.
Inspect the supervised Docker process before assuming the socket is broken.

## A Network Request Is Denied

Check **DNS Requests**, **HTTP Requests**, and **TCP Flows**. Local destinations
are blocked unless `allow-local = true`, even with the default allow action.
Hostname policy applies only where Tascarrel can inspect HTTP or HTTPS. The
HTTP request log excludes query strings and encrypted pass-through HTTPS.

## An Agent Cannot Start or a Turn Fails

Open **Workspace → Settings → Harnesses** and verify authentication. Then inspect
the agent's supervised process output. Model availability and authentication
errors can originate from the harness provider rather than Tascarrel.

For Tasci, also check **Settings → Tasci**, the selected endpoint and model, its
authorization template, and the matching workspace network secret-injection
rule. Tasci requires an OpenAI-compatible Chat Completions endpoint. Its
failed turns include actionable provider diagnostics such as authentication,
quota, and credit errors. Its supervised process log also records harness
startup, turns, and provider failures.

## The Web Editor or a Preview Does Not Open

Inspect the code-server or application process, confirm the pod port, and check
that the route still targets the current pod. Previews and the Code view depend
on the host service remaining available.
