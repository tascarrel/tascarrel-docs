---
order: 2
description: Look up the host CLI, environment overrides, and retained host data.
---

# `tascarrel` CLI

The host CLI covers installation, diagnostics, service management, and
workspace VM lifecycle. Pod creation and development work happen in the
UI.

## Global Option

```text
tascarrel [--socket <PATH>] <COMMAND>
```

The `--socket` option selects a non-default host control socket and can also be
supplied as `TASCARREL_SOCKET`.

## Maintain Tascarrel

| Command                   | Behavior                                                                                        |
| ------------------------- | ----------------------------------------------------------------------------------------------- |
| `tascarrel app`           | Run a foreground daemon and open the UI in a dedicated browser window                           |
| `tascarrel install`       | Check dependencies, install the executable and guest payload, and register the per-user service |
| `tascarrel doctor`        | Check host architecture, QEMU, acceleration, Git, service management, and optional SOPS         |
| `tascarrel doctor --json` | Emit the diagnostic report as JSON                                                              |

## Workspaces

| Command                                     | Behavior                                                                  |
| ------------------------------------------- | ------------------------------------------------------------------------- |
| `tascarrel workspace list`                  | Print configured workspace names                                          |
| `tascarrel workspace create <NAME>`         | Create a workspace with the default Debian development image              |
| `tascarrel workspace start <NAME>`          | Start its VM and wait until it is ready                                   |
| `tascarrel workspace stop <NAME>`           | Stop its VM while preserving pods and configuration                       |
| `tascarrel workspace info <NAME>`           | Show current VM state or startup failure                                  |
| `tascarrel workspace info <NAME> --json`    | Emit the complete workspace record as JSON                                |
| `tascarrel workspace delete <NAME>`         | Stop and permanently delete the workspace and all pods after confirmation |
| `tascarrel workspace delete <NAME> --force` | Delete without interactive confirmation                                   |

## Daemon

| Command                          | Behavior                                           |
| -------------------------------- | -------------------------------------------------- |
| `tascarrel daemon start`         | Start the installed per-user service               |
| `tascarrel daemon stop`          | Stop it                                            |
| `tascarrel daemon restart`       | Restart it                                         |
| `tascarrel daemon status`        | Show service-manager status and fail when inactive |
| `tascarrel daemon logs`          | Show recent service logs                           |
| `tascarrel daemon logs --follow` | Continue displaying new log messages               |

Run `tascarrel <COMMAND> --help` for the exact syntax supported by the installed
version.

## Host Environment

| Variable                   | Purpose                                                                             |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `TASCARREL_HOME`           | Absolute configuration and state root; the installer defaults to `$HOME/.tascarrel` |
| `TASCARREL_SOCKET`         | Override the local host control socket                                              |
| `TASCARREL_QEMU`           | Select the QEMU system executable                                                   |
| `TASCARREL_GIT`            | Select the host Git executable                                                      |
| `TASCARREL_SOPS`           | Select the host SOPS executable                                                     |
| `TASCARREL_APP_BROWSER`    | Select the browser executable used by app mode                                      |
| `TASCARREL_WEB_ADDRESS`    | Override the UI address                                                             |
| `TASCARREL_HOST_PORT_HOST` | Select the outer host for configured workspace host-port mappings                   |

A binary run without the installer defaults `TASCARREL_HOME` to `.tascarrel` in
the current directory.

The installer also accepts `TASCARREL_VERSION`,
`TASCARREL_GITHUB_REPOSITORY`, and `TASCARREL_RELEASE_BASE_URL`. It places the
executable in `$HOME/.local/bin`.

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

`config` contains editable inputs. `state/payloads` contains verified embedded
assets, `state/runtime` contains transient sockets, and `state/workspaces`
contains persistent VM state. Do not edit state while the service is running.
