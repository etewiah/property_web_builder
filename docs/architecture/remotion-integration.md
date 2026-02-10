# Remotion Integration for Listing Videos

This document describes how to integrate Remotion as an alternative to Shotstack for generating listing videos.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Rails Application                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  GenerateListingVideoJob                                             │
│       │                                                              │
│       ├── Video::ScriptGenerator    (unchanged - AI script)         │
│       │                                                              │
│       ├── Video::VoiceoverGenerator (unchanged - TTS audio)         │
│       │                                                              │
│       ├── Video::TemplateBuilder    (REPLACE with params builder)   │
│       │                                                              │
│       └── Video::Assembler          (MODIFY to call Remotion)       │
│                                                                      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               │ HTTP POST /render
                               │ (or AWS Lambda invocation)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Remotion Service                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Option A: Express Render API                                        │
│  ─────────────────────────────                                       │
│  - Self-hosted Node.js server                                        │
│  - Uses @remotion/renderer                                           │
│  - Good for development/testing                                      │
│                                                                      │
│  Option B: Remotion Lambda (Recommended)                             │
│  ────────────────────────────────────────                            │
│  - Serverless AWS Lambda functions                                   │
│  - Scales automatically                                              │
│  - Pay-per-render pricing                                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Rails Adapter Example

Here's how to modify `Video::Assembler` to use Remotion:

```ruby
# app/services/video/remotion_assembler.rb
module Video
  class RemotionAssembler
    RENDER_API_URL = ENV.fetch("REMOTION_RENDER_URL", "http://localhost:3100")
    RENDER_TIMEOUT = 600 # 10 minutes

    def initialize(listing_video)
      @listing_video = listing_video
      @website = listing_video.website
    end

    def call
      response = render_video

      if response["success"]
        download_and_attach_video(response["videoUrl"])
        {
          success: true,
          duration_frames: response["durationInFrames"],
          cost_cents: calculate_cost
        }
      else
        raise RenderError, response["error"]
      end
    end

    private

    def render_video
      connection.post("/render") do |req|
        req.headers["Content-Type"] = "application/json"
        req.options.timeout = RENDER_TIMEOUT
        req.body = build_props.to_json
      end.body
    end

    def build_props
      {
        props: {
          property: build_property_data,
          scenes: build_scenes,
          style: @listing_video.style,
          format: @listing_video.format,
          voiceoverUrl: @listing_video.voiceover_url,
          backgroundMusicUrl: select_background_music,
          backgroundMusicVolume: 0.2,
          branding: build_branding
        },
        compositionId: composition_id,
        outputFileName: "listing-#{@listing_video.id}"
      }
    end

    def build_property_data
      asset = @listing_video.realty_asset
      {
        address: asset.full_address,
        propertyType: asset.property_type&.titleize,
        bedrooms: asset.bedrooms,
        bathrooms: asset.bathrooms,
        squareFeet: asset.square_feet,
        price: format_price(asset.for_sale_price),
        yearBuilt: asset.year_built
      }.compact
    end

    def build_scenes
      @listing_video.scenes.map.with_index do |scene, index|
        {
          photoIndex: index,
          photoUrl: scene["photo_url"],
          duration: scene["duration"],
          caption: scene["caption"],
          transition: scene["transition"]
        }
      end
    end

    def build_branding
      return nil unless @website.logo.attached?

      {
        logoUrl: url_for(@website.logo),
        primaryColor: @website.primary_color
      }.compact
    end

    def composition_id
      case @listing_video.format
      when "vertical_9_16" then "ListingVideo-Vertical"
      when "square_1_1" then "ListingVideo-Square"
      else "ListingVideo"
      end
    end

    def connection
      @connection ||= Faraday.new(url: RENDER_API_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def calculate_cost
      # Remotion Lambda cost is ~$0.01-0.02 per render
      # Much cheaper than Shotstack's $0.05
      2 # cents
    end

    class RenderError < StandardError; end
  end
end
```

## Remotion Lambda Setup

For production, use Remotion Lambda:

### 1. Install CLI

```bash
cd remotion
npm install @remotion/lambda
```

### 2. Configure AWS

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_REGION=us-east-1
```

### 3. Deploy

```bash
# Create S3 site bucket
npx remotion lambda sites create --site-name=pwb-listing-video

# Deploy Lambda function
npx remotion lambda functions deploy --memory=2048 --timeout=240
```

### 4. Rails Lambda Adapter

```ruby
# app/services/video/remotion_lambda_assembler.rb
require "aws-sdk-lambda"

module Video
  class RemotionLambdaAssembler
    FUNCTION_NAME = ENV.fetch("REMOTION_LAMBDA_FUNCTION")
    SERVE_URL = ENV.fetch("REMOTION_SERVE_URL")

    def initialize(listing_video)
      @listing_video = listing_video
    end

    def call
      # Invoke Remotion Lambda
      response = lambda_client.invoke(
        function_name: FUNCTION_NAME,
        payload: {
          type: "start",
          serveUrl: SERVE_URL,
          composition: composition_id,
          inputProps: build_props,
          codec: "h264",
          outName: "listing-#{@listing_video.id}.mp4"
        }.to_json
      )

      result = JSON.parse(response.payload.read)

      # Poll for completion or use webhook
      poll_for_completion(result["renderId"])
    end

    private

    def lambda_client
      @lambda_client ||= Aws::Lambda::Client.new(region: "us-east-1")
    end

    # ... rest of implementation
  end
end
```

## Cost Comparison

| Provider | Per-Video Cost | 1000 Videos/Month |
|----------|----------------|-------------------|
| Shotstack | $0.05 | $50 |
| Remotion Lambda | ~$0.015 | ~$15 |
| Self-hosted | Compute only | Variable |

## Migration Checklist

- [ ] Set up Remotion project (`remotion/`)
- [ ] Test rendering locally with `npm run dev`
- [ ] Deploy to Remotion Lambda or self-host
- [ ] Create `Video::RemotionAssembler` service
- [ ] Add feature flag for Remotion vs Shotstack
- [ ] Test with real property data
- [ ] Compare output quality
- [ ] Monitor render times and costs
- [ ] Full migration once validated
