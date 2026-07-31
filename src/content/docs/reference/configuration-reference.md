---
order: 1
description: Look up every supported server.toml, config.toml, and settings.json field.
---

# Configuration Reference

Tascarrel reads host-wide settings from
`$TASCARREL_HOME/config/server.toml` and workspace settings from each
workspace's `config.toml` and `settings.json`. Unknown fields are rejected.

## Server Configuration

The optional `server.toml` file uses `kebab-case` fields and is limited to
64 KiB. Hostd reads it at startup.

```toml
[remote-access]
public-origin = "https://tascarrel.example.com"

[authentication]
secret-file = "/run/secrets/tascarrel-auth"
```

| Field                         | Type and Default                | Purpose                                                  |
| ----------------------------- | ------------------------------- | -------------------------------------------------------- |
| `remote-access.public-origin` | HTTPS origin; unset             | Public UI origin and source of the HTTP-route DNS suffix |
| `authentication.secret-file`  | Path; generated key when absent | External private 32-byte browser-authentication key      |

Relative authentication key paths resolve beside `server.toml`. Restart hostd
after changing this file.

Workspace `config.toml` files use `kebab-case` fields and are limited to 4 MiB.

## Virtual Machine and Features

| Field                     | Type and Default                           | Purpose                              |
| ------------------------- | ------------------------------------------ | ------------------------------------ |
| `vm.cores`                | Positive integer; all available host cores | Virtual CPUs                         |
| `vm.memory`               | Binary size; one third of host memory      | VM memory, such as `"16G"`           |
| `vm.disk`                 | Binary size; `"1T"`                        | Sparse state disk; minimum 256 MiB   |
| `features.docker`         | Boolean; `false`                           | Confined Docker daemon in every pod  |
| `features.podman`         | Boolean; `false`                           | Rootless Podman in every pod         |
| `features.virtualization` | Boolean; `false`                           | `/dev/kvm` in every pod              |
| `features.usb`            | Boolean; `false`                           | Dynamic Linux-host USB forwarding    |
| `nix.daemon`              | Boolean; `false`                           | Persistent workspace-wide Nix daemon |

## Host Shares

| Field                | Type and Default                                | Purpose                                         |
| -------------------- | ----------------------------------------------- | ----------------------------------------------- |
| `shares.<name>.path` | Absolute or `~/`-relative path; required        | Host directory exposed at `/mnt/<name>` in pods |
| `shares.<name>.mode` | `ReadOnly`, `ReadWrite`, or `Overlay`; required | Pod access policy                               |

| Mode        | Behavior                                                                                              |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| `ReadOnly`  | Every pod receives an ownership-normalized, read-only view                                            |
| `ReadWrite` | Every pod reads and writes the host directory directly                                                |
| `Overlay`   | Every pod receives an isolated copy-on-write view whose changes require explicit inspection and apply |

Share names contain up to 64 ASCII letters, digits, `_`, or `-` and start with
a letter or digit. Tascarrel resolves and pins at most 32 shares when the VM
starts. Every mode exposes the share at `/mnt/<name>` in each pod.
`ReadOnly` and `ReadWrite` shares also appear at `/mnt/shares/<name>` in the VM.
Overlay changes are private to one pod and persist until they are applied or
the pod is deleted. Duplicate directories and paths overlapping Tascarrel's
configuration, state, or runtime trees are rejected. Share changes require a
workspace restart.

## Configure Tools and Processes

| Field                       | Type             | Purpose                                                                                 |
| --------------------------- | ---------------- | --------------------------------------------------------------------------------------- |
| `editors.code.extensions`   | Array of strings | Marketplace extensions installed before code-server starts                              |
| `chat.commands.<name>.text` | String           | Text inserted by a slash command                                                        |
| `env.<name>`                | String           | Default process environment value; secret references use `${secrets.<provider>.<name>}` |

Image `ENV` values have the lowest precedence, followed by `[env]`, `.env`, and
per-process values. Tascarrel-owned identity and service variables take final
precedence.

## Secrets

| Field                           | Type and Default                | Purpose                                     |
| ------------------------------- | ------------------------------- | ------------------------------------------- |
| `secrets.providers.<name>.kind` | `"sops"`                        | Select the current provider implementation  |
| `secrets.providers.<name>.file` | Relative path; `"secrets.json"` | SOPS-encrypted, string-valued JSON document |

Initial secrets supplied by the workspace creation page are encrypted before
the workspace is published. Hostd uses the user's default `id_ed25519` or
`id_rsa` SSH key pair and requires its private-key file to work
non-interactively.

## Setup and Initialization

| Field                  | Type and Default | Purpose                                                        |
| ---------------------- | ---------------- | -------------------------------------------------------------- |
| `setup.steps[].script` | String; required | Synchronous shell script run while preparing the reusable seed |
| `init.steps[].script`  | String; required | Shell script started for each new pod                          |
| `init.steps[].wait`    | Boolean; `false` | Wait for this init step before continuing                      |

## Caches and Repositories

| Field                   | Type                          | Purpose                                                            |
| ----------------------- | ----------------------------- | ------------------------------------------------------------------ |
| `caches[].name`         | String                        | Stable backing-subvolume name                                      |
| `caches[].path`         | Absolute or `~`-relative path | Read-write mount destination in every pod                          |
| `repos."<path>".source` | String                        | Upstream URL for the host-owned checkout below `/workspace/<path>` |
| `repos."<path>".branch` | Optional short branch name    | Branch checked out instead of the upstream default                 |
| `repos."<path>".git`    | Git policy table              | Complete repository-specific replacement for the workspace policy  |

Runtime-owned paths and overlapping cache destinations are rejected.

## Git Policy

| Field                    | Type and Default                                           | Purpose                                                 |
| ------------------------ | ---------------------------------------------------------- | ------------------------------------------------------- |
| `git.default-policy`     | `allow`, `deny`, or `require-approval`; `require-approval` | Action for unmatched refs                               |
| `git.branches[].pattern` | String                                                     | Case-sensitive glob matched against a short branch name |
| `git.branches[].policy`  | Policy string                                              | Action for the first matching branch rule               |
| `git.tags[].pattern`     | String                                                     | Case-sensitive glob matched against a short tag name    |
| `git.tags[].policy`      | Policy string                                              | Action for the first matching tag rule                  |

A single `*` stays within one slash-delimited component; `**` crosses
components.

## Host Commands

Host commands let authenticated workspace pods request narrowly configured
processes on the physical host. Every request captures an immutable execution
plan and requires host-side approval. The process runs as the Tascarrel host
user without a separate container or virtual machine.

```toml
[host-commands.deploy]
description = "Deploy one server from the captured infrastructure worktree"
program = "nix"
arguments = [
  "develop",
  "--command",
  "bash",
  "scripts/deploy.sh",
  "${parameters.host}",
]
working-directory = "${inputs.infrastructure}"
approval = "always"
timeout-seconds = 7200

[host-commands.deploy.parameters.host]
required = true
allowed-values = ["staging", "production"]

[host-commands.deploy.inputs.infrastructure]
repository = "infrastructure"
capture = "working-tree"

[host-commands.deploy.environment]
inherit = ["HOME", "SSH_AUTH_SOCK"]
```

| Field                                                   | Type and Default                     | Purpose                                                                 |
| ------------------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------- |
| `host-commands.<name>.description`                      | String; unset                        | Purpose shown to callers and approvers                                  |
| `host-commands.<name>.program`                          | String; required                     | Absolute executable or bare name resolved from hostd's `PATH`           |
| `host-commands.<name>.arguments`                        | Array of strings; empty              | Trusted arguments and complete parameter or input placeholders          |
| `host-commands.<name>.working-directory`                | String; private operation directory  | Absolute path, private relative path, or one complete input placeholder |
| `host-commands.<name>.approval`                         | `"always"`                           | Require approval for every request                                      |
| `host-commands.<name>.timeout-seconds`                  | Positive integer; unset              | Stop execution after the configured duration                            |
| `host-commands.<name>.parameters.<name>.required`       | Boolean; `true` without a default    | Require the caller to supply the parameter                              |
| `host-commands.<name>.parameters.<name>.default`        | String; unset                        | Value selected when the caller omits the parameter                      |
| `host-commands.<name>.parameters.<name>.allowed-values` | Non-empty array; unset               | Complete finite set of accepted values                                  |
| `host-commands.<name>.parameters.<name>.pattern`        | Rust regular expression; unset       | Pattern matched against the complete parameter value                    |
| `host-commands.<name>.inputs.<name>.repository`         | Configured repository path; required | Repository captured from the requesting pod                             |
| `host-commands.<name>.inputs.<name>.capture`            | Capture policy; `"working-tree"`     | Select `working-tree`, `clean-head`, `commit`, or `published-ref`       |
| `host-commands.<name>.environment.inherit`              | Array of environment names; empty    | Resolve hostd environment values immediately before execution           |
| `host-commands.<name>.environment.values`               | String map; empty                    | Add literal non-secret environment values                               |

Placeholders must occupy an entire argument or the entire working-directory
value. They use `${parameters.<name>}` or `${inputs.<name>}`. A
`working-tree` input includes staged, unstaged, and non-ignored untracked
files. A `published-ref` input accepts `HEAD` only when a remote-tracking ref
can reach it.

Hostd watches `config.toml`. Valid edits change the registered command catalog
and apply to new requests after a short debounce without restarting hostd or
the workspace VM. Existing operations retain the exact definition captured
when they were requested. Invalid edits leave the preceding valid catalog
active and expose a configuration error through command discovery.

## Network Policy

| Field                     | Type and Default                            | Purpose                                                            |
| ------------------------- | ------------------------------------------- | ------------------------------------------------------------------ |
| `network.host-ports`      | Integers or `"<host>:<pod>"` strings; empty | Host-loopback services made available at `host.tascarrel.internal` |
| `network.default`         | `allow` or `deny`; `allow`                  | Default egress action                                              |
| `network.allow-local`     | Boolean; `false`                            | Permit local, private, link-local, and host-interface addresses    |
| `network.allow-addresses` | Array of IP strings; empty                  | Addresses admitted when the default is deny                        |
| `network.deny-addresses`  | Array of IP strings; empty                  | Addresses always rejected                                          |
| `network.allow-hosts`     | Array of host patterns; empty               | HTTP hosts admitted when the default is deny                       |
| `network.deny-hosts`      | Array of host patterns; empty               | HTTP hosts always rejected                                         |
| `network.allow-ports`     | Array of ports; `[80, 443]`                 | Destination TCP ports available to pods                            |
| `network.http-ports`      | Array of ports; `[80]`                      | Ports interpreted as HTTP                                          |
| `network.https-ports`     | Array of ports; `[443]`                     | Ports interpreted as HTTPS                                         |

The host daemon reloads this table after a short debounce period. New TCP flows
receive the latest valid snapshot, while active flows retain their original
snapshot. An invalid edit leaves the last valid snapshot in effect. An
initially invalid configuration uses deny-all until it becomes valid.

Each `[[network.secret-injection]]` entry supports:

| Field         | Type and Default                       | Purpose                                                    |
| ------------- | -------------------------------------- | ---------------------------------------------------------- |
| `host`        | Host pattern; required                 | Exact host or subdomain pattern to match                   |
| `paths`       | Non-empty array of globs; every path   | Absolute request path patterns to match                    |
| `methods`     | Non-empty array of strings; required   | Case-sensitive methods admitted for matching host and path |
| `header`      | String; all eligible headers           | Limit placeholder lookup to one header                     |
| `placeholder` | String; inferred from the secret name  | Value to replace                                           |
| `secret`      | Provider-qualified reference; required | Host-owned value to insert                                 |

When a host matches one or more injection rules, the host proxy rejects a
request unless at least one matching rule lists its method and matches its
path. A rule without `paths` matches every path; an explicit array must contain
between one and 64 patterns, each at most 2,048 bytes. Every pattern starts with
`/`. Glob syntax supports `*`, `**`, `?`, character classes, and brace
alternatives. A single `*` does not cross `/`, while `**` does. Query strings
are ignored. A literal `/mcp` therefore admits only `/mcp`, while `/api/**`
admits its descendants. Only rules admitting the complete request participate
in secret injection.

## Portable Interface Settings

The host-owned `settings.json` file contains portable interface preferences,
including harness model preferences, a workspace Model Context Protocol (MCP)
server catalog, and Tasci's model catalog. It uses `camelCase` names and can be
edited through **Workspace → Settings**.

### Usage Cost Centers

The optional `usage` object declares workspace-local cost centers for chat
usage attribution:

```json
{
  "usage": {
    "defaultCostCenter": "client_alpha",
    "costCenters": {
      "client_alpha": {
        "name": "Client Alpha"
      },
      "internal_research": {
        "name": "Internal Research",
        "archived": true
      }
    }
  }
}
```

Cost-center IDs are stable keys containing 1–64 ASCII letters, numbers,
hyphens, or underscores. Their display names can be changed without changing
chat assignments. An archived cost center remains available for historical
attribution but cannot be the default for new chats.

Manage declarations and the default under **Workspace → Settings → Usage**.
The same page reports monthly token usage and locally calculated cost across
all projects in the workspace. A chat's current assignment applies to its
whole recorded history, including usage from archived chats; chats without an
assignment appear under **Unassigned**.

### Harness Model Preferences

The optional `chat.harnesses` object has `codex` and `claudeCode` entries. Each
entry supports:

| Field            | Purpose                                               |
| ---------------- | ----------------------------------------------------- |
| `defaultModel`   | Model and non-default options selected for new chats  |
| `modelOrder`     | Model identifiers placed first in the specified order |
| `hiddenModels`   | Models omitted from ordinary selection controls       |
| `favoriteModels` | Models shown before other visible models              |

### MCP Servers

The optional `chat.mcpServers` object declares Streamable HTTP servers once for
the workspace. Each server applies to every coding harness unless its
`harnesses` array selects a subset:

```json
{
  "chat": {
    "mcpServers": {
      "exa": {
        "displayName": "Exa",
        "endpoint": "https://mcp.exa.ai/mcp"
      },
      "private-tools": {
        "endpoint": "https://mcp.example.com/mcp",
        "headers": {
          "Authorization": "Bearer tascarrel-secret:mcp-api-token",
          "X-Workspace": "development"
        },
        "harnesses": ["Tasci", "ClaudeCode"]
      }
    }
  }
}
```

An MCP server supports:

| Field         | Purpose                                                                        |
| ------------- | ------------------------------------------------------------------------------ |
| `displayName` | Optional interface label                                                       |
| `endpoint`    | Absolute Streamable HTTP URL without credentials, a query, or a fragment       |
| `headers`     | Optional map of HTTP header names to non-secret, placeholder-bearing templates |
| `harnesses`   | Optional nonempty subset of `Tasci`, `Codex`, and `ClaudeCode`                 |

Omitting `harnesses` selects all three harnesses. Tascarrel resolves the
selection when it starts or attaches a harness session, so an existing session
keeps its original MCP catalog.

The map key becomes the native MCP server name. Tasci exposes model-visible tool
names as `mcp__<server>__<tool>`; Codex and Claude Code retain their native tool
naming. Configuring a server trusts all tools and descriptions it advertises.
Header values may use any valid HTTP header text, including placeholders
handled by `network.secret-injection`.

This portable catalog deliberately covers the shared provider intersection:
remote Streamable HTTP endpoints and static header templates. Configure local
standard-I/O servers and provider-specific MCP features through the harness's
native configuration when required.

### Tasci Model Preferences and Endpoints

Tasci is bundled with Tascarrel. Its `chat.tasci` settings map workspace-local
model aliases to OpenAI-compatible Chat Completions endpoints:

```json
{
  "chat": {
    "tasci": {
      "defaultModel": "development",
      "modelOrder": ["development"],
      "favoriteModels": ["development"],
      "endpoints": {
        "local": {
          "protocol": "OpenAiChatCompletions",
          "baseUrl": "http://host.tascarrel.internal:18080/v1"
        },
        "host-injected": {
          "protocol": "OpenAiChatCompletions",
          "baseUrl": "https://api.example.com/v1",
          "authorization": {
            "header": "Authorization",
            "value": "Bearer tascarrel-secret:model-api-token"
          }
        }
      },
      "models": {
        "development": {
          "endpoint": "local",
          "model": "provider-model-id",
          "displayName": "Development Model",
          "toolCalls": true
        }
      }
    }
  }
}
```

The Tasci object supports:

| Field            | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| `defaultModel`   | Model alias selected for new chats                   |
| `modelOrder`     | Model aliases placed first in the specified order    |
| `hiddenModels`   | Models omitted from ordinary selection controls      |
| `favoriteModels` | Models shown before other visible models             |
| `endpoints`      | Inference endpoints keyed by workspace-local aliases |
| `models`         | Selectable models keyed by workspace-local aliases   |

An endpoint supports:

| Field           | Purpose                                                                    |
| --------------- | -------------------------------------------------------------------------- |
| `displayName`   | Optional interface label                                                   |
| `protocol`      | `OpenAiChatCompletions`; the only currently supported protocol             |
| `baseUrl`       | Absolute HTTP or HTTPS API URL without credentials, a query, or a fragment |
| `authorization` | Optional non-secret authorization header template                          |

An authorization template supplies the header and a placeholder-bearing value:

```json
{
  "header": "Authorization",
  "value": "Bearer tascarrel-secret:model-api-token"
}
```

The template is not a credential. Configure a matching
`network.secret-injection` rule in `config.toml`; the host proxy replaces the
placeholder after the request leaves the workspace. Tasci never receives the
secret. Older `prefix` and `credential` settings remain readable for migration,
but Tascarrel converts them into the default `tascarrel-secret:<name>`
placeholder instead of resolving the referenced secret.

A model supports:

| Field               | Purpose                                              |
| ------------------- | ---------------------------------------------------- |
| `endpoint`          | Alias of the endpoint that serves the model          |
| `model`             | Provider-native model identifier                     |
| `displayName`       | Optional interface label                             |
| `contextWindow`     | Positive context limit used for automatic compaction |
| `maxOutputTokens`   | Positive request output limit and compaction reserve |
| `toolCalls`         | Whether the model supports structured tool calls     |
| `parallelToolCalls` | Whether it supports parallel structured calls        |
| `pricing`           | Optional versioned token prices for cost calculation |

Tasci automatically projects streamed `reasoning_content` from compatible
endpoints and retains it in assistant history. It requests streamed usage
metadata from compatible endpoints. When `contextWindow` is configured, Tasci
uses reported usage when available and a conservative text estimate otherwise
to trigger context compaction before later requests overflow.

Model selectors qualify each model name with its endpoint display name, such
as `GLM 5.2 (Melious)`. The endpoint alias is used when no display name is
configured.

`pricing` contains `catalogVersion`, a positive `tokenCount`, required `input`
and `output` monetary amounts, and optional `cacheReadInput` and
`cacheWriteInput` amounts. Each amount has an ISO 4217 `currency` and an integer
`amount` in that currency's minor unit.
