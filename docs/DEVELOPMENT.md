# Development Guide

This guide provides instructions for setting up PropertyWebBuilder v2.0.0 locally, running tests, and troubleshooting common issues.

## Prerequisites

- **Ruby**: 3.4.7 or higher
- **Rails**: 8.0
- **PostgreSQL**: Ensure you have PostgreSQL installed and running
- **Node.js & npm**: Required for managing frontend dependencies (Vite, Vue.js)
- **Redis**: Optional, used for Firebase certificate caching

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

4.  **Setup the database:**

    ```bash
    rails db:create
    rails db:migrate
    rails pwb:db:seed
    ```

5.  **Start the development server:**

    ```bash
    bin/dev
    ```

    This starts both the Rails server and Vite for frontend asset compilation.
    The application should now be accessible at `http://localhost:3000`.

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

- `http://localhost:3000` - Default tenant
- `http://tenant-a.localhost:3000` - Specific tenant (requires hosts file or subdomain setup)

For local subdomain testing, add entries to `/etc/hosts`:
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

The project uses RSpec for testing.

- **Run all tests:**

    ```bash
    bundle exec rspec
    ```

- **Run specific tests:**

    ```bash
    bundle exec rspec spec/path/to/file_spec.rb
    ```

## Database Seeding

For comprehensive information about database seeding, including enhanced seeding features, multi-tenancy support, and safety mechanisms, see [docs/seeding.md](docs/seeding.md).

## Troubleshooting

### API CSRF Issues

If you encounter 422 Unprocessable Entity errors when making API requests (e.g., `PUT /api/v1/website`), it might be due to CSRF protection.

**Solution:**
Ensure that the relevant API controller has CSRF protection disabled or configured correctly for API usage. For example:

```ruby
class Api::V1::SomeController < ApplicationApiController
  protect_from_forgery with: :null_session
  # ...
end
```

### Asset Compilation

If you see issues with missing assets or styles, try precompiling assets locally:

```bash
rails assets:precompile
```

## Contributing

Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.
