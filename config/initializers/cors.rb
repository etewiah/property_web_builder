Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # Development origin (Angular/Vue apps during development)
  allow do
    origins 'http://localhost:4200', 'http://localhost:4321', 'http://localhost:4322', 'http://localhost:4323'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end

  allow do
    origins 'pwb-astrojs-client.etewiah.workers.dev',
            'demo.propertywebbuilder.com',
            /.*\.workers\.dev/,
            /.*\.pages\.dev/,              # Cloudflare Pages preview deployments (EmDash)
            /.*\.propertywebbuilder\.com/,
            /.*\.spp\.propertywebbuilder\.com/,
            *([ENV['EMFRONT_ORIGIN']].compact)  # Production EmDash custom domain
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      max_age: 3600
  end

  # HPG (HousePriceGuess) frontend
  allow do
    origins 'https://housepriceguess.com',
            /.*\.housepriceguess\.com/
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      max_age: 3600
  end

  # Widget API - allow any origin for embeddable widgets
  # Security is handled at the application level via allowed_domains on each widget
  allow do
    origins '*'

    # Widget API endpoints
    resource '/api_public/v1/widgets/*',
      headers: :any,
      methods: [:get, :post, :options],
      max_age: 3600

    # Widget JavaScript and iframe
    resource '/widget.js',
      headers: :any,
      methods: [:get, :options],
      max_age: 3600

    resource '/widget/*',
      headers: :any,
      methods: [:get, :options],
      max_age: 3600
  end
end
