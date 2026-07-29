---
order: 6
description: Enforce egress policy and connect explicitly between pods, the host, and local web routes.
---

# Control Network Access

Tascarrel routes pod traffic through a host-enforced policy layer. The default
action is `allow`, but only destination ports 80 and 443 are enabled, and local
or private addresses remain blocked unless `allow-local` is set.

## Restrict Egress

```toml
[network]
default = "deny"
allow-local = false
allow-hosts = [
  "api.github.com",
  "*.npmjs.org",
]
allow-addresses = ["1.1.1.1"]
allow-ports = [80, 443]
deny-hosts = ["telemetry.example.com"]
```

Address and hostname deny rules take precedence. Hostname rules apply to
inspected HTTP and HTTPS traffic. `*.example.com` matches subdomains, not the
bare hostname. Network configuration changes require a workspace restart.

Open **Workspace → Network → DNS Requests**, **HTTP Requests**, and **TCP
Flows** to see the requesting pod, destination, mediated request method and
path, secret-injection state, policy decision, and connection state. Query
strings and secret values are not retained. These diagnostic records are not
packet captures.

Current external network support is limited to TCP and captured DNS. Arbitrary
UDP and external IPv6 are not implemented. HTTP inspection supports HTTP/1.1,
including upgrades, but not HTTP/2, QUIC, or `CONNECT`. HTTPS requests appear
in the HTTP request log only when a matching secret-injection rule already
requires `hostd` to terminate TLS. Other HTTPS traffic remains encrypted.

## Reach a Host Service

Expose selected host-loopback services to every pod:

```toml
[network]
host-ports = [3000, "5432:15432"]
```

An integer maps the same port. The string form maps
`<host-port>:<pod-visible-port>`. Pods connect through:

```text
host.tascarrel.internal:3000
host.tascarrel.internal:15432
```

Other ports on that synthetic address remain denied. The **Pod → Host** tab can
add a runtime mapping for one pod; it overrides a configured mapping with the
same pod-visible port.

When the server itself runs inside another isolated environment, use
`tascarrel --host-port-host <HOST>` or `TASCARREL_HOST_PORT_HOST` to change
the outer destination for configured mappings:

```console
tascarrel --host-port-host host.tascarrel.internal
```

This affects static workspace mappings only. Dynamic pod-scoped mappings still
target the machine running that `hostd` process.

## Expose a Pod Service

Use **Host → Pod** or publish from inside the pod:

```console
podctl ports publish 3000 --title "Development server"
podctl ports list
podctl ports unpublish 3000
```

Tascarrel assigns a host-loopback port. Add `--tab` when the service should also
receive a visible HTTP route.

## Publish a Web Route

An HTTP route assigns a local hostname to one pod port:

```console
podctl http publish 3000 --title "Web application"
podctl http list
podctl http unpublish 3000
```

The UI provides the same actions under **HTTP Routes**. An internal route,
created with `--internal`, stays out of normal pod tabs.

Hostd presents the route's service with a canonical loopback authority. The
route's final hostname becomes `localhost`; any labels to the left become
`<labels>.tascarrel.localhost`. This mapping is independent of whether the
browser uses the local route suffix or a configured public suffix.

One route can be marked as the trusted Tascarrel frontend. Its exact origin then
receives full Tascarrel API access, replacing any previously trusted route.
Grant this capability only to reviewed code; sibling and nested hostnames do
not inherit it.
