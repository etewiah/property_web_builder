/**
 * Render API for PropertyWebBuilder Listing Videos
 *
 * This is a proof-of-concept Express server that accepts
 * render requests and produces videos using Remotion.
 *
 * In production, consider using Remotion Lambda for serverless rendering:
 * https://www.remotion.dev/docs/lambda
 */

import express from "express";
import { bundle } from "@remotion/bundler";
import { renderMedia, selectComposition } from "@remotion/renderer";
import path from "path";
import fs from "fs";
import { ListingVideoProps } from "../src/schema";

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3100;
const OUTPUT_DIR = process.env.OUTPUT_DIR || "./out";

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

interface RenderRequest {
  props: ListingVideoProps;
  outputFileName?: string;
  compositionId?: string;
}

interface RenderResponse {
  success: boolean;
  videoUrl?: string;
  thumbnailUrl?: string;
  durationInFrames?: number;
  error?: string;
}

/**
 * POST /render
 *
 * Accepts listing video props and renders the video.
 *
 * Request body:
 * {
 *   "props": { ...ListingVideoProps },
 *   "outputFileName": "video-123.mp4",
 *   "compositionId": "ListingVideo" // or "ListingVideo-Vertical"
 * }
 *
 * Response:
 * {
 *   "success": true,
 *   "videoUrl": "/out/video-123.mp4",
 *   "thumbnailUrl": "/out/video-123-thumb.png",
 *   "durationInFrames": 450
 * }
 */
app.post("/render", async (req, res) => {
  const { props, outputFileName, compositionId = "ListingVideo" } =
    req.body as RenderRequest;

  if (!props || !props.scenes || props.scenes.length === 0) {
    return res.status(400).json({
      success: false,
      error: "Missing or invalid props. Must include at least one scene.",
    } as RenderResponse);
  }

  const videoId = outputFileName || `listing-${Date.now()}`;
  const outputPath = path.join(OUTPUT_DIR, `${videoId}.mp4`);
  const thumbnailPath = path.join(OUTPUT_DIR, `${videoId}-thumb.png`);

  console.log(`Starting render for ${videoId}...`);
  console.log(`Composition: ${compositionId}`);
  console.log(`Scenes: ${props.scenes.length}`);
  console.log(`Style: ${props.style}`);
  console.log(`Format: ${props.format}`);

  try {
    // Bundle the Remotion project
    const bundleLocation = await bundle({
      entryPoint: path.resolve(__dirname, "../src/index.ts"),
      webpackOverride: (config) => config,
    });

    // Select the composition with our props
    const composition = await selectComposition({
      serveUrl: bundleLocation,
      id: compositionId,
      inputProps: props,
    });

    console.log(`Video duration: ${composition.durationInFrames} frames`);
    console.log(`Dimensions: ${composition.width}x${composition.height}`);

    // Render the video
    await renderMedia({
      composition,
      serveUrl: bundleLocation,
      codec: "h264",
      outputLocation: outputPath,
      inputProps: props,
      onProgress: ({ progress }) => {
        console.log(`Render progress: ${Math.round(progress * 100)}%`);
      },
    });

    console.log(`Video rendered successfully: ${outputPath}`);

    // TODO: Generate thumbnail at 1 second mark
    // await renderStill({
    //   composition,
    //   serveUrl: bundleLocation,
    //   output: thumbnailPath,
    //   frame: 30,
    //   inputProps: props,
    // });

    res.json({
      success: true,
      videoUrl: outputPath,
      // thumbnailUrl: thumbnailPath,
      durationInFrames: composition.durationInFrames,
    } as RenderResponse);
  } catch (error) {
    console.error("Render failed:", error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    } as RenderResponse);
  }
});

/**
 * GET /health
 *
 * Health check endpoint
 */
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "pwb-listing-video-renderer" });
});

app.listen(PORT, () => {
  console.log(`Remotion render server listening on port ${PORT}`);
  console.log(`Output directory: ${OUTPUT_DIR}`);
});

export { app };
