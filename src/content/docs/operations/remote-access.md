---
order: 2
description: Publish the authenticated Tascarrel UI and HTTP routes through an SSH reverse tunnel and Nginx.
---

# Configure Remote Access

Tascarrel's host daemon (`hostd`) can remain bound to loopback while an SSH
reverse tunnel and Nginx publish its UI and HTTP routes. Browser access always
requires a persistent session created with a short-lived pairing key.

This guide uses `tascarrel.example.com` for the UI and
`<route>.tascarrel.example.com` for published HTTP routes.

## Configure the Public Origin

Create `$TASCARREL_HOME/config/server.toml` with the externally visible HTTPS
origin:

```toml
[remote-access]
public-origin = "https://tascarrel.example.com"
```

Hostd derives the route suffix from the public-origin hostname. One TLS
certificate can then cover `tascarrel.example.com` and
`*.tascarrel.example.com` without a nested wildcard. Hostd continues to
recognize `<route>.tascarrel.localhost` for desktop and loopback development
workflows.

The public suffix identifies routes but is not exposed to routed services.
Hostd presents `localhost` for `<route>.tascarrel.example.com` and
`<prefix>.tascarrel.localhost` for
`<prefix>.<route>.tascarrel.example.com`. It applies the same mapping to
`Host`, same-origin `Origin`, and same-origin `Referer` values. This gives
services the same loopback origin locally and through remote access.

Hostd generates a private authentication key below
`$TASCARREL_HOME/state/auth/`. Supply an externally managed 32-byte raw key
with an optional server setting:

```toml
[authentication]
secret-file = "/run/secrets/tascarrel-auth"
```

Relative key paths resolve beside `server.toml`. The file must not grant group
or other permissions. Stop hostd before backing up or migrating the key and
`sessions.sqlite3`; the two files belong together. Restart hostd after changing
`server.toml`.

## Create the Reverse Tunnel

Keep this tunnel connected from the machine running Tascarrel:

```console
ssh -N -R 127.0.0.1:8272:127.0.0.1:8272 user@server
```

The explicit remote bind address keeps the forwarded port private to the
server. Nginx is the only public listener.

## Terminate TLS with Nginx

Proxy both the base hostname and its wildcard routes to the tunnel:

```nginx
map $http_upgrade $tascarrel_connection {
    default upgrade;
    ''      close;
}

server {
    listen 443 ssl http2;
    server_name tascarrel.example.com *.tascarrel.example.com;

    ssl_certificate     /etc/letsencrypt/live/tascarrel/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tascarrel/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8272;
        proxy_http_version 1.1;
        proxy_set_header Host $http_host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $tascarrel_connection;
        proxy_read_timeout 3600s;
    }
}
```

Preserve the original `Host` header. Hostd uses it to distinguish the UI from
published routes and to scope route credentials.

## Pair and Revoke Browsers

Create a single-use pairing key through hostd's private control socket:

```console
tascarrelctl auth pair --label "Remote laptop"
```

Open the public UI and enter the printed key. Pairing keys expire after ten
minutes. Browser sessions expire after 30 idle days or 180 total days.

Inspect or revoke sessions from **Settings → Remote Access** or from the host:

```console
tascarrelctl auth sessions
tascarrelctl auth revoke browser_session_...
```

Revocation closes the browser control connection and invalidates every HTTP
route grant derived from that session.

## Understand Route Authentication

Every published HTTP route requires authentication. The UI issues a 60-second,
single-use ticket in the URL fragment. Fragments do not reach Nginx, hostd's
HTTP logs, or the routed application. The route exchanges the ticket for a
host-only `HttpOnly` cookie and redirects to the clean target.

Embedded previews use their ticket only to bootstrap the frame. Opening a route
in a new tab from a preview or the network settings issues a fresh ticket
instead of reusing the frame's consumed ticket.

Hostd removes only its reserved route credential before proxying. Cookies owned
by the routed application continue to work. A route trusted as a Tascarrel
frontend also receives a same-origin API bridge below `/.tascarrel/`; trust
does not make the route public.
