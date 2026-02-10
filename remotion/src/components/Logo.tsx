import {
  AbsoluteFill,
  Img,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { VideoFormat } from "../schema";

interface LogoProps {
  logoUrl: string;
  format: VideoFormat;
  position?: "top-left" | "top-right" | "bottom-left" | "bottom-right";
}

/**
 * Logo watermark overlay component
 *
 * Displays a semi-transparent logo in the corner of the video.
 * Fades in at the start and persists throughout.
 */
export const Logo: React.FC<LogoProps> = ({
  logoUrl,
  format,
  position = "top-right",
}) => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();

  // Fade in over 0.5 seconds
  const fadeInDuration = 0.5 * fps;
  const opacity = interpolate(frame, [0, fadeInDuration], [0, 0.8], {
    extrapolateRight: "clamp",
  });

  // Logo size relative to video width
  const logoSize = width * 0.12; // 12% of video width

  // Margin from edges
  const margin = format === "vertical_9_16" ? 30 : 40;

  // Position styles based on corner
  const positionStyles: React.CSSProperties = {};
  switch (position) {
    case "top-left":
      positionStyles.top = margin;
      positionStyles.left = margin;
      break;
    case "top-right":
      positionStyles.top = margin;
      positionStyles.right = margin;
      break;
    case "bottom-left":
      positionStyles.bottom = margin;
      positionStyles.left = margin;
      break;
    case "bottom-right":
      positionStyles.bottom = margin;
      positionStyles.right = margin;
      break;
  }

  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <Img
        src={logoUrl}
        style={{
          position: "absolute",
          width: logoSize,
          height: "auto",
          maxHeight: logoSize,
          objectFit: "contain",
          opacity,
          filter: "drop-shadow(0 2px 4px rgba(0,0,0,0.3))",
          ...positionStyles,
        }}
      />
    </AbsoluteFill>
  );
};
