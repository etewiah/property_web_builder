# Infrastructure Configuration for Astro Frontend

This document outlines the infrastructure changes required to support dual rendering mode (Rails + Astro) for PropertyWebBuilder.

## Environment Variables

The following environment variables must be configured on the Rails application server:

| Variable | Description | Example |
|----------|-------------|---------|
| `ASTRO_CLIENT_URL` | The URL of the Astro client application (internal or external) | `http://astro-app:4321` |
| `PROXY_AUTH_SECRET` | Secret key for JWT signing (defaults to `secret_key_base`) | `yoursecretkey` |

## Rails as Reverse Proxy

PropertyWebBuilder now acts as a reverse proxy for client-rendered websites. 

- **A themes (Client Mode):** Requests are forwarded to `ASTRO_CLIENT_URL`.
- **B themes (Rails Mode):** Handled directly by Rails.

### Headers Forwarded to Astro

The proxy forwards the following headers to the Astro client:

- `X-Forwarded-Host`: Original host requested by the user.
- `X-Forwarded-Proto`: Original protocol (http/https).
- `X-Website-Slug`: Subdomain of the current website.
- `X-Website-Id`: ID of the current website.
- `X-Rendering-Mode`: Always `client`.
- `X-Client-Theme`: The selected A-theme name.
- `X-Auth-Token`: A short-lived JWT for authentication verification.

## Nginx Configuration (Optional)

If you prefer to bypass Rails for static assets or specific public routes, you can use Nginx as a frontend load balancer.

### Example Nginx Configuration

```nginx
upstream rails_app {
  server localhost:3000;
}

upstream astro_app {
  server localhost:4321;
}

server {
  listen 80;
  server_name *.propertywebbuilder.com;

  location / {
    proxy_pass http://rails_app;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  # Optional: Serve Astro assets directly if shared volume is used
  # location /_astro/ {
  #   root /path/to/astro/dist;
  # }
}
```

## Security

The `X-Auth-Token` is a JWT signed with `Rails.application.secret_key_base`. The Astro client must use the same secret to verify the token.

### JWT Payload

```json
{
  "user_id": 123,
  "website_id": 456,
  "exp": 1234567890,
  "iat": 1234567880
}
```
