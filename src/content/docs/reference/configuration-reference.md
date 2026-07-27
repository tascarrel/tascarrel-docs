---
order: 1
description: Look up every supported config.toml and settings.json field.
---

# Configuration Reference

Tascarrel reads a workspace's declarative settings from `config.toml`. Field
names use `kebab-case`, unknown fields are rejected, and the file is limited to
4 MiB.

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
| `authorization` | Optional secret-backed authorization header                                |

The token stays out of `settings.json`; authorization refers to a configured
secret:

```json
{
  "header": "Authorization",
  "prefix": "Bearer ",
  "credential": {
    "provider": "project",
    "secret": "MODEL_API_TOKEN"
  }
}
```

Tascarrel resolves that secret only for a selected Tasci session and delivers
the complete header to its private pod process.

A model supports:

| Field               | Purpose                                              |
| ------------------- | ---------------------------------------------------- |
| `endpoint`          | Alias of the endpoint that serves the model          |
| `model`             | Provider-native model identifier                     |
| `displayName`       | Optional interface label                             |
| `contextWindow`     | Optional positive context-window metadata            |
| `maxOutputTokens`   | Optional positive output-limit metadata              |
| `toolCalls`         | Whether the model supports structured tool calls     |
| `parallelToolCalls` | Whether it supports parallel structured calls        |
| `pricing`           | Optional versioned token prices for cost calculation |

`pricing` contains `catalogVersion`, a positive `tokenCount`, required `input`
and `output` monetary amounts, and optional `cacheReadInput` and
`cacheWriteInput` amounts. Each amount has an ISO 4217 `currency` and an integer
`amount` in that currency's minor unit.
