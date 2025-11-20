# Development Guide

This guide provides instructions for setting up the PropertyWebBuilder project locally, running tests, and troubleshooting common issues.

## Prerequisites

- **Ruby**: 3.4.1
- **Rails**: ~> 7.0
- **PostgreSQL**: Ensure you have PostgreSQL installed and running.
- **Node.js & Yarn**: Required for managing frontend dependencies.

## Setup

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/etewiah/property_web_builder.git
    cd property_web_builder
    ```

2.  **Install Ruby dependencies:**

    ```bash
    bundle install
    ```

3.  **Install JavaScript dependencies:**

    ```bash
    yarn install
    ```

4.  **Setup the database:**

    ```bash
    rails db:create
    rails db:migrate
    rails pwb:db:seed
    ```

5.  **Start the server:**

    ```bash
    rails server
    ```

    The application should now be accessible at `http://localhost:3000`.

## Running Tests

The project uses RSpec for testing.

- **Run all tests:**

    ```bash
    bundle exec rspec
    ```

- **Run specific tests:**

    ```bash
    bundle exec rspec spec/path/to/file_spec.rb
    ```

## Troubleshooting

### API CSRF Issues

If you encounter 422 Unprocessable Entity errors when making API requests (e.g., `PUT /api/v1/website`), it might be due to CSRF protection.

**Solution:**
Ensure that the relevant API controller has CSRF protection disabled or configured correctly for API usage. For example:

```ruby
class Api::V1::SomeController < ApplicationApiController
  protect_from_forgery with: :null_session
  # ...
end
```

### Asset Compilation

If you see issues with missing assets or styles, try precompiling assets locally:

```bash
rails assets:precompile
```

## Contributing

Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.
