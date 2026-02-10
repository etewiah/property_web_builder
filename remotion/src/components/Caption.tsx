import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { VideoStyle, VideoFormat } from "../schema";
import { getStyleConfig } from "../styles";

interface CaptionProps {
  text: string;
  style: VideoStyle;
  format: VideoFormat;
}

/**
 * Caption component with fade-in animation
 *
 * Captions appear at the bottom of the screen with style-specific
 * typography and background colors.
 */
export const Caption: React.FC<CaptionProps> = ({ text, style, format }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const styleConfig = getStyleConfig(style);

  // Fade in over 0.3 seconds
  const fadeInDuration = 0.3 * fps;
  const opacity = interpolate(frame, [0, fadeInDuration], [0, 1], {
    extrapolateRight: "clamp",
  });

  // Slide up slightly as it fades in
  const translateY = interpolate(frame, [0, fadeInDuration], [20, 0], {
    extrapolateRight: "clamp",
  });

  // Position adjustments based on format
  const bottomPadding = format === "vertical_9_16" ? "15%" : "8%";
  const maxWidth = format === "vertical_9_16" ? "85%" : "70%";

  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        paddingBottom: bottomPadding,
      }}
    >
      <div
        style={{
          opacity,
          transform: `translateY(${translateY}px)`,
          backgroundColor: styleConfig.captionBgColor,
          color: styleConfig.captionTextColor,
          fontFamily: styleConfig.fontFamily,
          fontSize: styleConfig.fontSize,
          fontWeight: styleConfig.fontWeight,
          padding: styleConfig.captionPadding,
          borderRadius: styleConfig.captionBorderRadius,
          maxWidth,
          textAlign: "center",
          lineHeight: 1.4,
          boxShadow: "0 4px 12px rgba(0, 0, 0, 0.3)",
        }}
      >
        {text}
      </div>
    </AbsoluteFill>
  );
};

/**
 * Typewriter caption variant
 * Text appears character by character
 */
export const TypewriterCaption: React.FC<CaptionProps> = ({
  text,
  style,
  format,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const styleConfig = getStyleConfig(style);

  // Characters per second
  const cps = 30;
  const charactersToShow = Math.floor((frame / fps) * cps);
  const displayText = text.slice(0, charactersToShow);

  // Only show if we have characters
  if (displayText.length === 0) return null;

  const bottomPadding = format === "vertical_9_16" ? "15%" : "8%";
  const maxWidth = format === "vertical_9_16" ? "85%" : "70%";

  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        paddingBottom: bottomPadding,
      }}
    >
      <div
        style={{
          backgroundColor: styleConfig.captionBgColor,
          color: styleConfig.captionTextColor,
          fontFamily: styleConfig.fontFamily,
          fontSize: styleConfig.fontSize,
          fontWeight: styleConfig.fontWeight,
          padding: styleConfig.captionPadding,
          borderRadius: styleConfig.captionBorderRadius,
          maxWidth,
          textAlign: "center",
          lineHeight: 1.4,
          boxShadow: "0 4px 12px rgba(0, 0, 0, 0.3)",
        }}
      >
        {displayText}
        {displayText.length < text.length && (
          <span
            style={{
              opacity: Math.sin(frame * 0.3) > 0 ? 1 : 0,
              marginLeft: 2,
            }}
          >
            |
          </span>
        )}
      </div>
    </AbsoluteFill>
  );
};
