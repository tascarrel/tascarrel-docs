---
order: 1
description: Learn how Tascarrel uses isolated development environments to let coding agents work safely without babysitting.
---

# Tascarrel Documentation

Tascarrel is an agentic development workbench that lets agents work safely
without babysitting. You declare each development context—its repositories,
tools, resources, and access policies—and Tascarrel runs it in a workspace
virtual machine isolated from your host and other workspaces. Within that
[safety boundary](/docs/getting-started/isolation-model), agents can use broad
permissions in disposable task pods instead of stopping for command-by-command
approvals. Each pod has its own writable files, processes, and network namespace,
so agents working in parallel do not trip over one another. The UI keeps you
on top of their sessions, shows what needs your attention, and lets you review
changes before publishing them through Git.

:::warning[Active Development]

Tascarrel is under active development. Things may break, and its security
properties have not been independently audited.

:::

## Start Here

Start with the practical path:

1. [Install Tascarrel](/docs/getting-started/installation) prepares the host.
2. [Run Your First Task](/docs/getting-started/quickstart) covers the complete
   workflow and UI.
3. [Choose the Right Boundary](/docs/getting-started/choose-the-right-boundary)
   explains when to create a workspace or a pod.

## Common Tasks

- [Configure a Workspace](/docs/guides/configure-a-workspace)
- [Work with Coding Agents](/docs/guides/work-with-coding-agents)
- [Review and Publish Changes](/docs/guides/review-and-publish-changes)
- [Control Network Access](/docs/guides/control-network-access)
- [Maintain Workspace State](/docs/operations/maintain-workspace-state)
- [Troubleshoot Tascarrel](/docs/operations/troubleshooting)

Use [`tascarrelctl`](/docs/reference/tascarrel-cli) for host maintenance
and [`podctl`](/docs/reference/podctl-cli) for pod-scoped automation.
