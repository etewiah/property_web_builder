# Deploying to Cloud 66

This guide explains how to deploy your PropertyWebBuilder application to Cloud 66. Cloud 66 is a service specifically designed for deploying and managing Rails applications on any cloud provider or your own servers.

## Prerequisites

*   A Cloud 66 account.
*   A cloud provider account (e.g., AWS, DigitalOcean, Google Cloud) or your own server.
*   Your application code pushed to a Git repository (e.g., GitHub).

## 1. Create a New Rails Stack

1.  Log in to your Cloud 66 dashboard.
2.  Click on **New Stack** and select **Rails**.
3.  Choose your deployment target: your own server or a cloud provider. You will need to provide the necessary credentials for Cloud 66 to access your cloud account.
4.  Select your Git repository and the branch you want to deploy.

## 2. Analyze and Configure

Cloud 66 will analyze your application's `Gemfile` and other configuration files to determine the required server setup. It will automatically detect that you are using a Rails application and suggest a suitable server configuration.

*   **Database:** Cloud 66 will automatically provision and configure a PostgreSQL database for your application.
*   **Environment Variables:** You can add your `RAILS_MASTER_KEY` and any other required environment variables in the Cloud 66 dashboard under your stack's configuration. The `DATABASE_URL` is typically configured automatically.

## 3. Deploy

Once you are satisfied with the configuration, click **Deploy Stack**. Cloud 66 will then:

1.  Provision the necessary servers on your cloud provider.
2.  Install and configure all the required software (Ruby, Nginx, PostgreSQL, etc.).
3.  Clone your application's repository.
4.  Run `bundle install`, `rails assets:precompile`, and `rails db:migrate`.
5.  Start your application.

You can monitor the entire process in the Cloud 66 deployment logs.

## 4. Ongoing Management

Cloud 66 provides a range of tools for managing your application, including:

*   **Scaling:** Easily scale your application by adding more web servers or database replicas.
*   **Backups:** Configure automatic backups for your database.
*   **SSH Access:** Securely access your servers via SSH through the Cloud 66 toolbelt.
