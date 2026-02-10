import { AbsoluteFill, Sequence, useVideoConfig } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { wipe } from "@remotion/transitions/wipe";

import { ListingVideoProps, Scene } from "./schema";
import { getStyleConfig } from "./styles";
import {
  PhotoScene,
  Caption,
  Logo,
  TitleCard,
  Voiceover,
  BackgroundMusic,
} from "./components";

/**
 * ListingVideo - Main composition for property listing videos
 *
 * This composition creates a professional real estate video with:
 * - Title card intro with property details
 * - Photo slideshow with Ken Burns effect
 * - Animated captions for each scene
 * - Smooth transitions between scenes
 * - Voiceover narration
 * - Background music
 * - Logo watermark
 *
 * The video style (professional, luxury, casual, etc.) affects
 * typography, colors, animation timing, and overall feel.
 */
export const ListingVideo: React.FC<ListingVideoProps> = ({
  scenes,
  property,
  style,
  format,
  voiceoverUrl,
  backgroundMusicUrl,
  backgroundMusicVolume = 0.2,
  branding,
}) => {
  const { fps } = useVideoConfig();
  const styleConfig = getStyleConfig(style);

  // Title card duration (3 seconds)
  const titleCardDuration = fps * 3;

  // Calculate scene durations in frames
  const sceneDurations = scenes.map((scene) => scene.duration * fps);

  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      {/* Title Card Intro */}
      <Sequence durationInFrames={titleCardDuration}>
        <TitleCard
          property={property}
          style={style}
          format={format}
          primaryColor={branding?.primaryColor}
        />
      </Sequence>

      {/* Photo Scenes with Transitions */}
      <Sequence from={titleCardDuration}>
        <TransitionSeries>
          {scenes.map((scene, index) => (
            <TransitionSeries.Sequence
              key={index}
              durationInFrames={sceneDurations[index]}
            >
              <SceneWithCaption
                scene={scene}
                style={style}
                format={format}
                sceneIndex={index}
              />
              {index < scenes.length - 1 && (
                <TransitionSeries.Transition
                  presentation={getTransitionPresentation(
                    scenes[index + 1]?.transition || "fade"
                  )}
                  timing={linearTiming({
                    durationInFrames: styleConfig.transitionDuration,
                  })}
                />
              )}
            </TransitionSeries.Sequence>
          ))}
        </TransitionSeries>
      </Sequence>

      {/* Logo Watermark (throughout video) */}
      {branding?.logoUrl && <Logo logoUrl={branding.logoUrl} format={format} />}

      {/* Audio Layers */}
      {voiceoverUrl && <Voiceover url={voiceoverUrl} startFrame={titleCardDuration} />}
      {backgroundMusicUrl && (
        <BackgroundMusic url={backgroundMusicUrl} volume={backgroundMusicVolume} />
      )}
    </AbsoluteFill>
  );
};

/**
 * Scene with photo and caption combined
 */
interface SceneWithCaptionProps {
  scene: Scene;
  style: ListingVideoProps["style"];
  format: ListingVideoProps["format"];
  sceneIndex: number;
}

const SceneWithCaption: React.FC<SceneWithCaptionProps> = ({
  scene,
  style,
  format,
  sceneIndex,
}) => {
  return (
    <AbsoluteFill>
      <PhotoScene scene={scene} style={style} sceneIndex={sceneIndex} />
      {scene.caption && (
        <Caption text={scene.caption} style={style} format={format} />
      )}
    </AbsoluteFill>
  );
};

/**
 * Map transition type to Remotion presentation
 */
function getTransitionPresentation(transition: Scene["transition"]) {
  switch (transition) {
    case "slide":
      return slide({ direction: "from-left" });
    case "zoom":
      // Remotion doesn't have a built-in zoom, use fade as fallback
      return fade();
    case "dissolve":
      return fade();
    case "fade":
    default:
      return fade();
  }
}

/**
 * Calculate total video duration based on scenes
 */
export function calculateVideoDuration(
  scenes: Scene[],
  fps: number,
  styleConfig: ReturnType<typeof getStyleConfig>
): number {
  const titleCardDuration = fps * 3;
  const sceneDuration = scenes.reduce((sum, scene) => sum + scene.duration * fps, 0);
  const transitionOverlap = (scenes.length - 1) * styleConfig.transitionDuration;

  return titleCardDuration + sceneDuration - transitionOverlap;
}
