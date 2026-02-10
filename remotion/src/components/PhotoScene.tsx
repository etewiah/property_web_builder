import {
  AbsoluteFill,
  Img,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Scene, VideoStyle } from "../schema";
import { getStyleConfig } from "../styles";

interface PhotoSceneProps {
  scene: Scene;
  style: VideoStyle;
  sceneIndex: number;
}

/**
 * PhotoScene component with Ken Burns effect
 *
 * The Ken Burns effect alternates between:
 * - Even scenes: Zoom in (scale up over time)
 * - Odd scenes: Zoom out (scale down over time)
 *
 * This creates visual variety without custom configuration per scene.
 */
export const PhotoScene: React.FC<PhotoSceneProps> = ({
  scene,
  style,
  sceneIndex,
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const styleConfig = getStyleConfig(style);

  // Calculate the Ken Burns animation
  const isZoomIn = sceneIndex % 2 === 0;
  const baseScale = 1;
  const targetScale = styleConfig.kenBurnsScale;

  // Interpolate scale over the duration of this scene
  const sceneDurationFrames = scene.duration * fps;
  const progress = Math.min(frame / sceneDurationFrames, 1);

  const scale = isZoomIn
    ? interpolate(progress, [0, 1], [baseScale, targetScale], {
        extrapolateRight: "clamp",
      })
    : interpolate(progress, [0, 1], [targetScale, baseScale], {
        extrapolateRight: "clamp",
      });

  // Slight pan effect - alternates direction
  const panDirection = sceneIndex % 4;
  const panAmount = 2; // percentage

  let translateX = 0;
  let translateY = 0;

  switch (panDirection) {
    case 0: // Pan right
      translateX = interpolate(progress, [0, 1], [0, panAmount]);
      break;
    case 1: // Pan down
      translateY = interpolate(progress, [0, 1], [0, panAmount]);
      break;
    case 2: // Pan left
      translateX = interpolate(progress, [0, 1], [0, -panAmount]);
      break;
    case 3: // Pan up
      translateY = interpolate(progress, [0, 1], [0, -panAmount]);
      break;
  }

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#000",
        overflow: "hidden",
      }}
    >
      <Img
        src={scene.photoUrl}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          transform: `scale(${scale}) translate(${translateX}%, ${translateY}%)`,
          transformOrigin: "center center",
        }}
      />
    </AbsoluteFill>
  );
};
