# Deploying to Dokku

This guide will walk you through deploying your PropertyWebBuilder application to Dokku.

## Prerequisites

* A server with Dokku installed and configured.
* SSH access to the Dokku server.

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

## 4. Deploy

Add your Dokku server as a git remote:

```bash
git remote add dokku dokku@your-server-ip:your-app-name
```

Deploy your application by pushing to the Dokku remote:

```bash
git push dokku main
```

Dokku will automatically detect that you are deploying a Ruby on Rails application, install the dependencies, and start the application.

## 5. Run Migrations

After the initial deployment, you'll need to run the database migrations:

```bash
dokku run your-app-name rails db:migrate
```
