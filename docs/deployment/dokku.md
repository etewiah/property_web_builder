# Deploying to Dokku

This guide will walk you through deploying your PropertyWebBuilder application to Dokku.

## Prerequisites

* A server with Dokku installed and configured.
* SSH access to the Dokku server.
* Rails credentials set up (see below).

## 0. Generate Rails Credentials

Since this is an open-source project, you need to generate your own credentials. The `credentials.yml.enc` file in the repo (if present) won't work without the original `master.key`.

```bash
# Remove any existing credentials file
rm -f config/credentials.yml.enc

# Generate new credentials (this creates both master.key and credentials.yml.enc)
EDITOR="code --wait" rails credentials:edit
```

This will open an editor where you can add your secrets:

```yaml
# Used by Rails and Devise for signing tokens
secret_key_base: your-generated-secret-key-base

# Optional: Separate key for Devise (falls back to secret_key_base if not set)
devise_secret_key: your-devise-secret-key
```

You can generate a new secret key with: `rails secret`

> **Important:** Never commit `config/master.key` to version control. It's already in `.gitignore`.

## 1. Create the Dokku App

Connect to your Dokku server via SSH and create a new Dokku app:

```bash
dokku apps:create your-app-name
```

## 2. Configure the Database

Create a PostgreSQL database and link it to your app:

```bash
dokku postgres:create your-app-name-db
dokku postgres:link your-app-name-db your-app-name
```

This will automatically set the `DATABASE_URL` environment variable for your app.

## 3. Configure Redis

Create a Redis instance and link it to your app:

```bash
dokku redis:create your-app-name-redis
dokku redis:link your-app-name-redis your-app-name
```

## 4. Build Configuration

To ensure a successful build, you need to configure a few files in your repository:

### Buildpacks
Create a `.buildpacks` file in the root of your repository to specify the buildpacks order (Node.js first for frontend assets, then Ruby):

```
https://github.com/heroku/heroku-buildpack-nodejs.git
https://github.com/heroku/heroku-buildpack-ruby.git
```

### Node Version
Ensure your `package.json` specifies a Node version compatible with your dependencies (e.g., Node 22):

```json
"engines": {
  "node": "22.x"
}
```

### NPM Configuration
If you encounter dependency conflicts (common with Vite/Quasar), create a `.npmrc` file:

```
legacy-peer-deps=true
```

## 5. Environment Variables

Configure the required environment variables for your app:

```bash
dokku config:set your-app-name \
  RAILS_MASTER_KEY=your_master_key_content \
  RAILS_SERVE_STATIC_FILES=enabled
```

| Variable | Required | Description |
|----------|----------|-------------|
| `RAILS_MASTER_KEY` | ✅ | The contents of `config/master.key` - required to decrypt credentials |
| `RAILS_SERVE_STATIC_FILES` | ✅ | Set to `enabled` - Dokku doesn't have a separate web server for static files |
| `GMAPS_API_KEY` | Optional | Google Maps API key (if using map features) |
| `R2_ACCESS_KEY_ID` | Optional | Cloudflare R2 access key (for cloud image storage) |
| `R2_SECRET_ACCESS_KEY` | Optional | Cloudflare R2 secret key |
| `R2_BUCKET` | Optional | Cloudflare R2 bucket name |
| `R2_ACCOUNT_ID` | Optional | Cloudflare R2 account ID |

> **Note:** `RAILS_ENV` and `RACK_ENV` are typically set automatically by Dokku.

## 6. Persistent Storage

Since Dokku containers are ephemeral, you must mount a persistent volume for uploaded files (images). Otherwise, uploads and seeded images will disappear on restart.

```bash
# Create the directory on the host (if it doesn't exist)
mkdir -p /var/lib/dokku/data/storage/your-app-name/uploads
chown -R 32767:32767 /var/lib/dokku/data/storage/your-app-name/uploads # Ensure container user has access

# Mount the storage
dokku storage:mount your-app-name /var/lib/dokku/data/storage/your-app-name/uploads:/app/public/uploads
```

## 7. Deploy

Add your Dokku server as a git remote:

```bash
git remote add dokku dokku@your-server-ip:your-app-name
```

Deploy your application by pushing to the Dokku remote:

```bash
git push dokku main
```

## 8. Post-Deployment Setup

### Database Migration and Seeding

For the initial setup, you might want to reset the database and seed it with default data.

**Warning:** The following commands will destroy existing data.

1.  **Stop the app** (to release database connections):
    ```bash
    dokku ps:stop your-app-name
    ```

2.  **Set safety override** (to allow DB drop in production):
    ```bash
    dokku config:set your-app-name DISABLE_DATABASE_ENVIRONMENT_CHECK=1
    ```

3.  **Reset and Seed**:
    ```bash
    dokku run your-app-name rails db:migrate:reset pwb:db:seed
    ```

4.  **Start the app**:
    ```bash
    dokku ps:start your-app-name
    ```

5.  **Cleanup**:
    ```bash
    dokku config:unset your-app-name DISABLE_DATABASE_ENVIRONMENT_CHECK
    ```

## Troubleshooting

### Rswag / NameError
If you see `NameError: uninitialized constant Rswag` in production, ensure `rswag-api` and `rswag-ui` gems are in the global group in your `Gemfile`, not just in `development` or `test`.

### Zeitwerk Autoloading Errors
If you encounter errors like `expected file .../version.rb to define constant ...::Version`, you may need to ignore specific files in `config/application.rb`:

```ruby
Rails.autoloaders.main.ignore(Rails.root.join('lib/pwb/version.rb'))
```
