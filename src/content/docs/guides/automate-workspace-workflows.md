---
order: 9
description: Run durable command, agent, host-command, and approval workflows from workspace YAML.
---

# Automate Workspace Workflows

An Automation is a host-owned, durable workflow declared in a workspace
configuration directory. A manual action or schedule creates an execution from
the current definition. Tascarrel captures that definition immutably and runs
its steps in order inside one dedicated pod.

Tascarrel stores workspace configuration below
`$TASCARREL_HOME/config/workspaces/<name>`. Create
`automations/deploy.yaml` in that directory:

```yaml
name: Update and Deploy
description: Update locked inputs, review the change, and deploy the fleet.

on:
  workflow_dispatch: {}
  schedule:
    - cron: "15 4 * * 1"

defaults:
  agent:
    harness: codex
    model: gpt-5

concurrency:
  limit: 1

timeout-minutes: 90

steps:
  - id: update
    name: Update flake inputs
    run: nix flake update

  - id: review
    name: Review the update
    agent:
      prompt: |
        Review the updated inputs. Run the relevant checks and fix regressions.

  - id: authorize
    name: Authorize deployment
    approval:
      prompt: Deploy the reviewed revisions to production?

  - id: deploy
    name: Deploy the fleet
    host-command:
      command: deploy-fleet
      parameters:
        environment: production
```

Open **Workspace → Automations** to inspect parsed definitions, start a workflow,
resolve approval steps, cancel an execution, and review its retained output.
Five-field cron expressions run in UTC. The scheduler starts a stopped workspace
on demand when the execution first needs its guest daemon. It does not backfill
scheduled times missed while hostd was unavailable.

## Execution Ownership

The host daemon (`hostd`) owns admission, scheduling, concurrency, timeouts,
approval state, execution history, and output history. The workspace guest
daemon (`guestd`) and pod daemon (`podd`) continue to supervise the pod and its
processes through their existing APIs.

Each execution receives one pod. Command steps, host-command helpers, and agent
steps therefore share the same writable workspace state. The pod remains after
the execution finishes so its files can be inspected. Before Tascarrel records
one of those steps as successful, it flushes the pod filesystem so later steps
can rely on its writes after a host restart. A definition edit affects future
executions only.

The `concurrency.limit` value applies to executions of the same Automation in
the same workspace and must be between 1 and 64. An execution waiting for
approval or agent input continues to occupy a slot. `timeout-minutes` covers
running and waiting time and, when set, may be at most 525,600 minutes.

After a hostd restart, queued executions and approval gates remain actionable.
Hostd marks running command steps and agent turns as interrupted because their
in-flight effects cannot be resumed safely.

## Define Steps

Every step accepts `id`, `name`, and `continue-on-error`. Tascarrel generates an
ID when it is omitted. A step must contain exactly one operation.

### Run a Command

```yaml
- id: check
  run: nix flake check
  working-directory: infrastructure
  environment:
    RUST_BACKTRACE: "1"
```

Tascarrel passes `run` to `bash -lc`. Workspace environment values configured in
`config.toml` and `.env` remain available in the step process. Step-specific
environment values cannot replace `HOME` or names beginning with
`TASCARREL_AUTOMATION_`, which the runner reserves for its execution contract.
Command output is retained by hostd and written in full below
`$HOME/.local/state/tascarrel/automations/<execution-id>/<step-id>.log`
in the execution pod. The directory is part of the pod's durable root, so a
later step can still inspect earlier output after Tascarrel restarts.

### Run an Agent Turn

```yaml
- id: repair
  agent:
    prompt: Diagnose the failed checks and make them pass.
    harness: codex
    model: gpt-5
    options:
      reasoning-effort: high
```

An agent step must select a harness either on the step or through
`defaults.agent`. Tascarrel never falls back to the first authenticated harness
for an unattended workflow. A model is optional and uses the harness default
when omitted; model options require an explicit model.

All agent steps in one Automation share one Automation-owned chat and must use
the same harness. Individual turns may select different models. The prompt for
each turn lists the full-output paths of earlier command and host-command steps,
which lets the agent inspect results without copying arbitrary output into its
context.

When a harness requests human input, the execution enters **Waiting for Input**.
Open the agent from the execution detail, answer in its chat, and let the same
turn continue. Automation-owned chats do not appear among ordinary agent tabs.

### Run a Host Command

```yaml
- id: sign
  host-command:
    command: sign-release
    parameters:
      channel: stable
```

The command name and parameters refer to an existing `host-commands` definition
in `config.toml`. The step invokes `podctl` inside the execution pod and retains
the resulting host-operation ID. Repository capture, secret resolution,
approval, execution policy, and output handling remain under the existing
host-command implementation. Canceling the Automation also requests
cancellation of a discovered host operation.

### Wait for Approval

```yaml
- id: publish
  approval:
    prompt: Publish the signed artifact?
```

An approval step is durable host state. Tascarrel retains the decision, time,
and authenticated actor which resolved it. Approval resumes the next pending
step. Rejection fails the execution and skips remaining steps.

## Security Model

Automation YAML is trusted workspace configuration. A workflow can run commands
and coding agents with the same authority as an interactive task pod, including
any plaintext environment secrets deliberately exposed to that workspace.
Host-side HTTP secret injection continues to replace credentials only after a
matching request leaves the VM, so those credentials do not enter the
Automation pod.

Automations do not grant arbitrary host execution. A `host-command` step can
only invoke a command already declared in `config.toml`, and the existing host
operation policy and approval checks still apply. This keeps scheduled workflow
authority explicit in versioned configuration instead of placing unrestricted
host credentials in an external CI runner.

## Current Scope

The first Automation version is intentionally sequential. It does not provide
dependency graphs, matrix expansion, reusable workflows, SCM event triggers,
automatic retries, or a separate artifact store. Use command output files and
the shared execution pod when one step must pass data to another.
