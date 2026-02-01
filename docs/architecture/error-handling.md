# Error Handling Architecture

This document describes the error handling patterns and best practices for PropertyWebBuilder.

## Overview

PropertyWebBuilder uses a layered error handling approach:

1. **Custom Error Classes** (`app/errors/`) - Domain-specific exceptions with structured data
2. **StructuredLogger** (`app/services/structured_logger.rb`) - JSON logging with Sentry integration
3. **ErrorHandling Concern** (`app/controllers/concerns/error_handling.rb`) - Controller error handling
4. **API-specific Handlers** (`app/controllers/concerns/api_public/error_handler.rb`) - API error responses

## Custom Error Classes

### Base Class

All custom errors inherit from `ApplicationError`:

```ruby
class ApplicationError < StandardError
  attr_reader :code, :details, :http_status

  def initialize(message, code: nil, details: {}, http_status: :internal_server_error)
    @code = code || self.class.name.demodulize.underscore.upcase
    @details = details
    @http_status = http_status
    super(message)
  end

  def to_log_hash  # Returns hash for structured logging
  def to_api_response  # Returns hash for JSON responses
end
```

### Domain-Specific Errors

| Error Class | Use Case | HTTP Status |
|-------------|----------|-------------|
| `TenantNotFoundError` | Website context missing | 400 |
| `TenantMismatchError` | Cross-tenant access attempt | 403 |
| `ExternalServiceError` | External API failures | 502 |
| `ExternalServiceTimeoutError` | External API timeout | 504 |
| `ExternalServiceRateLimitError` | Rate limited by external service | 429 |
| `ImportError` | Data import failures | 422 |
| `SubscriptionError` | Subscription/payment issues | 402 |
| `FeatureNotAvailableError` | Feature not in plan | 403 |

### AI Service Errors (existing)

Located in `app/services/ai/error.rb`:

| Error Class | Use Case |
|-------------|----------|
| `Ai::ConfigurationError` | Missing API keys |
| `Ai::RateLimitError` | AI provider rate limit |
| `Ai::TimeoutError` | AI request timeout |
| `Ai::ContentPolicyError` | Content blocked |

## Logging with StructuredLogger

Use `StructuredLogger` for all error logging:

```ruby
# Basic logging
StructuredLogger.info("User signed in", user_id: user.id)
StructuredLogger.warn("Rate limit approaching", current: 90, limit: 100)
StructuredLogger.error("Payment failed", order_id: order.id, error: e.message)

# Exception logging (includes backtrace, sends to Sentry)
StructuredLogger.exception(error, "Failed to process payment", order_id: order.id)

# Performance tracking
StructuredLogger.measure("api.external_call") do
  ExternalApi.call
end

# Thread-local context
StructuredLogger.with_context(tenant_id: website.id) do
  # All logs in this block include tenant_id
  process_request
end
```

## Controller Error Handling

### Include the Concern

```ruby
class MyController < ApplicationController
  include ErrorHandling
  # ...
end
```

### Automatic Rescue Handlers

The concern provides automatic handlers for:
- `ApplicationError` and subclasses
- `ExternalServiceError` and subclasses
- `TenantNotFoundError`, `TenantMismatchError`
- `SubscriptionError`, `FeatureNotAvailableError`

### Manual Rescue Blocks

For rescue blocks that can't use automatic handlers:

```ruby
# BAD - Silent failure, no logging
def process
  service.call
rescue StandardError
  nil
end

# GOOD - Log and continue with fallback
def process
  service.call
rescue SomeSpecificError => e
  log_rescued_exception(e, context_message: "Processing widget")
  nil
end

# GOOD - Log with helper method
def fetch_optional_data
  ExternalApi.fetch
rescue ExternalApi::Error => e
  log_and_continue(e, fallback_value: [], context_message: "Fetching optional data")
end
```

### Raising Custom Errors

```ruby
def create_widget
  raise TenantNotFoundError.new unless current_website
  raise FeatureNotAvailableError.new("widgets", required_plan: "professional") unless can_create_widgets?

  Widget.create!(widget_params)
rescue ExternalApi::Error => e
  raise ExternalServiceError.new(
    "Widget creation failed",
    service_name: "WidgetAPI",
    original_error: e
  )
end
```

## API Error Responses

### API Public Controllers

Use the existing `ApiPublic::ErrorHandler`:

```ruby
module ApiPublic::V1
  class MyController < BaseController
    # ErrorHandler is already included via BaseController

    def show
      resource = find_resource
      render json: resource
    rescue MySpecificError => e
      raise ApiPublic::Errors::ApiError.new(
        code: "MY_ERROR",
        message: e.message,
        status: 422
      )
    end
  end
end
```

### API Manage Controllers

```ruby
module ApiManage::V1
  class MyController < BaseController
    include ErrorHandling

    def create
      # Automatic error handling for ApplicationError subclasses
      raise ExternalServiceError.new("API unavailable") if service_down?

      result = process_request
      render json: { success: true, data: result }
    end
  end
end
```

## Best Practices

### DO

- Use specific exception classes over `StandardError`
- Include context in error logs (user_id, resource_id, etc.)
- Use `StructuredLogger.exception` for caught exceptions
- Let errors bubble up when appropriate (don't swallow unexpectedly)
- Use `to_log_hash` and `to_api_response` for consistency

### DON'T

- Rescue `StandardError` without logging
- Swallow errors silently (`rescue => e; nil`)
- Include sensitive data in error messages (passwords, tokens)
- Re-raise generic `StandardError` - use specific classes

### When to Catch vs Let Bubble

**Catch the error when:**
- You can handle it gracefully (fallback value, retry, etc.)
- It's expected in normal operation (not found, validation)
- You need to transform it to a different error type

**Let it bubble when:**
- You can't meaningfully handle it
- It indicates a programming error
- It should be reported to error tracking (Sentry)

## Migration Guide

### Converting Old Rescue Blocks

```ruby
# OLD
def process
  do_something
rescue StandardError => e
  flash[:error] = "Something went wrong"
  redirect_to root_path
end

# NEW (in controller with ErrorHandling)
def process
  do_something
rescue SpecificServiceError => e
  log_rescued_exception(e, context_message: "Processing request")
  flash[:error] = "Something went wrong"
  redirect_to root_path
rescue AnotherError => e
  # Let ErrorHandling concern handle ApplicationError subclasses
  raise ExternalServiceError.new(e.message, service_name: "MyService", original_error: e)
end
```

## File Locations

- `app/errors/application_error.rb` - Base error class
- `app/errors/tenant_errors.rb` - Multi-tenancy errors
- `app/errors/external_service_errors.rb` - External API errors
- `app/errors/import_export_errors.rb` - Import/export errors
- `app/errors/subscription_errors.rb` - Subscription/payment errors
- `app/services/structured_logger.rb` - Structured logging
- `app/controllers/concerns/error_handling.rb` - Controller error handling
- `app/services/ai/error.rb` - AI service errors
