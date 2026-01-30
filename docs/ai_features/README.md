# AI Features for PropertyWebBuilder

This directory contains implementation documentation for AI-powered features that enhance the PropertyWebBuilder platform for real estate professionals.

## Overview

These features leverage AI (primarily Claude via Anthropic API) to automate time-consuming marketing tasks, helping agents focus on client relationships and closing deals.

## Features

### 1. [AI Listing Descriptions](./ai_listing_descriptions.md)

**Status**: Planned

Auto-generate compelling property descriptions from property attributes.

**Key Capabilities**:
- Generate descriptions in multiple languages
- Customizable tone (professional, casual, luxury)
- Fair Housing compliance checking
- Brand voice consistency via custom writing rules
- SEO title and meta description generation

**Integration Points**:
- Site Admin property text editing tab
- API endpoint for external clients
- Batch generation for multiple locales

---

### 2. [Social Media Content Generator](./social_media_generator.md)

**Status**: Planned

Create platform-optimized social posts from property listings.

**Key Capabilities**:
- Multi-platform support (Instagram, Facebook, LinkedIn, X/Twitter, TikTok)
- Post type variations (feed, story, reel)
- Category-based content (just listed, price drop, open house, sold)
- Platform-specific image optimization
- Hashtag generation
- Exportable content packages

**Integration Points**:
- Site Admin property pages
- Dedicated social media dashboard
- API for scheduling tool integration

---

### 3. [Market Reports & CMA](./market_reports_cma.md)

**Status**: Planned

Generate professional Comparative Market Analyses and market reports.

**Key Capabilities**:
- Automatic comparable property identification
- Price adjustment calculations
- AI-generated market insights
- Professional PDF generation
- Public sharing with lead capture
- Customizable report templates

**Integration Points**:
- Site Admin reports section
- Property detail pages (quick CMA)
- Public shareable links
- Email delivery

---

## Shared Infrastructure

### AI Provider Abstraction

All features use a common AI provider interface:

```ruby
# app/services/ai/base_provider.rb
module Ai
  class BaseProvider
    def generate(prompt:, system_prompt: nil)
      raise NotImplementedError
    end
  end
end

# Implementations
# - Ai::AnthropicProvider (Claude)
# - Ai::OpenAiProvider (GPT) - Future
# - Ai::GoogleProvider (Gemini) - Future
```

### Request Tracking

All AI generations are tracked for:
- Usage monitoring and limits
- Cost tracking
- Quality improvement
- Audit trail

```ruby
# pwb_ai_generation_requests table
- website_id, user_id
- request_type (listing_description, social_post, market_report)
- ai_provider, ai_model
- input_data, output_data
- input_tokens, output_tokens, cost_cents
- status (pending, processing, completed, failed)
```

### Subscription Limits

Usage is controlled by subscription tier:

| Plan | Monthly AI Generations |
|------|----------------------|
| Free | 5 |
| Starter | 50 |
| Professional | 500 |
| Enterprise | Unlimited |

---

## Configuration

### Required Environment Variables

```bash
# AI Provider Keys
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...  # Future

# Feature Flags
AI_FEATURES_ENABLED=true
AI_COMPLIANCE_CHECK=true
AI_DEFAULT_PROVIDER=anthropic
AI_DEFAULT_MODEL=claude-sonnet-4-20250514

# Rate Limiting
AI_RATE_LIMIT=10  # requests per minute
```

### Database Migrations

Run in order:
1. `create_ai_generation_requests` - Core tracking table
2. `create_ai_writing_rules` - Custom brand guidelines
3. `create_social_media_posts` - Social content storage
4. `create_social_media_templates` - Reusable templates
5. `create_market_reports` - CMA and report storage
6. `create_report_templates` - PDF templates
7. `create_market_data_snapshots` - Market statistics cache

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [ ] AI provider abstraction layer
- [ ] Request tracking and usage limits
- [ ] Anthropic API integration
- [ ] Basic listing description generation

### Phase 2: Listing Descriptions (Weeks 3-4)
- [ ] Multi-language support
- [ ] Fair Housing compliance checker
- [ ] Custom writing rules
- [ ] Site Admin integration

### Phase 3: Social Media (Weeks 5-6)
- [ ] Multi-platform content generation
- [ ] Image optimization
- [ ] Export functionality
- [ ] Social dashboard UI

### Phase 4: Market Reports (Weeks 7-10)
- [ ] Comparable finder algorithm
- [ ] Price adjustment logic
- [ ] AI insights generation
- [ ] PDF generation
- [ ] Public sharing

### Phase 5: Polish & Scale (Ongoing)
- [ ] Additional AI providers
- [ ] Advanced analytics
- [ ] A/B testing
- [ ] Template marketplace

---

## Testing Strategy

### Unit Tests
- AI provider mock responses
- Compliance checker patterns
- Price calculation algorithms

### Integration Tests
- Full generation flow with mocked AI
- PDF generation output
- API endpoint responses

### E2E Tests
- Site Admin UI flows
- Social media generation workflow
- CMA creation and sharing

---

## Security Considerations

1. **API Key Management**: Keys stored in environment, never in code
2. **Rate Limiting**: Per-website limits prevent abuse
3. **Content Filtering**: AI output scanned for inappropriate content
4. **Audit Trail**: All generations logged with user attribution
5. **Data Privacy**: Property data sent to AI is minimal and anonymized where possible

---

## Cost Management

Estimated costs per feature (using Claude Sonnet):

| Feature | Avg Tokens | Est. Cost |
|---------|------------|-----------|
| Listing Description | ~1,500 | $0.02 |
| Social Post (single) | ~800 | $0.01 |
| Social Batch (4 platforms) | ~3,200 | $0.04 |
| CMA Insights | ~2,500 | $0.03 |

Monthly cost projections at scale:
- 100 descriptions/month: ~$2
- 200 social batches/month: ~$8
- 50 CMAs/month: ~$1.50

---

## Related Documentation

- [PropertyWebBuilder Architecture](../architecture/)
- [Multi-tenancy Guide](../multi_tenancy/)
- [API Documentation](../api/)
