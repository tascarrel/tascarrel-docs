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
