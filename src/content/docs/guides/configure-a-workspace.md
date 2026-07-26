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
│   └── skills/
├── overlay/             # Optional
├── hooks/
│   ├── setup/           # Optional
│   └── init/            # Optional
└── .env                 # Optional
```

The installer defaults `TASCARREL_HOME` to `$HOME/.tascarrel`.
`config.toml` is limited to 4 MiB and rejects unknown or malformed fields.
See the [configuration reference](/docs/reference/configuration-reference) for
the complete schema.

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
Claude Code preferences under **Settings → Harnesses** and Tasci endpoints and
models under **Settings → Tasci**.

Configuration that changes the VM requires a restart. Image, seed, and
initialization changes apply to newly created pods after their inputs are
rebuilt.
