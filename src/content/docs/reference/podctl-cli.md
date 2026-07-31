---
order: 3
description: Inspect and control the current pod from scripts running inside it.
---

# `podctl` CLI

The `podctl` command is installed inside every pod. Its private socket already
identifies the current workspace and pod; a caller cannot use it to select a
different pod.

## Identity and Lifecycle

| Command                | Behavior                                                    |
| ---------------------- | ----------------------------------------------------------- |
| `podctl identity`      | Print the authenticated workspace and pod identity          |
| `podctl title <TITLE>` | Set the pod's human-readable title                          |
| `podctl destroy`       | Destroy the current pod and all of its persistent resources |

## Processes and Chats

| Command                                                | Behavior                                           |
| ------------------------------------------------------ | -------------------------------------------------- |
| `podctl processes list`                                | Print processes belonging to this pod              |
| `podctl processes snapshot <PROCESS_ID>`               | Capture the current screen of a terminal process   |
| `podctl processes kill <PROCESS_ID>`                   | Send the default terminate signal                  |
| `podctl processes kill <PROCESS_ID> --signal <SIGNAL>` | Send `terminate`, `kill`, `hangup`, or `interrupt` |
| `podctl chats list`                                    | Print chats belonging to this pod                  |
| `podctl chats show <CHAT_ID>`                          | Print one chat and its current timeline            |

Commands that return structured data emit JSON.

## Host Operations

Workspace configuration may register trusted commands which execute on the
physical host after host-side approval.

| Command                                                  | Behavior                                                    |
| -------------------------------------------------------- | ----------------------------------------------------------- |
| `podctl host operations commands`                        | Print the current caller-visible registered command catalog |
| `podctl host operations run <COMMAND>`                   | Request a registered command and follow it to completion    |
| `podctl host operations run <COMMAND> -p <NAME>=<VALUE>` | Supply one validated parameter; repeat `-p` as needed       |
| `podctl host operations list`                            | Print durable operations initiated by this pod              |
| `podctl host operations cancel <OPERATION_ID>`           | Withdraw an unapproved request or stop its active process   |

`podctl host operations commands` reports each command's description, trusted
program and argument templates, parameter validation, repository inputs,
environment names without their values, and timeout. It also reports a
configuration error when an invalid edit leaves the preceding valid catalog
active. Valid `config.toml` edits appear after a short debounce without
restarting the workspace.

## Overlay Share Approvals

An `Overlay` host share retains filesystem changes in the current pod until a
host client approves an exact revision. Submit the current revision after
finishing the proposed changes:

```console
podctl shares submit source
```

| Command                              | Behavior                                                         |
| ------------------------------------ | ---------------------------------------------------------------- |
| `podctl shares submit <SHARE>`       | Create a durable approval request for the exact current revision |
| `podctl shares list`                 | Print this pod's pending overlay approval requests               |
| `podctl shares cancel <APPROVAL_ID>` | Withdraw a request while retaining every overlay change          |

Submitting the same revision again returns its existing request. If the pod
changes the overlay while that request is pending, cancel it before submitting
the new revision. Approval applies only the submitted revision; a changed
revision or a concurrent host edit leaves the complete overlay intact.

## Host-Loopback Port Forwards

| Command                                       | Behavior                                                                    |
| --------------------------------------------- | --------------------------------------------------------------------------- |
| `podctl ports publish <PORT>`                 | Expose a pod TCP port on an assigned host-loopback port and print that port |
| `podctl ports publish <PORT> --title <TITLE>` | Add a label in the interface                                                |
| `podctl ports publish <PORT> --tab`           | Also create a visible HTTP route                                            |
| `podctl ports list`                           | Print this pod's dynamic forwards                                           |
| `podctl ports unpublish <PORT>`               | Remove the forward for that pod port                                        |

## HTTP Routes

| Command                                      | Behavior                                               |
| -------------------------------------------- | ------------------------------------------------------ |
| `podctl http publish <PORT>`                 | Create or update a route and print its hostname prefix |
| `podctl http publish <PORT> --title <TITLE>` | Set the visible title                                  |
| `podctl http publish <PORT> --internal`      | Keep the route out of ordinary visible pod tabs        |
| `podctl http list`                           | Print this pod's routes                                |
| `podctl http unpublish <ROUTE>`              | Remove a route by pod port or route identifier         |
