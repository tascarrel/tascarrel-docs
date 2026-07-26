---
order: 3
description: Configure Tasci, install Codex or Claude Code, and manage agent chats.
---

# Work with Coding Agents

Tascarrel supports three coding-agent harnesses:

- **Tasci** is bundled with Tascarrel and connects to configured
  OpenAI-compatible Chat Completions endpoints.
- **Codex** and **Claude Code** are installed and authenticated for each
  workspace.

The harness and its tools run inside the task pod. The model endpoint may run on
your host, elsewhere on your network, or at a hosted provider.

## Understand the Permission Model

Tascarrel uses [isolation](/docs/getting-started/isolation-model), not per-action
approval, as its agent safety model. Codex and Claude Code start without command
or file approval prompts, and Tasci's built-in tools likewise run without
per-action confirmation. The workspace VM and its declared access policies
limit what an agent can reach on the host and network.

That safety boundary makes autonomy practical. Agents keep working without
permission prompts while the web UI tracks their activity and surfaces
decisions, failures, and completed turns. You give up some moment-to-moment
control, but you can leave agents working and return when attention is needed
to review changes before publishing.

## Configure a Harness

Choose one of the supported harnesses:

- For Tasci, open **Workspace → Settings → Tasci**, add an API endpoint and
  model, and select a default model. Tasci is already installed.
- For Codex, install the pinned harness and choose **Sign in with ChatGPT**.
  Complete the displayed device-code flow under **Settings → Harnesses**.
- For Claude Code, install the pinned harness, run `claude setup-token`
  separately, and enter the resulting token under **Settings → Harnesses**.

Use different workspaces when projects should not share agent credentials.

Tasci endpoint authorization refers to a host-owned secret. The token stays out
of `settings.json`, but Tascarrel passes the complete authorization header to
the selected pod's private Tasci process. The endpoint must also be reachable
under the workspace's [network policy](/docs/guides/control-network-access).

## Start and Resume Chats

Open a pod's **Agent** view, choose a harness and model, and send a prompt.
Chats retain messages, attachments, status, and harness metadata even when the
harness process stops. Navigating away does not terminate an active turn.

Codex and Claude Code can resume their provider sessions after a harness or
workspace restart. Tasci retains the visible chat record but cannot yet resume
its model conversation after the Tasci process stops.

A pod can have multiple chats. **Interrupt** asks an active harness to stop
cooperatively. Archiving removes a completed chat from the active list; the web
UI cannot currently restore it.

## Deliver a Prompt at the Right Time

When a turn is active, the composer offers:

- **Immediate** steers the active turn when supported. Tasci does not currently
  support steering.
- **When Idle** queues a separate follow-up until the turn finishes.
- **Interrupt and Send** cancels the active turn before sending the new prompt
  when the harness supports that operation. Tasci does not yet support it.

Prompt queues are runtime state and do not survive an agent-engine restart.
Interruption is cooperative, so child processes may not stop immediately.

## Choose Models and Read Usage

Codex and Claude Code supply their available models and options. Set their
workspace defaults and ordering under **Settings → Harnesses**.

Tasci models are aliases that map to provider-native model identifiers and
endpoints under **Settings → Tasci**. One endpoint can serve several models, and
the model can be changed between turns. Tascarrel stores both kinds of settings
in `settings.json`.

Token usage and cost estimates appear only when the harness reports enough
data. Tasci can calculate costs from optional per-model pricing in
`settings.json`. Provider billing remains authoritative.

## Provide Workspace Guidance

Put Codex guidance that applies to every task in `agents/AGENTS.md`. Place
compatible reusable skills below `agents/skills/`; Tascarrel mounts workspace
skills read-only and pins them to the pod's input generation. Tasci currently
reads `/workspace/AGENTS.md` when starting a new model conversation.

Define prompt shortcuts in `config.toml`:

```toml
[chat.commands.prepare-review]
text = """
Inspect the current changes, run the smallest relevant checks, and summarize
anything that should block publication.
"""
```

Commands insert their text into the composer, where it can be adapted before
sending.
