---
order: 3
description: Start Tascarrel, create a workspace, configure an agent harness, and review one task.
---

# Run Your First Task

This guide creates a workspace through the UI, configures one coding harness,
and runs one reviewed agent task.

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

Use the workspace creation page in the UI:

1. Select **Create workspace**.
2. Enter `demo` as the workspace name.
3. Add the Git repositories for the first task and select their branches when
   needed.
4. Select the languages, tools, and workspace capabilities the project needs.
   Leave optional settings at their defaults when unsure.
5. Review the generated `Dockerfile`, `config.toml`, and `AGENTS.md`, then
   select **Create workspace**.

Tascarrel creates the workspace and starts its virtual machine. The first start
may take a moment while the guest becomes ready.

## Configure a Coding Harness

Before starting a task, open **Settings** in the workspace sidebar and configure
at least one coding harness:

- For Codex, open **Settings → Harnesses**, select **Install harness**, and then
  select **Sign in with ChatGPT**. Complete the displayed device-code flow.
- For Claude Code, open **Settings → Harnesses**, select **Install harness**,
  run `claude setup-token` separately, and enter the resulting setup token.
- For Tasci, open **Settings → Tasci**, add an OpenAI-compatible endpoint and
  model, and select a default model. Tasci is bundled with Tascarrel.

Harness credentials are shared by every pod in the workspace. Use separate
workspaces when projects should not share agent credentials.

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
- **Pod** for lifecycle details, supervised processes, and repository imports.

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
