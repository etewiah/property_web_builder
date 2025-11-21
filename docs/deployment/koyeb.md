# Deploying to Koyeb

This guide will walk you through deploying your PropertyWebBuilder application to Koyeb.

## Prerequisites

* A Koyeb account.
* Your application code pushed to a GitHub repository.

## 1. Prepare your application

Koyeb can automatically detect and deploy your Rails application. However, you need to make sure your application is properly configured.

### Procfile

Create a `Procfile` in the root of your project to define the command to run your application:

```
web: bundle exec rails server
```

### Database

Koyeb provides a PostgreSQL database service. You will need to configure your `config/database.yml` to use the `DATABASE_URL` environment variable provided by Koyeb.

```yaml
production:
  adapter: postgresql
  encoding: unicode
  pool: 5
  url: <%= ENV['DATABASE_URL'] %>
```

## 2. Deploy

1. Go to the Koyeb Dashboard and click **Create App**.
2. Select **GitHub** as the deployment method and choose your repository.
3. Koyeb will automatically detect your application as a Ruby on Rails application.
4. In the **Environment Variables** section, add any required variables, such as `RAILS_MASTER_KEY`.
5. Click **Deploy**.

Koyeb will now build and deploy your application. You can monitor the progress in the deploy logs. Once the deployment is complete, your application will be available at the URL provided by Koyeb.
