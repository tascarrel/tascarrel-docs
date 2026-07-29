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

| Field                    | Type and Default                         | Purpose                                             |
| ------------------------ | ---------------------------------------- | --------------------------------------------------- |
| `shares.<name>.path`     | Absolute or `~/`-relative path; required | Host directory exposed at `/mnt/<name>` in pods     |
| `shares.<name>.writable` | Boolean; `false`                         | Permit the VM and pods to modify the host directory |

Share names contain up to 64 ASCII letters, digits, `_`, or `-` and start with
a letter or digit. Tascarrel resolves and pins at most 32 shares when the VM
starts. Each directory appears at `/mnt/shares/<name>` in the VM and through an
idmapped bind at `/mnt/<name>` in every pod. Duplicate directories and paths
overlapping Tascarrel's configuration, state, or runtime trees are rejected.
Share changes require a workspace restart.

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

| Field         | Type and Default                       | Purpose                                                 |
| ------------- | -------------------------------------- | ------------------------------------------------------- |
| `host`        | Host pattern; required                 | Exact host or subdomain pattern to match                |
| `methods`     | Non-empty array of strings; required   | Case-sensitive HTTP methods admitted for matching hosts |
| `header`      | String; all eligible headers           | Limit placeholder lookup to one header                  |
| `placeholder` | String; inferred from the secret name  | Value to replace                                        |
| `secret`      | Provider-qualified reference; required | Host-owned value to insert                              |

When a host matches one or more injection rules, the host proxy rejects a
request unless at least one matching rule lists its method. Only rules listing
the request method participate in secret injection.

## Portable Interface Settings

The host-owned `settings.json` file contains portable interface preferences and
the Tasci model catalog. It uses `camelCase` names and can be edited through
**Workspace → Settings**.

### Harness Model Preferences

The optional `chat.harnesses` object has `codex` and `claudeCode` entries. Each
entry supports:

| Field            | Purpose                                               |
| ---------------- | ----------------------------------------------------- |
| `defaultModel`   | Model and non-default options selected for new chats  |
| `modelOrder`     | Model identifiers placed first in the specified order |
| `hiddenModels`   | Models omitted from ordinary selection controls       |
| `favoriteModels` | Models shown before other visible models              |

### Tasci Endpoints and Models

Tasci is bundled with Tascarrel. Its `chat.tasci` settings map workspace-local
model aliases to OpenAI-compatible Chat Completions endpoints:

```json
{
  "chat": {
    "tasci": {
      "defaultModel": "development",
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
