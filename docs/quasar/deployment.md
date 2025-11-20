# Deployment and CI/CD

This guide covers the process of deploying your standalone Quasar application and setting up a Continuous Integration and Continuous Deployment (CI/CD) pipeline to automate the workflow.

## Deployment

A standalone Quasar application can be deployed to any static hosting provider. We recommend using [Vercel](https://vercel.com/) or [Netlify](https://www.netlify.com/) for their ease of use and seamless integration with GitHub.

### Building for Production

Before deploying, you need to build the application for production. This will create a `dist` directory with optimized and minified assets.

```bash
quasar build
```

### Deploying to Vercel

1. **Sign up for a Vercel account** and connect it to your GitHub repository.
2. **Create a new project** and select your Quasar application's repository.
3. **Configure the project:**
   - **Build Command:** `quasar build`
   - **Output Directory:** `dist/spa`
   - **Install Command:** `npm install`
4. **Deploy the application.**

### Deploying to Netlify

1. **Sign up for a Netlify account** and connect it to your GitHub repository.
2. **Create a new site** and select your Quasar application's repository.
3. **Configure the site:**
   - **Build Command:** `quasar build`
   - **Publish Directory:** `dist/spa`
4. **Deploy the site.**

## CI/CD Pipeline

A CI/CD pipeline automates the process of building, testing, and deploying your application. We recommend using GitHub Actions to set up a CI/CD pipeline for your Quasar project.

### Example GitHub Actions Workflow

Create a `.github/workflows/deploy.yml` file in your repository with the following configuration:

```yaml
name: Deploy to Vercel

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'

      - name: Install dependencies
        run: npm install

      - name: Build application
        run: quasar build

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
          working-directory: dist/spa
```

This workflow will automatically deploy your application to Vercel whenever you push a change to the `main` branch.

## Rails Backend Configuration

To allow the standalone frontend to communicate with the Rails API, you need to configure Cross-Origin Resource Sharing (CORS) in your Rails application.

### Enable CORS

Uncomment the `rack-cors` gem in your `Gemfile` and run `bundle install`. Then, configure CORS in `config/initializers/cors.rb`:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:8080', 'https://your-production-domain.com'
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

Replace `your-production-domain.com` with the actual domain of your deployed frontend application. This configuration will allow your Quasar app to make cross-origin requests to the Rails API.
