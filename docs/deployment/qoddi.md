# Deploying to Qoddi

This guide provides a general overview of how to deploy your PropertyWebBuilder application to Qoddi. Qoddi is a platform that uses Docker to deploy applications, so this guide assumes you have a Dockerized version of your application.

## Prerequisites

*   A Qoddi account.
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

## 2. Create a New App in Qoddi

1.  Log in to your Qoddi dashboard.
2.  Click **New App**.
3.  Connect your Git repository and select the branch you want to deploy.

## 3. Configure Your App

*   **Buildpack:** Qoddi will likely detect your `Dockerfile` and use it to build your application.
*   **Environment Variables:** Add your `RAILS_MASTER_KEY` and any other required environment variables in the app's settings.
*   **Database:** Qoddi provides a PostgreSQL data service. You will need to create a database and then add the connection string as a `DATABASE_URL` environment variable in your app's settings.
*   **Port:** Ensure that Qoddi is configured to route traffic to the port exposed in your `Dockerfile` (port 3000 in the example).

## 4. Deploy

Qoddi will automatically build and deploy your application when you push new commits to your connected Git branch. You can monitor the build and deployment process in the Qoddi dashboard.

## 5. Run Database Migrations

After your app is deployed, you'll need to run your database migrations. You can typically do this by SSHing into your running container or using a one-off job feature in the Qoddi dashboard:

```bash
bundle exec rails db:migrate
```
