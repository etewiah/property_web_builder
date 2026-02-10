# PWB Listing Video - Remotion Proof of Concept

This is a proof-of-concept Remotion implementation for generating property listing videos, as an alternative to Shotstack.

## Overview

This Remotion project replicates the functionality of the current Shotstack-based video generation:

- **Ken Burns effect** on property photos
- **Animated captions** with style-specific typography
- **Smooth transitions** (fade, slide, dissolve)
- **Title card** with property details
- **Voiceover** support
- **Background music** with fade in/out
- **Logo watermark** overlay
- **5 video styles**: professional, luxury, casual, energetic, minimal
- **3 formats**: horizontal (16:9), vertical (9:16), square (1:1)

## Project Structure

```
remotion/
├── src/
│   ├── ListingVideo.tsx      # Main composition
│   ├── Root.tsx              # Remotion entry point
│   ├── schema.ts             # Zod schemas (matches Rails output)
│   ├── styles.ts             # Style configurations
│   ├── index.ts              # Exports
│   └── components/
│       ├── PhotoScene.tsx    # Ken Burns photo display
│       ├── Caption.tsx       # Animated captions
│       ├── TitleCard.tsx     # Intro/outro title card
│       ├── Logo.tsx          # Watermark overlay
│       ├── AudioLayers.tsx   # Voiceover & background music
│       └── index.ts
├── render-api/
│   ├── index.ts              # Express render server
│   └── package.json
├── package.json
├── tsconfig.json
└── remotion.config.ts
```

## Getting Started

### 1. Install Dependencies

```bash
cd remotion
npm install
```

### 2. Start Remotion Studio

```bash
npm run dev
```

This opens Remotion Studio at http://localhost:3000 where you can:
- Preview the video in real-time
- Adjust props in the sidebar
- Test different styles and formats

### 3. Render a Video

```bash
npm run render
```

This renders the default composition to `out/video.mp4`.

## Integration with Rails

### Option A: Render API Server

Run the render API server and call it from Rails:

```bash
cd render-api
npm install
npm run dev
```

From Rails (`Video::Assembler`):

```ruby
response = Faraday.post("http://localhost:3100/render") do |req|
  req.headers["Content-Type"] = "application/json"
  req.body = {
    props: {
      property: { address: "123 Main St", bedrooms: 3 },
      scenes: [
        { photoIndex: 0, photoUrl: "https://...", duration: 5, caption: "Welcome", transition: "fade" }
      ],
      style: "professional",
      format: "horizontal_16_9",
      voiceoverUrl: "https://..."
    }
  }.to_json
end
```

### Option B: Remotion Lambda (Recommended for Production)

Deploy to AWS Lambda for serverless rendering:

```bash
npx remotion lambda sites create
npx remotion lambda functions deploy
```

Then call from Rails using the AWS SDK.

See: https://www.remotion.dev/docs/lambda

## Props Schema

The `ListingVideoProps` schema matches the output from your existing `Video::ScriptGenerator`:

```typescript
{
  property: {
    address: string,
    propertyType?: string,
    bedrooms?: number,
    bathrooms?: number,
    squareFeet?: number,
    price?: string,
    yearBuilt?: number
  },
  scenes: [
    {
      photoIndex: number,
      photoUrl: string,
      duration: number,      // seconds
      caption: string,
      transition: "fade" | "slide" | "zoom" | "dissolve"
    }
  ],
  style: "professional" | "luxury" | "casual" | "energetic" | "minimal",
  format: "vertical_9_16" | "horizontal_16_9" | "square_1_1",
  voiceoverUrl?: string,
  backgroundMusicUrl?: string,
  backgroundMusicVolume?: number,  // 0-1, default 0.2
  branding?: {
    logoUrl?: string,
    primaryColor?: string,
    secondaryColor?: string
  }
}
```

## Customization

### Adding New Styles

Edit `src/styles.ts` to add new style configurations:

```typescript
export const STYLE_CONFIGS: Record<VideoStyle, StyleConfig> = {
  // ... existing styles
  modern: {
    fontFamily: "'Poppins', sans-serif",
    fontSize: 32,
    // ...
  }
};
```

Don't forget to update the Zod schema in `src/schema.ts`.

### Custom Transitions

Remotion supports custom transition presentations. See the `@remotion/transitions` docs.

### Adding Overlays

You can add light leak effects, particle overlays, etc. using `@remotion/light-leaks` or custom components.

## Comparison with Shotstack

| Feature | Shotstack | Remotion |
|---------|-----------|----------|
| Rendering | Cloud API | Self-hosted / Lambda |
| Cost | Per render | Compute only |
| Customization | Limited | Unlimited (React) |
| Preview | None | Real-time Studio |
| Ken Burns | Basic | Full control |
| Transitions | 4 types | 5+ built-in, custom |
| Typography | Limited fonts | Any font |
| Development | JSON timeline | React components |

## Next Steps

1. **Test rendering** with your actual property photos
2. **Set up Remotion Lambda** for production
3. **Update Rails `Video::Assembler`** to call Remotion instead of Shotstack
4. **Add custom transitions** or effects as needed
5. **Performance testing** to compare render times
