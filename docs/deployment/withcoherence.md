# Deploying to Withcoherence

This guide provides a general overview of how to deploy your PropertyWebBuilder application to Withcoherence. Coherence is a platform that automates DevOps, and it typically uses a `coherence.yml` file to define your application's services.

This guide assumes you have a Dockerized version of your application.

## Prerequisites

*   A Withcoherence account.
*   Your application code pushed to a Git repository.
*   A `Dockerfile` in your project's root directory.

## 1. Dockerize Your Application

If you haven't already, you'll need to create a `Dockerfile` for your Rails application. Here is a basic example:

```dockerfile
# Use the official Ruby image
FROM ruby:3.1

# Install dependencies
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

# Set the working directory
WORKDIR /app

# Copy the Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application code
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

# Expose port 3000
EXPOSE 3000

# Start the Rails server
CMD ["rails", "server", "-b", "0.0.0.0"]
```

## 2. Create a `coherence.yml` File

Create a `coherence.yml` file in the root of your project. This file will define your application's services. Here is a basic example for a Rails application:

```yaml
services:
  web:
    build: .
    port: 3000
    health_check: /up
    env:
      - name: RAILS_MASTER_KEY
        secret: rails-master-key
      - name: DATABASE_URL
        from:
          service: db
          format: postgresql://{{user}}:{{password}}@{{host}}:{{port}}/{{name}}
  db:
    type: postgres
```

## 3. Deploy

1.  Log in to your Withcoherence dashboard.
2.  Connect your Git repository.
3.  Coherence will detect your `coherence.yml` file and use it to provision and deploy your services.
4.  You will need to add the value for your `RAILS_MASTER_KEY` as a secret in the Coherence dashboard.

## 4. Run Database Migrations

Coherence may have a feature for running one-off tasks or jobs. You would use this to run your database migrations:

```bash
bundle exec rails db:migrate
```
