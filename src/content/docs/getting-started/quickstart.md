---
order: 3
description: Start Tascarrel, create a workspace, connect an agent harness, and review one task.
---

# Run Your First Task

This guide uses the default configuration to run one reviewed agent task.

## Start Tascarrel

The server installer starts the per-user service. If you stopped it after
installation, start it again with:

```console
tascarrelctl daemon start
```

Create a key for the first browser:

```console
tascarrelctl auth pair --label "Local browser"
```

Open the UI at <http://tascarrel.localhost:8272> and enter the printed key.
Tascarrel retains the resulting browser session. If the UI does not load,
check:

```console
tascarrelctl daemon status
tascarrelctl daemon logs
```

Run `tascarrel` directly to keep the server in the foreground.

If you installed the experimental desktop application, open **Tascarrel** from
the macOS or Linux application launcher instead. Its startup window reports host
checks and payload extraction, pairs its browser session through the private
control socket, and loads the application when the server is ready.

## Create and Start a Workspace

Create a workspace named `demo`:

```console
tascarrelctl workspace create demo
tascarrelctl workspace start demo
```

The `create` command writes a default Debian development configuration. The
workspace `start` command starts the virtual machine and waits for its guest
service to become ready.

## Choose a Coding Harness

Choose one of the available harnesses:

- For Tasci, open **Workspace → Settings → Tasci**, add an OpenAI-compatible
  endpoint and model, and select a default model. Tasci itself is bundled.
- For Codex, install the pinned harness and choose **Sign in with ChatGPT**.
  Complete the device-code flow under **Settings → Harnesses**.
- For Claude Code, run `claude setup-token` separately and enter the resulting
  setup token under **Settings → Harnesses**.

Harness configuration and credentials belong to the workspace rather than each
pod. If a Tasci endpoint requires authentication, configure a secret provider
before adding its authorization header.

## Start a Task

Use the add button beside **Pods** and enter a concrete first request, such as:

```text
Inspect the repositories in this workspace and summarize what each one does.
Do not change any files.
```

Tascarrel creates a pod and its first chat together. The initial image may take
time to build, so the first pod usually starts more slowly than later pods.

While the agent runs, you may leave the page. Tascarrel keeps the chat and shows
an attention indicator when input, a failure, or a completed turn needs review.

## Find Your Way Around

The sidebar selects workspaces and pods. Workspace-level entries manage
repositories, images, network access, and settings. A selected pod provides:

- **Agent** for chats and prompts.
- **Code** for the embedded code editor.
- **Changes** for Git status, commits, and diffs.
- **Files** for quick previews below `/workspace`.
- **Pod** for lifecycle details and supervised processes.

Capabilities such as USB appear only when enabled.

When you are finished, stop the pod to retain its state or destroy it to remove
its private files and processes.

## Stop without Deleting

Stop the workspace virtual machine:

```console
tascarrelctl workspace stop demo
```

Stopping retains the workspace configuration, persistent disk, images, pods,
chats, and repository state. Starting the workspace again restores the retained
resources, although processes that were running before the VM stopped return as
stopped records rather than live processes.

Next, [choose the right boundary](/docs/getting-started/choose-the-right-boundary) or
[configure the workspace](/docs/guides/configure-a-workspace).
