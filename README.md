# pablo-domain

This repository defines an nginx reverse proxy for routing a root domain, subdomains, and optional path-based routes to services deployed on Zeabur.

## What this service does

The request flow is:

```text
Browser
  -> your domain DNS
  -> Zeabur public gateway
  -> this nginx service
  -> target service
```

Use this only when you want one central routing layer. If each subdomain maps directly to one Zeabur service, Zeabur's built-in domain routing is simpler.

## Files

```text
Dockerfile
nginx/default.conf.template
README.md
```

- `Dockerfile` packages nginx for Zeabur.
- `nginx/default.conf.template` contains the routing rules.
- Zeabur provides a `PORT` environment variable. The official nginx Docker entrypoint replaces `${PORT}` in files under `/etc/nginx/templates/` before starting nginx.

## Step 1: Start with the default health route

The initial config responds to:

```text
/health -> ok
/       -> pablo-domain nginx proxy is running
```

This lets you deploy the proxy before you have real backend services wired in.

## Step 2: Add your domain in Zeabur

Deploy this repository to Zeabur as a Dockerfile service.

Then bind your domain and subdomains to this nginx service, for example:

```text
pablo.tw
www.pablo.tw
api.pablo.tw
blog.pablo.tw
```

In your DNS provider, point those records to the target Zeabur asks you to use.

## Step 3: Route the root domain

In `nginx/default.conf.template`, add a server block like this:

```nginx
server {
    listen ${PORT};
    server_name pablo.tw www.pablo.tw;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass https://main-service.zeabur.app;
    }
}
```

Replace `https://main-service.zeabur.app` with the public URL of the Zeabur service you want to route to.

## Step 4: Route a subdomain

Add another server block:

```nginx
server {
    listen ${PORT};
    server_name api.pablo.tw;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass https://api-service.zeabur.app;
    }
}
```

Each subdomain usually gets its own `server` block.

This repository currently routes:

```text
simple-api.makfichen.dev -> http://simple-api.zeabur.internal:8080
```

That upstream is a Zeabur private networking hostname, so it only resolves when this nginx service runs inside the same Zeabur project as `simple-api`.

## Step 5: Route by path

If you want one domain to route to multiple services by path:

```nginx
server {
    listen ${PORT};
    server_name pablo.tw;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass https://main-service.zeabur.app;
    }

    location /api/ {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass https://api-service.zeabur.app/;
    }
}
```

The trailing slash matters:

```text
location /api/ + proxy_pass https://api-service.zeabur.app/
```

This strips `/api/` before forwarding. For example:

```text
pablo.tw/api/users -> https://api-service.zeabur.app/users
```

If your API expects to receive `/api/users`, remove the trailing slash from `proxy_pass`:

```nginx
proxy_pass https://api-service.zeabur.app;
```

## Step 6: Test locally with Docker

If Docker is installed:

```powershell
docker build -t pablo-domain .
docker run --rm -p 8080:8080 -e PORT=8080 pablo-domain
```

Then open:

```text
http://localhost:8080/health
```

## Mental model

- `server_name` decides which domain or subdomain this block handles.
- `location` decides which path this rule handles.
- `proxy_pass` decides where nginx forwards the request.
- `proxy_set_header` keeps useful client and protocol information for your backend service.
- Zeabur handles public HTTPS before the request reaches this nginx service.

## Common route patterns

```text
pablo.tw          -> main frontend
www.pablo.tw      -> main frontend
api.pablo.tw      -> API service
admin.pablo.tw    -> admin service
pablo.tw/api/     -> API service by path
```
