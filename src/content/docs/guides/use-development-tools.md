---
order: 4
description: Create pods and use their terminals, process controls, code editor, and file viewer.
---

# Use Development Tools

Start a pod from the current image and workspace seed. Give it a task-oriented
title; the title can change without changing the pod's identity.

Stopping a pod retains its private state. Destroying it removes its writable
filesystems, chats, and retained processes, so preserve valuable changes first.

## Open a Terminal

Terminals start in `/workspace` with the pod's user environment and a live
pseudo-terminal. Closing a tab does not guarantee that its process exited.

The **Processes** view shows supervised commands, lifecycle state, exit results,
and captured output. Use the normal terminate action first, then choose a
specific signal when needed:

- **Interrupt** behaves like `Ctrl+C`.
- **Hang up** disconnects a terminal-oriented process.
- **Terminate** requests an orderly shutdown.
- **Kill** stops it without cleanup.

The same controls are available through
[`podctl processes`](/docs/reference/podctl-cli).

## Edit Code

The **Code** view starts code-server inside the selected pod. It has access to
the same workspace, environment, and tools as the terminal. Its workspace-level
profile keeps settings and extensions available across pods.

## Inspect Files

The **Files** view lazily browses `/workspace`. Text previews use syntax
highlighting, Markdown files offer rendered and source representations, and
PDFs and images use dedicated viewers. The view does not follow symbolic links,
preventing traversal outside the workspace tree or through recursive links.

A link such as `[configuration](/workspace/project/config.toml)` in an agent
message opens the same file viewer over the chat. Use Code or a terminal to
edit files.
