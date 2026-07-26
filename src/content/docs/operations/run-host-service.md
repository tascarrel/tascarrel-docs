---
order: 1
description: Run Tascarrel as an installed service or foreground app and inspect its logs.
---

# Run the Host Service

Tascarrel's host service owns workspace VMs and serves the UI. Run it
as an installed per-user daemon or as a foreground app.

## Use the Installed Service

```console
tascarrel daemon start
tascarrel daemon status
```

The UI is available at <http://127.0.0.1:8272> by default. The installed
service uses a systemd user unit on Linux or a LaunchAgent on macOS.

```console
tascarrel daemon restart
tascarrel daemon stop
```

Use the daemon when work should continue after closing the web browser.

## Use the Foreground App

```console
tascarrel app
```

App mode starts the service in the foreground and opens a dedicated browser
window. Stop the installed daemon first because the two modes cannot share a
runtime. Closing the app stops its workspace VMs.

## Inspect Service Logs

```console
tascarrel daemon logs
tascarrel daemon logs --follow
```

Run `tascarrel doctor` when the service cannot start or a VM fails before the
UI becomes available. Use `tascarrel workspace info <name>` for the current
VM state or startup failure.

The CLI normally discovers the service through Tascarrel's control socket. Use
the global `--socket <path>` option, or `TASCARREL_SOCKET`, only for an
intentionally non-default runtime.
