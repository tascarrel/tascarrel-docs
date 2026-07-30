---
order: 1
description: Configure workspace resources, files, environment values, caches, and editor settings.
---

# Configure a Workspace

Tascarrel owns one configuration directory for each workspace and exposes its
files through **Workspace → Settings**:

```text
$TASCARREL_HOME/config/workspaces/<name>/
├── config.toml
├── settings.json
├── image/
│   └── Dockerfile
├── agents/
│   ├── AGENTS.md
│   ├── CLAUDE.md -> AGENTS.md
│   └── skills/
├── automations/         # Optional durable workflow definitions
│   └── example.yaml
├── .sops.yaml            # Optional SOPS policy
├── secrets.json          # Optional SOPS-encrypted values
├── overlay/             # Optional
├── hooks/
│   ├── setup/           # Optional
│   └── init/            # Optional
└── .env                 # Optional
```

The installer defaults `TASCARREL_HOME` to `$HOME/.tascarrel`.
`config.toml` is limited to 4 MiB and rejects unknown or malformed fields.
See the [configuration reference](/docs/reference/configuration-reference) for
the complete `config.toml` schema. See
[Automate Workspace Workflows](/docs/guides/automate-workspace-workflows) for
the Automation YAML schema.

When a workspace is created through the UI, the setup page generates
`config.toml`, `image/Dockerfile`, and `agents/AGENTS.md` from the selected
repositories, runtimes, capabilities, developer services, resources, and
network policy. It creates `agents/CLAUDE.md` as a relative symlink to
`AGENTS.md`, giving Claude Code the same workspace guidance.
These files remain ordinary workspace configuration and can be edited here
afterward. The generated agent guidance explains repository instruction
precedence and how to publish HTTP development servers. It recommends Nix for
ad-hoc tools only when the Nix daemon is selected. Initial developer-service
tokens are supplied separately and encrypted before the workspace is
published; they never appear in the generated files. Tascarrel supplies its
interactive shell separately, so the generated image does not install or
configure a shell.

## Size the Workspace VM

```toml
[vm]
cores = 8
memory = "16G"
disk = "200G"
```

Without overrides, Tascarrel uses all available host CPU cores, one third of
host memory, and a 1 TiB sparse disk. Increasing `disk` grows existing state;
decreasing it does not shrink the disk. Resource changes require a workspace
restart.

## Share a Host Directory

Named shares explicitly expose host directories to the workspace VM and every
pod:

```toml
[shares.source]
path = "~/src/product"

[shares.generated]
path = "/srv/product/generated"
writable = true
```

A share is read-only unless `writable = true` is set. Tascarrel presents an
ownership-normalized view at `/mnt/shares/<name>` in the VM and exposes it
through an idmapped bind at `/mnt/<name>` in each pod. It does not change the
host directory's ownership.

Paths must be absolute or begin with `~/`, must resolve to directories, and
cannot overlap Tascarrel's configuration, state, or runtime directories.
Changing shares requires a workspace restart because the host pins the resolved
paths while it creates the VM. A writable share deliberately crosses the main
VM isolation boundary; only share directories whose contents every pod in the
workspace may modify.

## Set the Process Environment

Declare non-sensitive values in `config.toml`:

```toml
[env]
NODE_ENV = "development"
RUST_BACKTRACE = "1"
```

The optional `.env` file overrides image `ENV` and `[env]` values. Per-process
values override `.env`; Tascarrel-owned identity and service variables have
final precedence. A fresh `.env` snapshot is read whenever a process starts.

Use [host-owned secrets](/docs/guides/manage-secrets) instead of storing
plaintext credentials.

## Add Seed Files

Files below `overlay/` are copied into `/workspace` while the reusable seed is
prepared:

```text
overlay/
└── product/
    └── local.example.toml
```

Overlay content becomes ordinary pod data and is visible to coding agents.

## Share a Cache

```toml
[[caches]]
name = "pnpm-store"
path = "~/.cache/pnpm"
```

The named cache persists across pod lifetimes and is mounted read-write into
every pod in the workspace. Any pod can modify or poison it, so never use a
shared cache for secrets or mutually untrusted work.

## Configure the Web Editor

```toml
[editors.code]
extensions = [
  "dbaeumer.vscode-eslint",
  "rust-lang.rust-analyzer",
]
```

The Code view uses a workspace-level profile, so settings and extensions are
reused across pods. Model preferences live in `settings.json`. Edit Codex and
Claude Code preferences under **Settings → Harnesses**, shared Model Context
Protocol (MCP) servers under **Settings → MCP**, and Tasci endpoints and models
under **Settings → Tasci**.

Configuration that changes the VM requires a restart. Image, seed, and
initialization changes apply to newly created pods after their inputs are
rebuilt.
