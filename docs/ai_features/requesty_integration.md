# Requesty Integration

## Overview

[Requesty](https://requesty.ai) is an API router that provides unified access to 400+ AI models from multiple providers (Anthropic, OpenAI, Google, DeepSeek, and more) through a single OpenAI-compatible API endpoint.

## Why Requesty?

| Benefit | Description |
|---------|-------------|
| **Model Variety** | Access Claude, GPT-4o, Gemini, DeepSeek, and 400+ other models |
| **Single API Key** | One API key for all providers |
| **Cost Optimization** | Compare pricing across providers, pay-as-you-go |
| **Automatic Fallbacks** | Route to backup models if primary is unavailable |
| **No Provider Lock-in** | Switch models without code changes |

## Configuration

### Site Admin Setup

1. Navigate to **Site Admin > Integrations**
2. Click **Configure** next to Requesty
3. Enter your API key from [app.requesty.ai/api-keys](https://app.requesty.ai/api-keys)
4. Select a default model
5. Click **Save**

### Credentials

| Field | Required | Description |
|-------|----------|-------------|
| API Key | Yes | Your Requesty API key |

### Settings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| Default Model | Select | `openai/gpt-4o-mini` | Model used for AI generation |
| Max Tokens | Number | 4096 | Maximum response length |

## Available Models

Requesty provides access to models in the format `provider/model-name`:

### Recommended Models

| Model | Provider | Best For |
|-------|----------|----------|
| `anthropic/claude-sonnet-4-5` | Anthropic | General purpose, good balance of quality/cost |
| `openai/gpt-4o` | OpenAI | Fast, multimodal |
| `openai/gpt-4o-mini` | OpenAI | Cost-effective, good quality |
| `openai/gpt-4.1` | OpenAI | High quality, large context |
| `google/gemini-2.5-flash` | Google | Fast, multimodal |
| `google/gemini-2.5-pro` | Google | Long context, multimodal |
| `deepseek/deepseek-chat` | DeepSeek | Cost-effective, strong reasoning |

### Full Model List

See [requesty.ai](https://requesty.ai) for the complete list of available models with pricing.

## Technical Implementation

### API Compatibility

Requesty uses an **OpenAI-compatible API**, which means:
- Same request/response format as OpenAI
- Uses `https://router.requesty.ai/v1` as the base URL
- Works with existing OpenAI client libraries

### RubyLLM Configuration

PropertyWebBuilder uses RubyLLM for AI interactions. Requesty integration works by:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = requesty_api_key
  config.openai_api_base = 'https://router.requesty.ai/v1'
end
```

### Service Layer Integration

The `Ai::BaseService` automatically handles Requesty configuration:

```ruby
# In app/services/ai/base_service.rb
case @integration.provider
when 'requesty'
  config.openai_api_key = @integration.credential(:api_key)
  config.openai_api_base = 'https://router.requesty.ai/v1'
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

The service will use Requesty if it's the configured AI integration for the website.

## Cost Tracking

Requesty usage is tracked in `pwb_ai_generation_requests`:
- `ai_provider`: 'requesty'
- `ai_model`: The specific model used (e.g., 'openai/gpt-4o-mini')
- `input_tokens`: Tokens in the prompt
- `output_tokens`: Tokens in the response
- `cost_cents`: Calculated cost based on model pricing

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `401 Unauthorized` | Invalid API key | Check API key in Site Admin |
| `402 Payment Required` | Insufficient credits | Add credits at app.requesty.ai |
| `429 Rate Limited` | Too many requests | Automatic retry with backoff |
| `503 Model Unavailable` | Model temporarily down | Requesty auto-routes to fallback |

## Testing

### Factory Trait

```ruby
# In specs
let!(:integration) { create(:pwb_website_integration, :requesty, website: website) }
```

### Connection Validation

```ruby
# Test connection in Site Admin
POST /site_admin/integrations/:id/test_connection
```

## Multi-Tenant Support

Each website can have its own Requesty configuration:
- Separate API keys per website
- Different default models per website
- Independent usage tracking
- Isolated error states

## Security Considerations

1. **API Key Storage**: Encrypted at rest in `pwb_website_integrations.credentials`
2. **Data Transit**: All requests use HTTPS
3. **Data Processing**: Requests routed through Requesty's servers
4. **Compliance**: Review Requesty's privacy policy for data handling

## Troubleshooting

### "AI is not configured" Error

1. Check integration is enabled in Site Admin > Integrations
2. Verify API key is set correctly
3. Test connection using the "Test Connection" button

### Model Not Found

1. Verify model name format: `provider/model-name`
2. Check model availability at requesty.ai
3. Ensure sufficient credits for the model

### Slow Responses

1. Consider using a faster model (e.g., `openai/gpt-4o-mini`)
2. Reduce `max_tokens` setting
3. Check Requesty status page for outages

## Related Documentation

- [AI Features Overview](./README.md)
- [OpenRouter Integration](./openrouter_integration.md)
- [Integrations System](../architecture/integrations.md)
