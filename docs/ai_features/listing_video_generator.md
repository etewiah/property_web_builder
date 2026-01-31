# Listing Video Generator

## Overview

Automatically generate professional marketing videos from property listing photos. The system creates fully branded videos with AI-generated scripts, professional voiceovers, smooth transitions, captions, and background music - all without any video editing skills required.

**Inspiration**: Amplifiles ($1.50/image model) - we can deliver similar value at lower cost.

## Value Proposition

- **Save Time**: Generate a polished listing video in ~5 minutes vs hours of editing
- **Professional Quality**: Consistent branding, smooth Ken Burns effects, professional voiceover
- **Multi-Platform**: Output optimized for Instagram Reels, TikTok, Facebook, YouTube, listing sites
- **Cost Effective**: ~$0.16/video production cost, can price at $3-5/video (vs $12+ competitors)
- **No Skills Required**: Upload photos, click generate, download video

## Target Users

- Real estate agents wanting video content for social media
- Brokerages needing consistent branded videos
- Property managers marketing rental listings
- Homeowners selling FSBO

---

## Implementation Phases

### Phase 1: MVP (2 weeks)

**Goal**: Working end-to-end video generation with basic functionality

| Component | Technology | Status |
|-----------|------------|--------|
| Script Generation | Claude via existing `Ai::BaseService` | To Build |
| Text-to-Speech | OpenAI TTS API | To Build |
| Video Assembly | Shotstack API | To Build |
| Storage | ActiveStorage → Cloudflare R2 | Existing |
| Site Admin UI | Rails views (similar to CMA Reports) | To Build |

**Deliverables**:
- Generate video from any listing with photos
- Single video style (professional)
- Single format (vertical 9:16 for social)
- Basic branding (logo watermark)
- Download and view in Site Admin

### Phase 2: Enhancement (2-3 weeks)

**Goal**: Multiple options, better quality, social integration

| Feature | Description |
|---------|-------------|
| Multiple Styles | Professional, Luxury, Casual, Energetic, Minimal |
| Multiple Formats | Vertical (9:16), Horizontal (16:9), Square (1:1) |
| Premium Voices | ElevenLabs integration for natural voices |
| Social Sharing | Direct post to connected social accounts |
| Batch Generation | Generate videos for multiple listings at once |
| Custom Music | Music library selection or upload |

### Phase 3: Cost Optimization (Future)

**Goal**: Reduce per-video costs at scale

| Optimization | Savings | Complexity |
|--------------|---------|------------|
| Remotion (self-hosted) | ~$0.05/video on assembly | High |
| FFmpeg pipeline | Eliminate assembly API cost | Very High |
| Voice caching | Reuse common phrases | Medium |
| Template caching | Pre-render static elements | Medium |

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Site Admin UI                                    │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│   │ Video Index │  │ Video Show  │  │  Generate   │  │  Settings   │   │
│   │   (list)    │  │  (preview)  │  │    Form     │  │  (styles)   │   │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                    ListingVideosController                               │
│   index | show | new | create | destroy | download | regenerate         │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                      Video::Generator                                    │
│                    (Orchestrator Service)                                │
│                                                                          │
│   1. Validate inputs (property, photos, options)                        │
│   2. Create ListingVideo record (status: pending)                       │
│   3. Enqueue GenerateListingVideoJob                                    │
│   4. Return video record to controller                                  │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                   GenerateListingVideoJob                                │
│                    (Async Background Job)                                │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │ Step 1: Generate Script                                         │   │
│   │         Video::ScriptGenerator.generate(property, style)        │   │
│   │         → { script, scenes[], music_mood, duration }            │   │
│   └─────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│   ┌─────────────────────────────▼───────────────────────────────────┐   │
│   │ Step 2: Generate Voiceover                                      │   │
│   │         Video::VoiceoverGenerator.generate(script, voice)       │   │
│   │         → audio_url (stored in R2)                              │   │
│   └─────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│   ┌─────────────────────────────▼───────────────────────────────────┐   │
│   │ Step 3: Assemble Video                                          │   │
│   │         Video::Assembler.assemble(photos, audio, options)       │   │
│   │         → video_url (stored in R2)                              │   │
│   └─────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│   ┌─────────────────────────────▼───────────────────────────────────┐   │
│   │ Step 4: Finalize                                                │   │
│   │         - Generate thumbnail                                    │   │
│   │         - Update ListingVideo record (status: completed)        │   │
│   │         - Track costs in AiGenerationRequest                    │   │
│   └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Service Layer

```
app/services/video/
├── generator.rb              # Orchestrator - coordinates full workflow
├── script_generator.rb       # AI script generation
├── voiceover_generator.rb    # TTS integration (OpenAI/ElevenLabs)
├── assembler.rb              # Video assembly (Shotstack/Remotion)
├── template_builder.rb       # Builds Shotstack JSON templates
└── music_selector.rb         # Selects background music by mood
```

### Data Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Pwb::ListingVideo                                │
├─────────────────────────────────────────────────────────────────────────┤
│ id                    : bigint (PK)                                     │
│ website_id            : bigint (FK) - multi-tenant scope                │
│ realty_asset_id       : uuid (FK) - the property                        │
│ user_id               : bigint (FK) - who generated it                  │
│ ai_generation_request_id : bigint (FK) - cost tracking                  │
│                                                                          │
│ reference_number      : string - "VID-20260131-ABC123"                  │
│ title                 : string - "Video for 123 Main St"                │
│ status                : string - pending/generating/completed/failed    │
│                                                                          │
│ format                : string - vertical_9_16/horizontal_16_9/square   │
│ style                 : string - professional/luxury/casual/energetic   │
│ voice                 : string - alloy/echo/fable/onyx/nova/shimmer     │
│ duration_seconds      : integer - actual video length                   │
│                                                                          │
│ script_data           : jsonb - { script, scenes[], music_mood }        │
│ generation_meta       : jsonb - { timings, external_ids, errors }       │
│ branding              : jsonb - { logo_url, colors, agent_info }        │
│                                                                          │
│ cost_cents            : integer - total generation cost                 │
│ view_count            : integer - tracking views                        │
│                                                                          │
│ generated_at          : datetime                                        │
│ created_at            : datetime                                        │
│ updated_at            : datetime                                        │
├─────────────────────────────────────────────────────────────────────────┤
│ Attachments (ActiveStorage)                                             │
│ - video_file          : the generated MP4                               │
│ - voiceover_audio     : the TTS audio file                              │
│ - thumbnail           : video thumbnail image                           │
├─────────────────────────────────────────────────────────────────────────┤
│ Associations                                                            │
│ - belongs_to :website                                                   │
│ - belongs_to :realty_asset (property)                                   │
│ - belongs_to :user (optional)                                           │
│ - belongs_to :ai_generation_request (optional)                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Service Specifications

### Video::Generator (Orchestrator)

The main entry point that coordinates the video generation workflow.

```ruby
# Usage:
result = Video::Generator.new(
  property: realty_asset,
  website: website,
  user: current_user,
  options: {
    format: :vertical_9_16,
    style: :professional,
    voice: :nova,
    include_price: true,
    include_address: true,
    music_enabled: true
  }
).generate

if result.success?
  video = result.video  # ListingVideo record (status: pending or generating)
else
  error = result.error
end
```

**Options:**
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format` | symbol | `:vertical_9_16` | Video dimensions |
| `style` | symbol | `:professional` | Visual style/template |
| `voice` | symbol | `:nova` | OpenAI TTS voice |
| `include_price` | boolean | `true` | Show price in video |
| `include_address` | boolean | `true` | Show address in video |
| `music_enabled` | boolean | `true` | Include background music |
| `max_photos` | integer | `10` | Limit photos used |
| `duration_target` | integer | `60` | Target length in seconds |

### Video::ScriptGenerator

Generates the voiceover script and scene breakdown using AI.

```ruby
# Usage:
result = Video::ScriptGenerator.new(
  property: realty_asset,
  style: :professional,
  options: {
    duration_target: 60,
    include_price: true,
    include_cta: true,
    locale: :en
  }
).generate

# Returns:
{
  script: "Welcome to this stunning 3-bedroom home...",
  scenes: [
    { photo_index: 0, duration: 5, caption: "Welcome Home", transition: "fade" },
    { photo_index: 1, duration: 6, caption: "Spacious Living", transition: "slide" },
    # ...
  ],
  music_mood: "uplifting",
  estimated_duration: 58,
  word_count: 145
}
```

**Style Prompts:**
| Style | Tone | Pace | Language |
|-------|------|------|----------|
| `professional` | Confident, informative | Moderate | Formal, feature-focused |
| `luxury` | Sophisticated, exclusive | Slower | Elegant, aspirational |
| `casual` | Friendly, approachable | Upbeat | Conversational, warm |
| `energetic` | Exciting, dynamic | Fast | Action words, enthusiasm |
| `minimal` | Simple, direct | Steady | Brief, factual |

### Video::VoiceoverGenerator

Converts script text to speech audio using TTS API.

```ruby
# Usage:
result = Video::VoiceoverGenerator.new(
  script: "Welcome to this stunning home...",
  voice: :nova,
  provider: :openai  # or :elevenlabs
).generate

# Returns:
{
  audio_url: "https://r2.example.com/voiceovers/abc123.mp3",
  duration_seconds: 58,
  cost_cents: 10,
  provider: "openai",
  voice: "nova"
}
```

**OpenAI TTS Voices:**
| Voice | Description | Best For |
|-------|-------------|----------|
| `alloy` | Neutral, balanced | General purpose |
| `echo` | Warm, conversational | Casual style |
| `fable` | Expressive, dynamic | Energetic style |
| `onyx` | Deep, authoritative | Luxury style |
| `nova` | Friendly, professional | Professional style |
| `shimmer` | Clear, pleasant | Any style |

**ElevenLabs Voices (Phase 2):**
- Custom voice cloning for agency branding
- More natural prosody and emotion
- Multi-language support

### Video::Assembler

Assembles the final video from photos, audio, and configuration.

```ruby
# Usage:
result = Video::Assembler.new(
  photos: property.prop_photos.ordered,
  voiceover_url: "https://r2.example.com/voiceovers/abc123.mp3",
  scenes: script_result[:scenes],
  options: {
    format: :vertical_9_16,
    style: :professional,
    branding: {
      logo_url: website.main_logo_url,
      primary_color: "#2563eb",
      agent_name: "John Smith"
    },
    music_mood: "uplifting",
    music_volume: 0.3
  }
).assemble

# Returns:
{
  video_url: "https://r2.example.com/videos/xyz789.mp4",
  thumbnail_url: "https://r2.example.com/thumbnails/xyz789.jpg",
  duration_seconds: 62,
  resolution: "1080x1920",
  file_size_bytes: 15_234_567,
  render_id: "shotstack_abc123",
  cost_cents: 5
}
```

### Video::TemplateBuilder

Builds the JSON template for Shotstack API.

```ruby
# Generates Shotstack Edit JSON structure
{
  timeline: {
    tracks: [
      # Track 1: Photos with Ken Burns effects
      {
        clips: photos.map { |p| photo_clip(p) }
      },
      # Track 2: Captions overlay
      {
        clips: scenes.map { |s| caption_clip(s) }
      },
      # Track 3: Logo watermark
      {
        clips: [logo_clip]
      },
      # Track 4: Voiceover audio
      {
        clips: [voiceover_clip]
      },
      # Track 5: Background music
      {
        clips: [music_clip]
      }
    ]
  },
  output: {
    format: "mp4",
    resolution: "hd",  # or "sd", "4k"
    aspectRatio: "9:16"
  }
}
```

---

## External Service Integration

### OpenAI TTS API

**Endpoint**: `POST https://api.openai.com/v1/audio/speech`

**Request:**
```json
{
  "model": "tts-1",
  "input": "Welcome to this stunning 3-bedroom home...",
  "voice": "nova",
  "response_format": "mp3",
  "speed": 1.0
}
```

**Pricing**: $15.00 per 1M characters (~$0.01 per 60-second script)

**Integration**:
- Store OpenAI API key in existing AI integration
- Reuse `Pwb::WebsiteIntegration` with category: `ai`
- Fall back to ENV variable if no integration configured

### Shotstack API

**Endpoint**: `POST https://api.shotstack.io/v1/render`

**Render Request:**
```json
{
  "timeline": { /* see TemplateBuilder */ },
  "output": {
    "format": "mp4",
    "resolution": "hd"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Created",
  "response": {
    "id": "d2b46ed6-998a-4d6b-9d91-b8cf0193a655",
    "status": "queued"
  }
}
```

**Status Polling**: `GET https://api.shotstack.io/v1/render/{id}`

**Pricing**:
- $49/month for 100 renders (Starter)
- $0.049/render overage
- ~$0.05 per video

**Integration**:
- New integration category: `video`
- Provider: `shotstack`
- Credentials: `api_key`, `environment` (sandbox/production)

### Integration Configuration

```ruby
# New integration provider definition
module Integrations
  module Providers
    class Shotstack
      CATEGORY = :video

      CREDENTIAL_FIELDS = {
        api_key: { type: :password, required: true },
        environment: { type: :select, options: %w[sandbox production], default: 'sandbox' }
      }

      SETTING_FIELDS = {
        default_resolution: { type: :select, options: %w[sd hd], default: 'hd' },
        webhook_url: { type: :string, required: false }
      }
    end
  end
end
```

---

## Video Formats & Dimensions

| Format | Aspect Ratio | Resolution | Use Case |
|--------|--------------|------------|----------|
| `vertical_9_16` | 9:16 | 1080x1920 | Instagram Reels, TikTok, Stories |
| `horizontal_16_9` | 16:9 | 1920x1080 | YouTube, Listing sites, Email |
| `square_1_1` | 1:1 | 1080x1080 | Instagram Feed, Facebook |

---

## Video Styles

### Professional (Default)
- Clean, modern transitions (fade, slide)
- Blue/neutral color scheme
- Moderate pacing (5-6 seconds per photo)
- Feature-focused captions
- Corporate-friendly music

### Luxury
- Slow, elegant transitions (dissolve)
- Gold/black accent colors
- Slower pacing (7-8 seconds per photo)
- Aspirational language
- Classical or ambient music

### Casual
- Dynamic transitions (zoom, pan)
- Warm, friendly colors
- Faster pacing (4-5 seconds per photo)
- Conversational captions
- Upbeat acoustic music

### Energetic
- Quick cuts, motion effects
- Bold, vibrant colors
- Fast pacing (3-4 seconds per photo)
- Action-oriented captions
- Electronic or pop music

---

## Cost Breakdown

### Per-Video Costs (Phase 1)

| Component | Service | Cost |
|-----------|---------|------|
| Script Generation | Claude Sonnet | ~$0.01 |
| Voiceover (60s) | OpenAI TTS | ~$0.01 |
| Video Assembly | Shotstack | ~$0.05 |
| Storage (50MB) | Cloudflare R2 | ~$0.001 |
| **Total** | | **~$0.07** |

### Pricing Strategy

| Tier | Price | Margin | Target |
|------|-------|--------|--------|
| Per video | $3.00 | ~$2.93 (97%) | Occasional users |
| 10-pack | $20.00 | ~$19.30 (96%) | Regular agents |
| Unlimited | $49/mo | Varies by usage | Power users |

### Cost Comparison

| Service | Cost per Video | Notes |
|---------|----------------|-------|
| Amplifiles | $12.00 (8 photos) | $1.50/image |
| Our MVP | $3.00 | Flat rate |
| Video editor | $50-200 | Manual work |
| Hiring videographer | $200-500+ | Professional shoot |

---

## Database Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_pwb_listing_videos.rb
class CreatePwbListingVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_listing_videos do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
      t.references :user, foreign_key: { to_table: :pwb_users }
      t.references :ai_generation_request, foreign_key: { to_table: :pwb_ai_generation_requests }

      # Identification
      t.string :reference_number, null: false
      t.string :title, null: false

      # Status
      t.string :status, default: 'pending', null: false

      # Configuration
      t.string :format, default: 'vertical_9_16', null: false
      t.string :style, default: 'professional', null: false
      t.string :voice, default: 'nova'

      # Generated data
      t.jsonb :script_data, default: {}
      t.jsonb :generation_meta, default: {}
      t.jsonb :branding, default: {}

      # Metrics
      t.integer :duration_seconds
      t.integer :cost_cents, default: 0
      t.integer :view_count, default: 0

      # Timestamps
      t.datetime :generated_at
      t.timestamps
    end

    add_index :pwb_listing_videos, :reference_number, unique: true
    add_index :pwb_listing_videos, [:website_id, :status]
    add_index :pwb_listing_videos, [:realty_asset_id]
  end
end
```

---

## Background Job

```ruby
# app/jobs/generate_listing_video_job.rb
class GenerateListingVideoJob < ApplicationJob
  include TenantAwareJob

  queue_as :default

  # Longer timeout for video generation
  limits_concurrency to: 2, key: ->(video_id, website_id) { "video_gen_#{website_id}" }

  retry_on Video::AssemblyError, wait: :polynomially_longer, attempts: 3
  retry_on Video::VoiceoverError, wait: 30.seconds, attempts: 2
  discard_on Video::InvalidPropertyError

  def perform(video_id:, website_id:)
    set_tenant!(website_id)

    video = Pwb::ListingVideo.find(video_id)
    return if video.completed? || video.failed?

    video.update!(status: 'generating')

    # Step 1: Generate script
    script_result = generate_script(video)
    video.update!(script_data: script_result)

    # Step 2: Generate voiceover
    voiceover_result = generate_voiceover(video, script_result[:script])
    video.voiceover_audio.attach(download_audio(voiceover_result[:audio_url]))

    # Step 3: Assemble video
    assembly_result = assemble_video(video, script_result, voiceover_result)
    video.video_file.attach(download_video(assembly_result[:video_url]))
    video.thumbnail.attach(download_thumbnail(assembly_result[:thumbnail_url]))

    # Step 4: Finalize
    video.update!(
      status: 'completed',
      duration_seconds: assembly_result[:duration_seconds],
      cost_cents: calculate_total_cost(script_result, voiceover_result, assembly_result),
      generated_at: Time.current,
      generation_meta: build_generation_meta(script_result, voiceover_result, assembly_result)
    )

  rescue StandardError => e
    video&.update!(
      status: 'failed',
      generation_meta: video.generation_meta.merge(error: e.message)
    )
    raise
  ensure
    clear_tenant!
  end

  private

  def generate_script(video)
    Video::ScriptGenerator.new(
      property: video.realty_asset,
      style: video.style.to_sym,
      options: { duration_target: 60 }
    ).generate
  end

  def generate_voiceover(video, script)
    Video::VoiceoverGenerator.new(
      script: script,
      voice: video.voice.to_sym
    ).generate
  end

  def assemble_video(video, script_result, voiceover_result)
    Video::Assembler.new(
      photos: video.realty_asset.prop_photos.ordered.limit(10),
      voiceover_url: voiceover_result[:audio_url],
      scenes: script_result[:scenes],
      options: {
        format: video.format.to_sym,
        style: video.style.to_sym,
        branding: video.branding,
        music_mood: script_result[:music_mood]
      }
    ).assemble
  end
end
```

---

## Site Admin Routes

```ruby
# config/routes.rb (within site_admin namespace)
resources :listing_videos, only: %i[index show new create destroy] do
  member do
    get :download
    post :regenerate
  end
  collection do
    get :batch_new
    post :batch_create
  end
end
```

---

## API Endpoints (Future)

For headless/API usage:

```
POST   /api_manage/v1/:locale/videos           # Generate video
GET    /api_manage/v1/:locale/videos           # List videos
GET    /api_manage/v1/:locale/videos/:id       # Get video details
DELETE /api_manage/v1/:locale/videos/:id       # Delete video
GET    /api_manage/v1/:locale/videos/:id/download  # Download URL
```

---

## Error Handling

### Error Types

| Error | Cause | Action |
|-------|-------|--------|
| `InvalidPropertyError` | No photos, invalid property | Discard job, notify user |
| `ScriptGenerationError` | AI API failure | Retry with backoff |
| `VoiceoverError` | TTS API failure | Retry once, then fail |
| `AssemblyError` | Shotstack API failure | Retry with backoff |
| `StorageError` | R2 upload failure | Retry |

### User-Facing Messages

```ruby
VIDEO_STATUS_MESSAGES = {
  pending: "Video is queued for generation",
  generating: "Video is being created (this takes 2-5 minutes)",
  completed: "Video is ready to download",
  failed: "Video generation failed. Please try again."
}
```

---

## Testing Strategy

### Unit Tests
- `Video::ScriptGenerator` - mock AI, test prompt building
- `Video::VoiceoverGenerator` - mock TTS API
- `Video::Assembler` - mock Shotstack API
- `Video::TemplateBuilder` - test JSON structure

### Integration Tests
- Full generation flow with VCR cassettes
- Shotstack sandbox environment

### Manual Testing
- Generate videos for various property types
- Test all formats and styles
- Verify on actual social platforms

---

## Monitoring & Observability

### Metrics to Track
- Videos generated per day/week
- Average generation time
- Success/failure rate
- Cost per video
- Most used styles/formats

### Alerts
- Generation failure rate > 10%
- Average generation time > 10 minutes
- Shotstack API errors
- TTS API errors

### Logging
```ruby
Rails.logger.tagged("VideoGeneration", video.reference_number) do
  Rails.logger.info "Starting generation", property_id: video.realty_asset_id
  # ... generation steps with timing
  Rails.logger.info "Completed", duration_ms: elapsed, cost_cents: cost
end
```

---

## Security Considerations

- API keys stored encrypted in `Pwb::WebsiteIntegration`
- Generated videos scoped to website (multi-tenant)
- Signed URLs for video downloads (expiring)
- Rate limiting on generation endpoint
- File size limits on uploads

---

## Future Enhancements

### Phase 2 Details

**Multiple Styles**:
- Add `style` column to model
- Create style-specific prompt templates
- Design Shotstack templates per style

**ElevenLabs Integration**:
- Add as alternative TTS provider
- Voice cloning for agency branding
- Higher quality, more natural voices

**Social Sharing**:
- Direct publish to connected social accounts
- Platform-specific optimization
- Scheduling support

**Batch Generation**:
- Select multiple properties
- Queue all videos
- Progress tracking UI

### Phase 3 Details

**Remotion Migration**:
- Self-hosted video rendering
- React-based template system
- Serverless function deployment
- ~$0.02/video vs $0.05 Shotstack

**FFmpeg Pipeline**:
- Custom encoding pipeline
- Zero external API cost
- Full control over output
- Requires dedicated infrastructure

**Asset Caching**:
- Pre-render common intros/outros
- Cache music tracks locally
- Reuse voice segments for common phrases
