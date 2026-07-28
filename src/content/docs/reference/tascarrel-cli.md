---
order: 2
description: Look up the host CLI, environment overrides, and retained host data.
---

# Tascarrel Executables

The `tascarrel` executable runs the server. The `tascarrelctl` executable
covers installation, diagnostics, service management, and workspace VM
lifecycle. Pod creation and development work happen in the UI.

## Run the Server

```text
tascarrel [SERVER OPTIONS]
```

The server binds its startup and application UI to
<http://127.0.0.1:8272>. It publishes host checks, payload extraction progress,
and actionable startup failures before initializing workspace services.

## Administrative CLI

```text
tascarrelctl [--socket <PATH>] <COMMAND>
```

The global `--socket` option selects a non-default host control socket and can
also be supplied as `TASCARREL_SOCKET`.

## Maintain Tascarrel

| Command                                  | Behavior                                                                       |
| ---------------------------------------- | ------------------------------------------------------------------------------ |
| `tascarrelctl install [--server <PATH>]` | Install a server executable and register the per-user service                  |
| `tascarrelctl doctor`                    | Check host architecture, QEMU, acceleration, Git, SOPS, and service management |
| `tascarrelctl doctor --json`             | Emit the diagnostic report as JSON                                             |

## Workspaces

| Command                                        | Behavior                                                                  |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| `tascarrelctl workspace list`                  | Print configured workspace names                                          |
| `tascarrelctl workspace create <NAME>`         | Create a workspace with the default Debian development image              |
| `tascarrelctl workspace start <NAME>`          | Start its VM and wait until it is ready                                   |
| `tascarrelctl workspace stop <NAME>`           | Stop its VM while preserving pods and configuration                       |
| `tascarrelctl workspace info <NAME>`           | Show current VM state or startup failure                                  |
| `tascarrelctl workspace info <NAME> --json`    | Emit the complete workspace record as JSON                                |
| `tascarrelctl workspace delete <NAME>`         | Stop and permanently delete the workspace and all pods after confirmation |
| `tascarrelctl workspace delete <NAME> --force` | Delete without interactive confirmation                                   |

## Daemon

| Command                             | Behavior                                           |
| ----------------------------------- | -------------------------------------------------- |
| `tascarrelctl daemon start`         | Start the installed per-user service               |
| `tascarrelctl daemon stop`          | Stop it                                            |
| `tascarrelctl daemon restart`       | Restart it                                         |
| `tascarrelctl daemon status`        | Show service-manager status and fail when inactive |
| `tascarrelctl daemon logs`          | Show recent service logs                           |
| `tascarrelctl daemon logs --follow` | Continue displaying new log messages               |

Run `tascarrelctl <COMMAND> --help` for the exact syntax supported by the
installed version.

## Host Environment

| Variable                   | Purpose                                                                             |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `TASCARREL_HOME`           | Absolute configuration and state root; the installer defaults to `$HOME/.tascarrel` |
| `TASCARREL_SOCKET`         | Override the local host control socket                                              |
| `TASCARREL_QEMU`           | Select the QEMU system executable                                                   |
| `TASCARREL_GIT`            | Select the host Git executable                                                      |
| `TASCARREL_SOPS`           | Select the host SOPS executable                                                     |
| `TASCARREL_WEB_ADDRESS`    | Override the UI address                                                             |
| `TASCARREL_HOST_PORT_HOST` | Select the outer host for configured workspace host-port mappings                   |

A binary run without the installer defaults `TASCARREL_HOME` to `.tascarrel` in
the current directory.

The server installer also accepts `TASCARREL_VERSION`,
`TASCARREL_SOPS_VERSION`, `TASCARREL_GITHUB_REPOSITORY`, and
`TASCARREL_RELEASE_BASE_URL`. It places the server and CLI executables in
`$HOME/.local/bin`.

## Host Data

```text
$TASCARREL_HOME/
├── config/
│   └── workspaces/<name>/
├── state/
│   ├── payloads/<sha256>/
│   ├── runtime/
│   │   └── control.sock
│   └── workspaces/<name>/
```

The `config` directory contains editable inputs. The `state/payloads` directory
contains verified embedded assets, `state/runtime` contains transient sockets,
and `state/workspaces` contains persistent VM state. Do not edit state while the
service is running.
