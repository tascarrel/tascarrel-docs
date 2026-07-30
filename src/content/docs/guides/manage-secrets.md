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

## Initialize Developer-Service Tokens

The workspace creation page can install GitHub CLI (`gh`) or GitLab CLI
(`glab`) and initialize its token. Use a GitHub token with read-only
permissions or a GitLab token with the `read_api` scope. Tascarrel cannot
validate the token's authority without contacting the provider, so the selected
permissions remain your responsibility.

Hostd selects `$HOME/.ssh/id_ed25519.pub`, falling back to
`$HOME/.ssh/id_rsa.pub`, and writes the corresponding SSH recipient into
`.sops.yaml`. It encrypts the values into `secrets.json` and verifies a
decrypting round trip before atomically publishing the workspace. The matching
private-key file must therefore be usable non-interactively by hostd. SOPS's
SSH-key support cannot decrypt through `ssh-agent` alone.

The generated `GH_TOKEN` or `GITLAB_TOKEN` environment value is only a
placeholder. Explicit HTTP rules replace that placeholder after a matching
request leaves the VM. GitHub's rule admits `POST` because `gh` uses GraphQL
for read operations; the token's provider permissions enforce the read-only
boundary.

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
paths = ["/v1/models", "/v1/projects/*/models"]
methods = ["GET", "HEAD"]
header = "authorization"
placeholder = "replace-with-api-token"
secret = "project.API_TOKEN"
```

Tascarrel replaces the placeholder in matching `GET` and `HEAD` HTTP/1.1
requests after they leave the workspace, so the credential never enters the
workspace VM. It rejects other paths and methods for `api.example.com` at the
host proxy. HTTPS uses a per-workspace CA installed into common certificate
bundles.

Set `header` whenever possible; otherwise, Tascarrel checks every eligible
non-routing header. Every injection rule must list at least one syntactically
valid, case-sensitive HTTP method. Host rules accept an exact name or
`*.example.com` pattern. Optional `paths` is a non-empty array of absolute path
glob patterns. The usual `*`, `**`, `?`, character-class, and brace-alternative
forms are available. A single `*` does not cross `/`, while `**` does. Request
query strings do not participate in matching. Omit `paths` to match every path;
a literal `"/mcp"` remains an exact match. When several rules match a host, a
request is admitted if at least one rule matches its path and method, and only
rules admitting the complete request can inject. Rule and
provider-configuration changes apply to new TCP flows after the network policy
reloads; active flows retain their original rules. Updating a value in an
existing provider takes effect on the next matching request without restarting
the VM.

## Authenticate Tasci Traffic

Tasci sends a non-secret header template. The host network proxy replaces
its placeholder, so the credential never enters the workspace VM or pod.
HTTPS endpoints are verified through the workspace system trust store, which
includes the Tascarrel workspace certificate authority.

Configure the endpoint under **Workspace → Settings → Tasci**:

```json
{
  "authorization": {
    "header": "Authorization",
    "value": "Bearer tascarrel-secret:model-api-token"
  }
}
```

Then configure the same placeholder for the provider host in `config.toml`:

```toml
[[network.secret-injection]]
host = "api.example.com"
paths = ["/v1/chat/completions"]
methods = ["POST"]
header = "authorization"
placeholder = "tascarrel-secret:model-api-token"
secret = "project.MODEL_API_TOKEN"
```

The OpenAI-compatible Chat Completions protocol uses `POST`, so the rule must
admit that method. A placeholder mismatch leaves the template unchanged and
normally causes the provider to reject the request.

## Authenticate MCP Traffic

Model Context Protocol (MCP) servers accept an arbitrary map of header
templates under `chat.mcpServers`:

```json
{
  "private-tools": {
    "endpoint": "https://mcp.example.com/mcp",
    "headers": {
      "Authorization": "Bearer tascarrel-secret:mcp-api-token",
      "X-Workspace": "development"
    }
  }
}
```

Configure one secret-injection rule for each placeholder-bearing header:

```toml
[[network.secret-injection]]
host = "mcp.example.com"
paths = ["/mcp"]
methods = ["GET", "POST", "DELETE"]
header = "authorization"
placeholder = "tascarrel-secret:mcp-api-token"
secret = "project.MCP_API_TOKEN"
```

Streamable HTTP MCP connections use `POST` and may also use `GET` and `DELETE`,
so authenticated servers commonly admit all three methods.
