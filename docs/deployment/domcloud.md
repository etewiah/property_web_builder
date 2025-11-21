# Deploying to Domcloud

This guide provides general instructions for deploying your PropertyWebBuilder application to Domcloud. As of this writing, there is no specific documentation available from Domcloud for deploying Rails applications, so these instructions are based on a typical deployment process for a traditional hosting provider.

## Prerequisites

*   A Domcloud account.
*   SSH access to your Domcloud server.
*   Your application code pushed to a Git repository.

## 1. Prepare Your Server

1.  Connect to your Domcloud server via SSH.
2.  Install the necessary software:
    *   Ruby (using a version manager like rbenv or RVM is recommended).
    *   Bundler.
    *   Node.js and Yarn.
    *   PostgreSQL.
    *   Nginx or another web server.

## 2. Deploy Your Application Code

1.  Clone your application's repository to a directory on your server (e.g., `/home/user/your-app`).
    ```bash
    git clone https://github.com/your-username/propertywebbuilder.git /home/user/your-app
    ```
2.  Navigate to your application directory and install the dependencies:
    ```bash
    cd /home/user/your-app
    bundle install
    yarn install
    ```

## 3. Configure the Database

1.  Create a PostgreSQL database and a user for your application.
2.  Create a `.env` file in your application's root directory to store your environment variables. **Do not commit this file to git.**
3.  Add the `DATABASE_URL` and `RAILS_MASTER_KEY` to your `.env` file:
    ```
    DATABASE_URL="postgresql://user:password@localhost/your-db"
    RAILS_MASTER_KEY="your-master-key"
    ```

## 4. Precompile Assets and Run Migrations

1.  Precompile your assets:
    ```bash
    RAILS_ENV=production bundle exec rails assets:precompile
    ```
2.  Run the database migrations:
    ```bash
    RAILS_ENV=production bundle exec rails db:migrate
    ```

## 5. Configure Your Web Server and Application Server

You will need to set up a web server (like Nginx) to act as a reverse proxy for your Rails application, which will be run by an application server (like Puma).

### Example Nginx Configuration

Here is an example Nginx configuration. You would typically place this in `/etc/nginx/sites-available/your-app` and create a symlink to it in `/etc/nginx/sites-enabled/`.

```nginx
upstream your_app {
  server unix:/home/user/your-app/tmp/sockets/puma.sock;
}

server {
  listen 80;
  server_name your-domain.com;

  root /home/user/your-app/public;

  location / {
    proxy_pass http://your_app;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```

### Puma and Systemd

You should configure Puma to run as a service using systemd. This will ensure your application starts on boot and is automatically restarted if it crashes.

1.  Create a systemd service file (e.g., `/etc/systemd/system/your-app.service`).
2.  Add a configuration like the following, adjusting the paths and user as necessary:

```ini
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
User=user
WorkingDirectory=/home/user/your-app
ExecStart=/home/user/.rbenv/shims/bundle exec puma -C /home/user/your-app/config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

3.  Enable and start the service:
    ```bash
    sudo systemctl enable your-app
    sudo systemctl start your-app
    ```
