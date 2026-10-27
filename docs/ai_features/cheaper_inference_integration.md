# Cheaper Inference Integration

## Overview

[Cheaper Inference](https://cheaperinference.com) is an OpenAI-compatible LLM gateway. One API key gives access to models from several labs through a single OpenAI-compatible API endpoint.

## Configuration

### Site Admin Setup

1. Navigate to **Site Admin > Integrations**
2. Click **Configure** next to Cheaper Inference
3. Enter your API key from [cheaperinference.com](https://cheaperinference.com)
4. Select a default model
5. Click **Save**

### Credentials

| Field | Required | Description |
|-------|----------|-------------|
| API Key | Yes | Your Cheaper Inference API key |

### Settings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| Default Model | Select | `gpt-5.4-mini` | Model used for AI generation |
| Max Tokens | Number | 4096 | Maximum response length |

## Available Models

Cheaper Inference uses bare model ids (no `provider/` prefix).

### Models in the Select List

| Model | Notes |
|-------|-------|
| `gpt-5.4-mini` | Default |
| `gpt-5.4` | |
| `gpt-5.5` | |
| `gpt-5-mini` | |
| `gpt-4.1` | |
| `gpt-4.1-mini` | |
| `gpt-4o-mini` | |

RubyLLM resolves each of these ids to its OpenAI provider.
`Ai::BaseService` points that provider at the Cheaper Inference base URL.

### Full Model List

See the [Cheaper Inference docs](https://cheaperinference.com/docs) for the complete list of models.

## Technical Implementation

### API Compatibility

Cheaper Inference uses an **OpenAI-compatible API**, which means:
- Same request/response format as OpenAI
- Uses `https://api.cheaperinference.com/v1` as the base URL
- Works with existing OpenAI client libraries

### RubyLLM Configuration

PropertyWebBuilder uses RubyLLM for AI interactions. The Cheaper Inference integration works by:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = cheaper_inference_api_key
  config.openai_api_base = 'https://api.cheaperinference.com/v1'
end
```

### Service Layer Integration

The `Ai::BaseService` automatically handles Cheaper Inference configuration:

```ruby
# In app/services/ai/base_service.rb
case @integration.provider
when 'cheaper_inference'
  config.openai_api_key = @integration.credential(:api_key)
  config.openai_api_base = 'https://api.cheaperinference.com/v1'
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

The service will use Cheaper Inference if it's the configured AI integration for the website.

## Cost Tracking

Cheaper Inference usage is tracked in `pwb_ai_generation_requests`:
- `ai_provider`: 'cheaper_inference'
- `ai_model`: The specific model used (e.g., 'gpt-5.4-mini')
- `input_tokens`: Tokens in the prompt
- `output_tokens`: Tokens in the response
- `cost_cents`: Calculated cost based on model pricing

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `401 Unauthorized` | Invalid API key | Check API key in Site Admin |
| `402 Payment Required` | Insufficient balance | Top up your account at cheaperinference.com |
| `429 Rate Limited` | Too many requests | Automatic retry with backoff |

## Testing

### Factory Trait

```ruby
# In specs
let!(:integration) { create(:pwb_website_integration, :cheaper_inference, website: website) }
```

### Connection Validation

```ruby
# Test connection in Site Admin
POST /site_admin/integrations/:id/test_connection
```

## Multi-Tenant Support

Each website can have its own Cheaper Inference configuration:
- Separate API keys per website
- Different default models per website
- Independent usage tracking
- Isolated error states

## Security Considerations

1. **API Key Storage**: Encrypted at rest in `pwb_website_integrations.credentials`
2. **Data Transit**: All requests use HTTPS
3. **Data Processing**: Requests routed through Cheaper Inference's servers
4. **Compliance**: Review Cheaper Inference's privacy policy for data handling

## Troubleshooting

### "AI is not configured" Error

1. Check integration is enabled in Site Admin > Integrations
2. Verify API key is set correctly
3. Test connection using the "Test Connection" button

### Model Not Found

1. Use a model from the select list (bare model id, no `provider/` prefix)
2. Check model availability in the Cheaper Inference docs
3. Ensure your account has a positive balance

## Related Documentation

- [AI Features Overview](./README.md)
- [Requesty Integration](./requesty_integration.md)
- [Integrations System](../architecture/integrations.md)
