---
order: 7
description: Store secrets on the host and expose them through explicit environment or HTTP rules.
---

# Manage Secrets

The current secret provider uses a SOPS-encrypted JSON document and host
credentials, keeping the decryption key outside the workspace VM.

```toml
[secrets.providers.project]
kind = "sops"
file = "secrets.json"
```

The path is relative to the workspace configuration directory and defaults to
`secrets.json`. The decrypted document must be an object with string values.
Use **Workspace → Settings → Secrets** to reveal, set, or delete values.

## Expose a Process Variable

```toml
[env]
API_TOKEN = "${secrets.project.API_TOKEN}"
```

Environment interpolation deliberately exposes plaintext to workspace
processes. The value is resolved at workspace startup, so provider or reference
configuration changes require a restart.

## Use Secretless HTTP Authentication

Keep the credential value on the host by sending a placeholder:

```toml
[[network.secret-injection]]
host = "api.example.com"
methods = ["GET", "HEAD"]
header = "authorization"
placeholder = "replace-with-api-token"
secret = "project.API_TOKEN"
```

Tascarrel replaces the placeholder in matching `GET` and `HEAD` HTTP/1.1
requests after they leave the workspace, so the credential never enters the
workspace VM. It rejects other methods for `api.example.com` at the host proxy.
HTTPS uses a per-workspace CA installed into common certificate bundles.

Set `header` whenever possible; otherwise, Tascarrel checks every eligible
non-routing header. Every injection rule must list at least one syntactically
valid, case-sensitive HTTP method. Host rules accept an exact name or
`*.example.com` pattern. When several rules match a host, a method is admitted
if at least one of those rules lists it, and only rules listing that method can
inject. Updating a value in an existing provider takes effect on the next
matching request without restarting the VM.

## Authenticate a Tasci Endpoint

Configure Tasci endpoint authorization under **Workspace → Settings → Tasci**.
The endpoint refers to a host-owned provider and secret instead of storing the
token in `settings.json`.

Tascarrel resolves the token when starting or changing a Tasci model and passes
the complete authorization header only to that pod's private Tasci process.
Unlike HTTP secret injection, the credential therefore enters the workspace VM
and selected pod.
