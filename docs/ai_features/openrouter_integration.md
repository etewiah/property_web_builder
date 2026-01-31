# OpenRouter.ai Integration

## Overview

[OpenRouter](https://openrouter.ai) is an API aggregator that provides unified access to 100+ AI models from multiple providers (Anthropic, OpenAI, Google, Meta, Mistral, and more) through a single API endpoint.

## Why OpenRouter?

| Benefit | Description |
|---------|-------------|
| **Model Variety** | Access Claude, GPT-4, Llama, Mistral, and 100+ other models |
| **Single API Key** | One API key for all providers |
| **Cost Optimization** | Compare pricing across providers, pay-as-you-go |
| **Automatic Fallbacks** | Route to backup models if primary is unavailable |
| **No Provider Lock-in** | Switch models without code changes |

## Configuration

### Site Admin Setup

1. Navigate to **Site Admin > Integrations**
2. Click **Configure** next to OpenRouter
3. Enter your API key from [openrouter.ai/keys](https://openrouter.ai/keys)
4. Select a default model
5. Click **Save**

### Credentials

| Field | Required | Description |
|-------|----------|-------------|
| API Key | Yes | Your OpenRouter API key (starts with `sk-or-`) |

### Settings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| Default Model | Select | `anthropic/claude-3.5-sonnet` | Model used for AI generation |
| Max Tokens | Number | 4096 | Maximum response length |

## Available Models

OpenRouter provides access to models in the format `provider/model-name`:

### Recommended Models

| Model | Provider | Best For |
|-------|----------|----------|
| `anthropic/claude-3.5-sonnet` | Anthropic | General purpose, good balance of quality/cost |
| `anthropic/claude-3-opus` | Anthropic | Highest quality, complex tasks |
| `openai/gpt-4o` | OpenAI | Fast, multimodal |
| `openai/gpt-4o-mini` | OpenAI | Cost-effective, good quality |
| `google/gemini-pro-1.5` | Google | Long context, multimodal |
| `meta-llama/llama-3.1-70b-instruct` | Meta | Open source, fast |
| `mistralai/mistral-large` | Mistral | European-hosted, multilingual |

### Full Model List

See [openrouter.ai/models](https://openrouter.ai/models) for the complete list of available models with pricing.

## Technical Implementation

### API Compatibility

OpenRouter uses an **OpenAI-compatible API**, which means:
- Same request/response format as OpenAI
- Uses `https://openrouter.ai/api/v1` as the base URL
- Works with existing OpenAI client libraries

### RubyLLM Configuration

PropertyWebBuilder uses RubyLLM for AI interactions. OpenRouter integration works by:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = openrouter_api_key
  config.openai_api_base = 'https://openrouter.ai/api/v1'
end
```

### Service Layer Integration

The `Ai::BaseService` automatically handles OpenRouter configuration:

```ruby
# In app/services/ai/base_service.rb
case @integration.provider
when 'open_router'
  config.openai_api_key = @integration.credential(:api_key)
  config.openai_api_base = 'https://openrouter.ai/api/v1'
end
```

## Usage in AI Services

All AI services automatically use the configured provider:

```ruby
# Listing Description Generation
result = Ai::ListingDescriptionGenerator.new(
  property: property,
  locale: 'en',
  tone: 'professional'
).generate

# Social Post Generation
result = Ai::SocialPostGenerator.new(
  property: property,
  platforms: [:instagram, :facebook],
  category: :just_listed
).generate
```

The service will use OpenRouter if it's the configured AI integration for the website.

## Environment Variables (Fallback)

For development or single-tenant deployments, you can set:

```bash
OPEN_ROUTER_API_KEY=sk-or-v1-...
OPEN_ROUTER_DEFAULT_MODEL=anthropic/claude-3.5-sonnet
```

Website integrations take precedence over environment variables.

## Cost Tracking

OpenRouter usage is tracked in `pwb_ai_generation_requests`:
- `ai_provider`: 'open_router'
- `ai_model`: The specific model used (e.g., 'anthropic/claude-3.5-sonnet')
- `input_tokens`: Tokens in the prompt
- `output_tokens`: Tokens in the response
- `cost_cents`: Calculated cost based on model pricing

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `401 Unauthorized` | Invalid API key | Check API key in Site Admin |
| `402 Payment Required` | Insufficient credits | Add credits at openrouter.ai |
| `429 Rate Limited` | Too many requests | Automatic retry with backoff |
| `503 Model Unavailable` | Model temporarily down | OpenRouter auto-routes to fallback |

## Testing

### Factory Trait

```ruby
# In specs
let!(:integration) { create(:pwb_website_integration, :open_router, website: website) }
```

### Connection Validation

```ruby
# Test connection in Site Admin
POST /site_admin/integrations/:id/test_connection
```

## Multi-Tenant Support

Each website can have its own OpenRouter configuration:
- Separate API keys per website
- Different default models per website
- Independent usage tracking
- Isolated error states

## Comparison with Direct Provider Integration

| Aspect | Direct (Anthropic/OpenAI) | OpenRouter |
|--------|---------------------------|------------|
| API Keys | One per provider | Single key for all |
| Model Access | Provider-specific | 100+ models |
| Pricing | Provider rates | OpenRouter markup (~10-20%) |
| Uptime | Provider SLA | OpenRouter + Provider SLA |
| Data Routing | Direct to provider | Through OpenRouter |

## Security Considerations

1. **API Key Storage**: Encrypted at rest in `pwb_website_integrations.credentials`
2. **Data Transit**: All requests use HTTPS
3. **Data Processing**: Requests routed through OpenRouter's servers
4. **Compliance**: Review OpenRouter's [privacy policy](https://openrouter.ai/privacy) for data handling

## Troubleshooting

### "AI is not configured" Error

1. Check integration is enabled in Site Admin > Integrations
2. Verify API key is set correctly
3. Test connection using the "Test Connection" button

### Model Not Found

1. Verify model name format: `provider/model-name`
2. Check model availability at openrouter.ai/models
3. Ensure sufficient credits for the model

### Slow Responses

1. Consider using a faster model (e.g., `gpt-4o-mini`)
2. Reduce `max_tokens` setting
3. Check OpenRouter status page for outages

## Related Documentation

- [AI Features Overview](./README.md)
- [AI Listing Descriptions](./ai_listing_descriptions.md)
- [Social Media Generator](./social_media_generator.md)
- [Integrations System](../architecture/integrations.md)
