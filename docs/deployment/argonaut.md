# Deploying to Argonaut

This guide provides a general overview of how to deploy your PropertyWebBuilder application to Argonaut. Since Argonaut is a platform for managing deployments to your own cloud infrastructure (like AWS, GCP, Azure), the exact steps will depend on your specific setup.

This guide assumes you have a Dockerized version of your application.

## Prerequisites

* An Argonaut account, connected to your cloud provider.
* A Docker image of your application pushed to a container registry (like Docker Hub, ECR, or GCR).
* A Kubernetes cluster or other target environment configured in Argonaut.

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

Build and push your Docker image to a registry:

```bash
docker build -t your-image-name .
docker push your-image-name
```

## 2. Create an App in Argonaut

1.  Log in to your Argonaut dashboard.
2.  Navigate to the **Apps** section and click **Create App**.
3.  Give your application a name.

## 3. Configure the Deployment

1.  Within your Argonaut app, create a new **Service**.
2.  Select your target environment (e.g., your Kubernetes cluster).
3.  For the **Image Path**, provide the path to your Docker image in the container registry.
4.  Configure the required **Environment Variables**, such as `DATABASE_URL` and `RAILS_MASTER_KEY`. You can link to a database managed by your cloud provider.
5.  Configure **Port Mapping** to expose port 3000 of your container.
6.  Configure any other necessary settings, such as resource allocation and scaling.

## 4. Deploy

Once you have configured your service, click **Deploy**. Argonaut will pull your Docker image and deploy it to your target environment. You can monitor the deployment progress in the Argonaut dashboard.
