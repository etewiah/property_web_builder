import { Sequence, useVideoConfig, interpolate } from "remotion";
import { Audio } from "@remotion/media";

interface VoiceoverProps {
  url: string;
  startFrame?: number;
}

/**
 * Voiceover audio component
 *
 * Plays the AI-generated voiceover narration at full volume.
 */
export const Voiceover: React.FC<VoiceoverProps> = ({
  url,
  startFrame = 0,
}) => {
  return (
    <Sequence from={startFrame}>
      <Audio src={url} volume={1} />
    </Sequence>
  );
};

interface BackgroundMusicProps {
  url: string;
  volume?: number;
}

/**
 * Background music component
 *
 * Plays ambient music at a low volume with fade-in and fade-out.
 * Volume is kept low so it doesn't compete with voiceover.
 */
export const BackgroundMusic: React.FC<BackgroundMusicProps> = ({
  url,
  volume = 0.2,
}) => {
  const { fps, durationInFrames } = useVideoConfig();

  // Fade in over 1 second, fade out over 2 seconds
  const fadeInDuration = fps;
  const fadeOutDuration = fps * 2;
  const fadeOutStart = durationInFrames - fadeOutDuration;

  return (
    <Audio
      src={url}
      volume={(f) => {
        // Fade in
        if (f < fadeInDuration) {
          return interpolate(f, [0, fadeInDuration], [0, volume], {
            extrapolateRight: "clamp",
          });
        }
        // Fade out
        if (f > fadeOutStart) {
          return interpolate(
            f,
            [fadeOutStart, durationInFrames],
            [volume, 0],
            {
              extrapolateRight: "clamp",
            }
          );
        }
        // Normal volume
        return volume;
      }}
      loop
    />
  );
};
