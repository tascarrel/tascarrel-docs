---
order: 1
description: Run Tascarrel as an installed service, in the foreground, or through the experimental desktop app.
---

# Run the Host Service

Tascarrel's server owns workspace VMs and serves both the startup page and
application UI. The recommended installation runs it as a per-user service.
The experimental desktop application starts the same server on demand.

## Use the Installed Service

```console
tascarrelctl daemon start
tascarrelctl daemon status
```

The UI is available at <http://tascarrel.localhost:8272> by default. The installed
service uses a systemd user unit on Linux or a LaunchAgent on macOS.

```console
tascarrelctl daemon restart
tascarrelctl daemon stop
```

Use the installed service when the server should start independently of the
desktop app or browser.

## Use the Experimental Desktop Application

Open **Tascarrel** from the application launcher. Opening it again focuses the
existing window. Closing the window leaves the server and workspace VMs
running, so reopening the app reconnects to the same state.

The startup page appears immediately after the server begins listening. It
reports host capability checks, payload validation and extraction, service
initialization, and actionable failures such as missing QEMU. A failed
retryable check can be repeated from the page.

## Run the Server in the Foreground

```console
tascarrel
```

Open <http://tascarrel.localhost:8272> in a browser. The same server-hosted startup page
appears before the application is ready. Stop the installed service first
because two server processes cannot share the same runtime or web address.

## Inspect Service Logs

```console
tascarrelctl daemon logs
tascarrelctl daemon logs --follow
```

Run `tascarrelctl doctor` when the server cannot create its startup listener.
Use `tascarrelctl workspace info <name>` for the current VM state or startup
failure.

The CLI normally discovers the service through Tascarrel's control socket. Use
the global `--socket <path>` option, or `TASCARREL_SOCKET`, only for an
intentionally non-default runtime.
