# Deploying to Northflank

This guide provides a general overview of how to deploy your PropertyWebBuilder application to Northflank. As there is no specific documentation from Northflank for deploying Rails applications, this guide assumes you will be deploying a Dockerized version of your application.

## Prerequisites

*   A Northflank account.
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

## 2. Create a New Service in Northflank

1.  Log in to your Northflank dashboard.
2.  Create a new **Service**.
3.  Choose your Git repository and branch. Northflank will detect your `Dockerfile` and use it to build your application.

## 3. Configure Your Service

*   **Ports:** Northflank will typically detect the exposed port from your `Dockerfile`. Ensure that port 3000 is correctly configured.
*   **Environment Variables:** Add your `RAILS_MASTER_KEY` and any other required environment variables.
*   **Database:** Create a new PostgreSQL database addon in Northflank. Once created, you can get the connection string and add it to your service's environment variables as `DATABASE_URL`.

## 4. Deploy

Once your service is configured, Northflank will automatically build and deploy your application. You can monitor the build and deployment logs in the Northflank dashboard.

## 5. Run Database Migrations

After your service is deployed, you will need to run your database migrations. You can do this by opening a one-off job or a command-line session into your running container and executing:

```bash
bundle exec rails db:migrate
```
