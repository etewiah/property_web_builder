import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
} from "remotion";
import { Property, VideoStyle, VideoFormat } from "../schema";
import { getStyleConfig } from "../styles";

interface TitleCardProps {
  property: Property;
  style: VideoStyle;
  format: VideoFormat;
  primaryColor?: string;
}

/**
 * Title card component for intro/outro
 *
 * Displays property address and key details with
 * style-appropriate typography and animations.
 */
export const TitleCard: React.FC<TitleCardProps> = ({
  property,
  style,
  format,
  primaryColor,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const styleConfig = getStyleConfig(style);

  // Spring animation for smooth entry
  const titleScale = spring({
    frame,
    fps,
    config: {
      damping: 200,
      stiffness: 100,
    },
  });

  const titleOpacity = interpolate(frame, [0, fps * 0.5], [0, 1], {
    extrapolateRight: "clamp",
  });

  // Staggered entry for details
  const detailsOpacity = interpolate(
    frame,
    [fps * 0.3, fps * 0.8],
    [0, 1],
    {
      extrapolateRight: "clamp",
    }
  );

  const detailsTranslateY = interpolate(
    frame,
    [fps * 0.3, fps * 0.8],
    [30, 0],
    {
      extrapolateRight: "clamp",
    }
  );

  // Format property details line
  const detailsParts: string[] = [];
  if (property.bedrooms) detailsParts.push(`${property.bedrooms} Bed`);
  if (property.bathrooms) detailsParts.push(`${property.bathrooms} Bath`);
  if (property.squareFeet)
    detailsParts.push(`${property.squareFeet.toLocaleString()} sqft`);
  const detailsLine = detailsParts.join(" | ");

  // Background gradient based on style
  const bgColor = primaryColor || getBackgroundColor(style);

  return (
    <AbsoluteFill
      style={{
        background: bgColor,
        justifyContent: "center",
        alignItems: "center",
        padding: format === "vertical_9_16" ? "10%" : "5%",
      }}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          textAlign: "center",
          gap: 24,
        }}
      >
        {/* Property Address */}
        <h1
          style={{
            fontFamily: styleConfig.fontFamily,
            fontSize: styleConfig.titleFontSize,
            fontWeight: styleConfig.titleFontWeight,
            color: "#ffffff",
            margin: 0,
            opacity: titleOpacity,
            transform: `scale(${titleScale})`,
            textShadow: "0 4px 12px rgba(0, 0, 0, 0.3)",
            lineHeight: 1.2,
          }}
        >
          {property.address}
        </h1>

        {/* Property Type */}
        {property.propertyType && (
          <div
            style={{
              fontFamily: styleConfig.fontFamily,
              fontSize: styleConfig.fontSize * 0.9,
              fontWeight: 400,
              color: "rgba(255, 255, 255, 0.9)",
              opacity: detailsOpacity,
              transform: `translateY(${detailsTranslateY}px)`,
              textTransform: "uppercase",
              letterSpacing: 2,
            }}
          >
            {property.propertyType}
          </div>
        )}

        {/* Property Details */}
        {detailsLine && (
          <div
            style={{
              fontFamily: styleConfig.fontFamily,
              fontSize: styleConfig.fontSize,
              fontWeight: styleConfig.fontWeight,
              color: "rgba(255, 255, 255, 0.95)",
              opacity: detailsOpacity,
              transform: `translateY(${detailsTranslateY}px)`,
            }}
          >
            {detailsLine}
          </div>
        )}

        {/* Price */}
        {property.price && (
          <div
            style={{
              fontFamily: styleConfig.fontFamily,
              fontSize: styleConfig.titleFontSize * 0.8,
              fontWeight: styleConfig.titleFontWeight,
              color: "#ffffff",
              opacity: detailsOpacity,
              transform: `translateY(${detailsTranslateY}px)`,
              marginTop: 16,
            }}
          >
            {property.price}
          </div>
        )}
      </div>
    </AbsoluteFill>
  );
};

/**
 * Get background gradient based on style
 */
function getBackgroundColor(style: VideoStyle): string {
  switch (style) {
    case "professional":
      return "linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)";
    case "luxury":
      return "linear-gradient(135deg, #0f0f0f 0%, #1a1a1a 100%)";
    case "casual":
      return "linear-gradient(135deg, #1e3a5f 0%, #2563eb 100%)";
    case "energetic":
      return "linear-gradient(135deg, #7f1d1d 0%, #dc2626 100%)";
    case "minimal":
      return "linear-gradient(135deg, #18181b 0%, #27272a 100%)";
    default:
      return "#1a1a2e";
  }
}
