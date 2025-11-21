# Deploying to Alwaysdata

This guide provides instructions for deploying your PropertyWebBuilder application to Alwaysdata.

## Prerequisites

* An Alwaysdata account.
* Your application code pushed to a Git repository (e.g., GitHub).
* SSH access to your Alwaysdata account.

## 1. Set Up the Site in Alwaysdata

1.  Log in to your Alwaysdata administration panel.
2.  Navigate to **Web > Sites**.
3.  Click **Add a Site**.
4.  Choose **Ruby Rack** as the type.
5.  Set the **Application Path** to the directory where your application's `config.ru` file will be located (e.g., `/home/your-account/www/pwb`).
6.  Under the **Configuration** section, check the **Use Bundler** option.
7.  Define your application's **Environment** (e.g., `production`).
8.  Save the site configuration.

## 2. Deploy Your Application Code

1.  Connect to your Alwaysdata account via SSH.
2.  Navigate to the directory you specified as the application path (e.g., `cd ~/www/pwb`).
3.  Clone your application's repository into this directory:
    ```bash
    git clone https://github.com/your-username/propertywebbuilder.git .
    ```
4.  Install the dependencies using Bundler:
    ```bash
    bundle install
    ```

## 3. Configure the Database

1.  In the Alwaysdata admin panel, navigate to **Databases > PostgreSQL**.
2.  Create a new PostgreSQL database and a user for your application.
3.  Note the database name, username, password, and host.
4.  Go back to the **Web > Sites** section and select your application.
5.  Under the **Environment Variables** section, add a new variable `DATABASE_URL` with the following format:
    ```
    postgresql://USER:PASSWORD@HOST/DATABASE_NAME
    ```
6.  Also, add your `RAILS_MASTER_KEY` as another environment variable.

## 4. Run Database Migrations

1.  Connect to your Alwaysdata account via SSH.
2.  Navigate to your application directory.
3.  Run the Rails database migrations:
    ```bash
    RAILS_ENV=production bundle exec rails db:migrate
    ```

## 5. Final Steps

1.  In the Alwaysdata panel, go to **Web > Sites** and restart your application for the changes to take effect.
2.  Your application should now be live at the address provided by Alwaysdata.
