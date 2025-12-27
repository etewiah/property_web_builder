# Property Video Generation with Revideo

This document outlines how to integrate programmatic video generation for property listings using [Revideo](https://re.video/), an open-source framework for creating videos with TypeScript.

## Overview

Automatically generate professional property showcase videos from listing data and images. Videos can be used for:
- Social media marketing (Instagram Reels, TikTok, YouTube Shorts)
- Property detail page embeds
- Email marketing campaigns
- Agent promotional materials

## Why Revideo?

| Consideration | Revideo | Remotion | Amplifiles API |
|---------------|---------|----------|----------------|
| License | MIT (free forever) | BSL (paid > $100k) | Per-video fee |
| Control | Full template control | Full template control | Limited |
| AI composition | No | No | Yes |
| Cost at scale | Compute only | Compute + license | $1-2/video |
| Branding | Full control | Full control | Watermark (free) |

**Recommendation**: Revideo for cost-effective, fully customizable video generation at scale.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PropertyWebBuilder                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │   Property   │───▶│  Video Job   │───▶│   Background Job     │  │
│  │   Listing    │    │   Request    │    │   (Sidekiq/GoodJob)  │  │
│  └──────────────┘    └──────────────┘    └──────────┬───────────┘  │
│                                                      │              │
└──────────────────────────────────────────────────────┼──────────────┘
                                                       │
                                                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Video Generation Service                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │   Revideo    │───▶│   Render     │───▶│   Video Output       │  │
│  │   Template   │    │   Engine     │    │   (MP4)              │  │
│  └──────────────┘    └──────────────┘    └──────────┬───────────┘  │
│                                                      │              │
└──────────────────────────────────────────────────────┼──────────────┘
                                                       │
                                                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Storage                                      │
├─────────────────────────────────────────────────────────────────────┤
│  ActiveStorage (S3/R2/Local) ─── CDN ─── Property Detail Page       │
└─────────────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Video Service Setup

#### 1.1 Create Node.js Video Service

The video generation runs as a separate Node.js service (Revideo requires Node.js).

```
video-service/
├── package.json
├── src/
│   ├── index.ts              # HTTP API server
│   ├── render.ts             # Rendering logic
│   └── templates/
│       ├── property-showcase.ts
│       ├── property-slideshow.ts
│       └── property-social.ts
├── assets/
│   ├── fonts/
│   ├── music/
│   └── overlays/
└── Dockerfile
```

#### 1.2 Dependencies

```json
{
  "dependencies": {
    "@revideo/core": "^0.4.0",
    "@revideo/2d": "^0.4.0",
    "@revideo/renderer": "^0.4.0",
    "express": "^4.18.0",
    "sharp": "^0.33.0"
  }
}
```

### Phase 2: Video Templates

#### 2.1 Property Showcase Template (30 seconds)

```typescript
// src/templates/property-showcase.ts
import { makeProject } from '@revideo/core';
import { makeScene2d, Img, Txt, Rect, Video } from '@revideo/2d';

interface PropertyData {
  title: string;
  price: string;
  address: string;
  bedrooms: number;
  bathrooms: number;
  area: string;
  images: string[];      // URLs to property images
  agentName?: string;
  agentPhoto?: string;
  logoUrl?: string;
  primaryColor?: string;
}

const propertyShowcase = makeScene2d(function* (view) {
  const data: PropertyData = view.variables.get('property')();

  // Scene 1: Hero image with address (0-5s)
  const heroImage = new Img({ src: data.images[0] });
  view.add(heroImage);
  yield* heroImage.scale(1, 1.1, 5);  // Ken Burns zoom

  const addressBar = new Rect({
    fill: data.primaryColor || '#1a365d',
    height: 80,
    width: '100%',
    y: 400,
  });
  view.add(addressBar);

  const addressText = new Txt({
    text: data.address,
    fill: '#ffffff',
    fontSize: 36,
    y: 400,
  });
  view.add(addressText);
  yield* addressText.opacity(0, 1, 0.5);

  // Scene 2: Feature highlights (5-12s)
  yield* transitionWipe();

  const features = [
    { icon: '🛏️', value: `${data.bedrooms} Bedrooms` },
    { icon: '🚿', value: `${data.bathrooms} Bathrooms` },
    { icon: '📐', value: data.area },
  ];

  for (const feature of features) {
    yield* showFeatureCard(feature, 2);
  }

  // Scene 3: Image slideshow (12-25s)
  for (let i = 1; i < Math.min(data.images.length, 5); i++) {
    yield* showImageWithTransition(data.images[i], 2.5);
  }

  // Scene 4: Price and CTA (25-30s)
  yield* showPriceCard(data.price);
  yield* showContactCTA(data.agentName, data.agentPhoto, data.logoUrl);
});

export default makeProject({
  scenes: [propertyShowcase],
  settings: {
    width: 1080,
    height: 1920,  // 9:16 for social media
    fps: 30,
  },
});
```

#### 2.2 Template Variants

| Template | Duration | Aspect Ratio | Use Case |
|----------|----------|--------------|----------|
| `property-showcase` | 30s | 9:16 | Instagram/TikTok |
| `property-slideshow` | 15s | 9:16 | Stories |
| `property-landscape` | 45s | 16:9 | YouTube/Website |
| `property-square` | 20s | 1:1 | Facebook/Instagram |

### Phase 3: Rails Integration

#### 3.1 Video Generation Model

```ruby
# app/models/pwb_tenant/property_video.rb
module PwbTenant
  class PropertyVideo < ApplicationRecord
    acts_as_tenant :website

    belongs_to :property, class_name: 'Pwb::Prop'
    has_one_attached :video_file

    enum status: {
      pending: 'pending',
      processing: 'processing',
      completed: 'completed',
      failed: 'failed'
    }

    enum template: {
      showcase: 'showcase',
      slideshow: 'slideshow',
      landscape: 'landscape',
      square: 'square'
    }

    validates :template, presence: true
  end
end
```

#### 3.2 Migration

```ruby
# db/migrate/XXXXXX_create_property_videos.rb
class CreatePropertyVideos < ActiveRecord::Migration[7.1]
  def change
    create_table :property_videos do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :property, null: false, foreign_key: { to_table: :pwb_props }
      t.string :template, null: false, default: 'showcase'
      t.string :status, null: false, default: 'pending'
      t.text :error_message
      t.integer :duration_seconds
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :property_videos, [:website_id, :property_id, :template],
              unique: true, name: 'idx_property_videos_unique'
  end
end
```

#### 3.3 Video Generation Service

```ruby
# app/services/video_generation_service.rb
class VideoGenerationService
  RENDER_SERVICE_URL = ENV.fetch('VIDEO_RENDER_SERVICE_URL', 'http://localhost:3100')

  def initialize(property_video)
    @property_video = property_video
    @property = property_video.property
    @website = property_video.website
  end

  def generate
    @property_video.update!(status: :processing)

    # Prepare property data for template
    property_data = build_property_data

    # Request video render
    response = request_render(property_data)

    if response[:success]
      # Attach the generated video
      @property_video.video_file.attach(
        io: URI.open(response[:video_url]),
        filename: "property-#{@property.id}-#{@property_video.template}.mp4",
        content_type: 'video/mp4'
      )
      @property_video.update!(
        status: :completed,
        duration_seconds: response[:duration]
      )
    else
      @property_video.update!(
        status: :failed,
        error_message: response[:error]
      )
    end
  rescue StandardError => e
    @property_video.update!(status: :failed, error_message: e.message)
    raise
  end

  private

  def build_property_data
    {
      title: @property.title,
      price: format_price,
      address: @property.full_address,
      bedrooms: @property.count_bedrooms,
      bathrooms: @property.count_bathrooms,
      area: format_area,
      images: property_image_urls,
      agentName: @website.agency&.display_name,
      agentPhoto: @website.agency&.photo_url,
      logoUrl: @website.logo_url,
      primaryColor: @website.primary_color
    }
  end

  def property_image_urls
    @property.photos.map(&:url).first(8)
  end

  def format_price
    if @property.for_sale?
      @property.price_sale_current&.format
    else
      "#{@property.price_rental_monthly_current&.format}/mo"
    end
  end

  def format_area
    unit = @property.area_unit == 'sqft' ? 'sq ft' : 'm²'
    "#{@property.plot_area} #{unit}"
  end

  def request_render(property_data)
    conn = Faraday.new(url: RENDER_SERVICE_URL) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 300  # 5 minute timeout
    end

    response = conn.post('/render') do |req|
      req.body = {
        template: @property_video.template,
        data: property_data
      }
    end

    response.body.symbolize_keys
  end
end
```

#### 3.4 Background Job

```ruby
# app/jobs/generate_property_video_job.rb
class GeneratePropertyVideoJob < ApplicationJob
  queue_as :video_generation

  # Retry with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(property_video_id)
    property_video = PwbTenant::PropertyVideo.find(property_video_id)
    VideoGenerationService.new(property_video).generate
  end
end
```

#### 3.5 Controller

```ruby
# app/controllers/site_admin/property_videos_controller.rb
module SiteAdmin
  class PropertyVideosController < SiteAdminController
    before_action :set_property

    def create
      @video = @property.property_videos.find_or_initialize_by(
        website: current_website,
        template: video_params[:template]
      )

      if @video.pending? || @video.failed?
        @video.update!(status: :pending)
        GeneratePropertyVideoJob.perform_later(@video.id)
        redirect_to site_admin_property_path(@property),
                    notice: 'Video generation started. This may take a few minutes.'
      else
        redirect_to site_admin_property_path(@property),
                    alert: 'Video is already being generated.'
      end
    end

    def show
      @video = @property.property_videos.find(params[:id])
    end

    private

    def set_property
      @property = current_website.properties.find(params[:property_id])
    end

    def video_params
      params.require(:property_video).permit(:template)
    end
  end
end
```

### Phase 4: Video Render Service API

#### 4.1 Express Server

```typescript
// video-service/src/index.ts
import express from 'express';
import { renderVideo } from './render';

const app = express();
app.use(express.json());

app.post('/render', async (req, res) => {
  const { template, data } = req.body;

  try {
    const result = await renderVideo(template, data);
    res.json({
      success: true,
      video_url: result.url,
      duration: result.duration
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3100;
app.listen(PORT, () => {
  console.log(`Video render service running on port ${PORT}`);
});
```

#### 4.2 Render Function

```typescript
// video-service/src/render.ts
import { renderVideo as revideoRender } from '@revideo/renderer';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import fs from 'fs';
import path from 'path';

const templates = {
  showcase: () => import('./templates/property-showcase'),
  slideshow: () => import('./templates/property-slideshow'),
  landscape: () => import('./templates/property-landscape'),
  square: () => import('./templates/property-square'),
};

export async function renderVideo(templateName: string, data: any) {
  const templateModule = await templates[templateName]();
  const outputPath = path.join('/tmp', `video-${Date.now()}.mp4`);

  // Render video
  await revideoRender({
    project: templateModule.default,
    variables: { property: data },
    output: outputPath,
    settings: {
      logProgress: true,
    },
  });

  // Upload to S3/R2
  const videoUrl = await uploadToStorage(outputPath);

  // Get duration
  const duration = await getVideoDuration(outputPath);

  // Cleanup
  fs.unlinkSync(outputPath);

  return { url: videoUrl, duration };
}

async function uploadToStorage(filePath: string): Promise<string> {
  const s3 = new S3Client({
    region: process.env.AWS_REGION,
    endpoint: process.env.S3_ENDPOINT,  // For R2 compatibility
  });

  const key = `videos/${path.basename(filePath)}`;

  await s3.send(new PutObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: key,
    Body: fs.readFileSync(filePath),
    ContentType: 'video/mp4',
  }));

  return `${process.env.CDN_URL}/${key}`;
}
```

### Phase 5: Deployment Options

#### Option A: Self-Hosted (Docker)

```yaml
# docker-compose.yml
services:
  video-service:
    build: ./video-service
    ports:
      - "3100:3100"
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - S3_BUCKET=${S3_BUCKET}
      - S3_ENDPOINT=${S3_ENDPOINT}
      - CDN_URL=${CDN_URL}
    volumes:
      - /tmp/video-render:/tmp
```

#### Option B: Serverless (AWS Lambda)

```typescript
// video-service/src/lambda.ts
import { renderPartialVideo, concatenateMedia } from '@revideo/renderer';

export async function handler(event: any) {
  const { template, data, workerIndex, totalWorkers } = event;

  // Render partial video (for parallelization)
  const partialPath = await renderPartialVideo({
    project: await loadTemplate(template),
    variables: { property: data },
    worker: { index: workerIndex, total: totalWorkers },
  });

  // If last worker, concatenate all parts
  if (workerIndex === totalWorkers - 1) {
    const finalPath = await concatenateMedia(/* partial paths */);
    return { videoUrl: await uploadToStorage(finalPath) };
  }

  return { partialPath };
}
```

### Phase 6: Admin UI

#### 6.1 Generate Video Button

```erb
<%# app/views/site_admin/properties/_video_generation.html.erb %>
<div class="bg-white rounded-lg shadow p-6">
  <h3 class="text-lg font-semibold mb-4">Video Generation</h3>

  <% if @property.photos.count < 3 %>
    <p class="text-gray-500">
      Add at least 3 photos to generate a video.
    </p>
  <% else %>
    <div class="space-y-4">
      <% %w[showcase slideshow landscape square].each do |template| %>
        <% video = @property.property_videos.find_by(template: template) %>
        <div class="flex items-center justify-between p-3 border rounded-lg">
          <div>
            <span class="font-medium"><%= template.titleize %></span>
            <% if video&.completed? %>
              <span class="ml-2 text-sm text-green-600">Ready</span>
            <% elsif video&.processing? %>
              <span class="ml-2 text-sm text-yellow-600">Processing...</span>
            <% elsif video&.failed? %>
              <span class="ml-2 text-sm text-red-600">Failed</span>
            <% end %>
          </div>

          <div class="flex gap-2">
            <% if video&.completed? && video.video_file.attached? %>
              <%= link_to 'Preview',
                  url_for(video.video_file),
                  target: '_blank',
                  class: 'btn btn-secondary btn-sm' %>
              <%= link_to 'Download',
                  rails_blob_path(video.video_file, disposition: 'attachment'),
                  class: 'btn btn-secondary btn-sm' %>
            <% end %>

            <%= button_to 'Generate',
                site_admin_property_videos_path(@property, property_video: { template: template }),
                method: :post,
                class: 'btn btn-primary btn-sm',
                disabled: video&.processing? %>
          </div>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

## Music and Assets

### Royalty-Free Music Sources

| Source | License | Cost |
|--------|---------|------|
| [Uppbeat](https://uppbeat.io) | Attribution | Free |
| [Pixabay Music](https://pixabay.com/music/) | Pixabay License | Free |
| [Artlist](https://artlist.io) | Universal | $199/year |
| [Epidemic Sound](https://epidemicsound.com) | Commercial | $15/month |

### Recommended Assets Structure

```
video-service/assets/
├── fonts/
│   ├── Inter-Regular.ttf
│   ├── Inter-Bold.ttf
│   └── Playfair-Display.ttf
├── music/
│   ├── upbeat-corporate.mp3
│   ├── elegant-piano.mp3
│   └── modern-ambient.mp3
├── overlays/
│   ├── vignette.png
│   └── lens-flare.png
└── transitions/
    ├── wipe.json
    └── fade.json
```

## Cost Estimation

### Self-Hosted (Recommended for > 500 videos/month)

| Component | Monthly Cost |
|-----------|--------------|
| VPS (4 CPU, 8GB RAM) | $40-80 |
| Storage (R2/S3) | $5-20 |
| CDN bandwidth | $10-50 |
| **Total** | **~$55-150/month** |

Cost per video: ~$0.10-0.30 (at 500 videos/month)

### Serverless (Good for < 500 videos/month)

| Component | Cost |
|-----------|------|
| Lambda compute | ~$0.05-0.15/video |
| Storage | $0.01/video |
| **Total** | **~$0.06-0.16/video** |

### Comparison with Amplifiles

| Volume | Self-Hosted | Serverless | Amplifiles |
|--------|-------------|------------|------------|
| 100/month | $55 ($0.55/vid) | $16 | $100-200 |
| 500/month | $75 ($0.15/vid) | $80 | $500-1000 |
| 2000/month | $150 ($0.075/vid) | $320 | $2000-4000 |

## Future Enhancements

1. **AI Voiceover**: Integrate ElevenLabs or AWS Polly for narration
2. **Music Selection**: AI-based music matching to property style
3. **Multi-language**: Generate videos with localized text
4. **Analytics**: Track video views and engagement
5. **Social Publishing**: Direct posting to Instagram/TikTok via API

## References

- [Revideo Documentation](https://docs.re.video/)
- [Revideo GitHub](https://github.com/redotvideo/revideo)
- [Motion Canvas](https://motioncanvas.io/) (Revideo's foundation)
- [WebCodecs API](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API)
