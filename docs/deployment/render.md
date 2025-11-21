# Deploying to Render

This guide will walk you through deploying your PropertyWebBuilder application to Render.

## Prerequisites

* A Render account.
* Your application code pushed to a GitHub repository.

## 1. Create a Blueprint

Render uses a `render.yaml` file to define the services to be deployed. Create a file named `render.yaml` in the root of your project with the following content:

```yaml
services:
  - type: web
    name: property-web-builder
    env: ruby
    buildCommand: "./bin/render-build.sh"
    startCommand: "bundle exec puma -C config/puma.rb"
    envVars:
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: postgres
          property: connectionString
  - type: redis
    name: redis
  - type: db
    name: postgres
    ipAllowList: []
```

## 2. Create a Build Script

Create a build script named `bin/render-build.sh` and give it execute permissions:

```bash
#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails db:migrate
```

Make sure the script is executable:

```bash
chmod +x bin/render-build.sh
```

## 3. Deploy

1. Go to the Render Dashboard and click **New +** > **Blueprint**.
2. Select your GitHub repository.
3. Render will automatically detect and use your `render.yaml` file.
4. Fill in the required environment variables, such as `RAILS_MASTER_KEY`.
5. Click **Apply**.

Render will now build and deploy your application. You can monitor the progress in the deploy logs.
