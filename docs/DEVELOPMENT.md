# Development Guide

This guide provides instructions for setting up PropertyWebBuilder locally, running tests, and troubleshooting common issues.

## Prerequisites

- **Ruby**: 3.4.7 (see `.tool-versions`)
- **Rails**: 8.1
- **PostgreSQL**: Ensure you have PostgreSQL installed and running
- **Node.js & npm**: Required for Tailwind build tooling, Playwright, and frontend asset utilities
- **Redis**: Recommended for background jobs, caching, and some integration features

## Current stack notes

- **Frontend architecture**: Server-rendered ERB + Liquid templates with Tailwind CSS
- **JavaScript**: Stimulus for browser interactions
- **Deprecated**: Vue/Vite flows are no longer part of the active development path
- **GraphQL**: Deprecated for new work; prefer the REST endpoints under `docs/api/`

## Setup

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/etewiah/property_web_builder.git
    cd property_web_builder
    ```

2.  **Install Ruby dependencies:**

    ```bash
    bundle install
    ```

3.  **Install JavaScript dependencies:**

    ```bash
    npm install
    ```

4.  **Prepare the database:**

    ```bash
    bin/rails db:prepare
    ```

5.  **Optionally seed demo data:**

    ```bash
    bin/rails pwb:db:seed
    ```

6.  **Start the development server:**

    ```bash
    bin/dev
    ```

    This starts the Rails server plus the Tailwind watcher defined in `Procfile.dev`.
    The application should now be accessible at `http://localhost:3000`.

### Optional helper

`bin/setup` is useful for Ruby dependency installation and `db:prepare`, but on a fresh clone you should still run `npm install` before starting `bin/dev`.

## Secrets (Rails Encrypted Credentials)

This project supports Rails encrypted credentials (preferred) with environment variable fallbacks.

- Encrypted file(s) (safe to commit): `config/credentials.yml.enc` and/or `config/credentials/*.yml.enc`
- Encryption key(s) (never commit): `config/master.key` and/or `config/credentials/*.key`

### Create credentials locally

```bash
bin/rails credentials:edit
```

This generates `config/master.key` (kept out of git) and an encrypted credentials file.

### Add Cloudflare R2 secrets to credentials

Edit credentials and add a structure like:

```yml
r2:
    access_key_id: "..."
    secret_access_key: "..."
    account_id: "..."
    bucket: "..."            # uploads/images bucket (ActiveStorage)
    public_url: "https://..." # CDN/public domain for images

    # Optional (if you use separate buckets/keys)
    assets_bucket: "..."
    seed_images_bucket: "..."
    assets_access_key_id: "..."
    assets_secret_access_key: "..."
```

### Production/Dokku setup

Set the master key in your hosting environment (example for Dokku):

```bash
# On your local machine, copy the contents of config/master.key
dokku config:set <app> RAILS_MASTER_KEY=<paste-master-key>
```

If you don’t want to store R2 secrets in Dokku env vars anymore, remove them after verifying the app boots using credentials.

## Multi-Tenancy in Development

PropertyWebBuilder is a multi-tenant application. Each website is identified by subdomain:

- `http://localhost:3000` - Local development entry point
- `http://tenant-a.localhost:3000` - Specific tenant for subdomain testing

Modern browsers usually resolve `*.localhost` automatically. If your setup does not, add entries to `/etc/hosts`:
```
127.0.0.1 tenant-a.localhost
127.0.0.1 tenant-b.localhost
```

## Seed Packs

Use seed packs to quickly set up demo sites:

```bash
rails pwb:seed_packs:list                    # List available packs
rails pwb:seed_packs:apply[netherlands_urban] # Apply a specific pack
```

See [seeding documentation](./seeding/) for more details.

## Running Tests

The project uses RSpec for unit/integration testing and Playwright for browser testing.

- **Run all tests:**

    ```bash
    bundle exec rspec
    ```

- **Run specific tests:**

    ```bash
    bundle exec rspec spec/path/to/file_spec.rb
    ```

- **Run Playwright tests:**

    ```bash
    npx playwright test
    ```

## Database Seeding

For comprehensive information about database seeding, including enhanced seeding features, multi-tenancy support, and safety mechanisms, see [docs/seeding/README.md](./seeding/README.md).

## Troubleshooting

### API CSRF Issues

If you encounter 422 Unprocessable Entity errors when making API requests, it might be due to CSRF protection.

**Solution:**
Ensure that the relevant API controller has CSRF protection disabled or configured correctly for API usage. For example:

```ruby
class Api::V1::SomeController < ApplicationApiController
  protect_from_forgery with: :null_session
  # ...
end
```

### Asset Compilation

If you see issues with missing assets or styles, try rebuilding Tailwind assets first:

```bash
npm run tailwind:build
```

Then, if needed, precompile assets locally:

```bash
bin/rails assets:precompile
```

If Stimulus or asset changes do not appear in development, try clearing `tmp/cache/assets`, restart the Rails server, and hard refresh the browser.

## Contributing

Please refer to [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on how to contribute to this project.
