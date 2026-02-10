import { VideoStyle, VideoFormat } from "./schema";

/**
 * Style configurations matching Ruby Video::TemplateBuilder
 * Each style has its own visual identity
 */
export interface StyleConfig {
  // Typography
  fontFamily: string;
  fontSize: number;
  fontWeight: number;

  // Caption styling
  captionBgColor: string;
  captionTextColor: string;
  captionPadding: number;
  captionBorderRadius: number;

  // Ken Burns effect intensity
  kenBurnsScale: number;

  // Transition duration in frames (at 30fps)
  transitionDuration: number;

  // Title styling
  titleFontSize: number;
  titleFontWeight: number;
}

export const STYLE_CONFIGS: Record<VideoStyle, StyleConfig> = {
  professional: {
    fontFamily: "'Open Sans', sans-serif",
    fontSize: 32,
    fontWeight: 400,
    captionBgColor: "rgba(0, 0, 0, 0.7)",
    captionTextColor: "#ffffff",
    captionPadding: 16,
    captionBorderRadius: 8,
    kenBurnsScale: 1.1,
    transitionDuration: 15, // 0.5 seconds at 30fps
    titleFontSize: 48,
    titleFontWeight: 600,
  },
  luxury: {
    fontFamily: "'Playfair Display', serif",
    fontSize: 36,
    fontWeight: 400,
    captionBgColor: "rgba(0, 0, 0, 0.85)",
    captionTextColor: "#ffffff",
    captionPadding: 20,
    captionBorderRadius: 0, // Sharp edges for luxury feel
    kenBurnsScale: 1.05, // Subtle, elegant movement
    transitionDuration: 24, // 0.8 seconds - slower, more deliberate
    titleFontSize: 56,
    titleFontWeight: 400,
  },
  casual: {
    fontFamily: "'Montserrat', sans-serif",
    fontSize: 30,
    fontWeight: 500,
    captionBgColor: "rgba(37, 99, 235, 0.85)", // Blue background
    captionTextColor: "#ffffff",
    captionPadding: 14,
    captionBorderRadius: 12,
    kenBurnsScale: 1.15, // More noticeable movement
    transitionDuration: 12, // 0.4 seconds - snappier
    titleFontSize: 44,
    titleFontWeight: 600,
  },
  energetic: {
    fontFamily: "'Roboto', sans-serif",
    fontSize: 34,
    fontWeight: 700,
    captionBgColor: "rgba(220, 38, 38, 0.9)", // Red background
    captionTextColor: "#ffffff",
    captionPadding: 12,
    captionBorderRadius: 4,
    kenBurnsScale: 1.2, // Dynamic, dramatic movement
    transitionDuration: 9, // 0.3 seconds - fast cuts
    titleFontSize: 52,
    titleFontWeight: 800,
  },
  minimal: {
    fontFamily: "'Inter', sans-serif",
    fontSize: 28,
    fontWeight: 300,
    captionBgColor: "rgba(0, 0, 0, 0.6)",
    captionTextColor: "#ffffff",
    captionPadding: 12,
    captionBorderRadius: 4,
    kenBurnsScale: 1.03, // Very subtle movement
    transitionDuration: 18, // 0.6 seconds
    titleFontSize: 40,
    titleFontWeight: 300,
  },
};

/**
 * Video dimensions by format
 */
export interface FormatConfig {
  width: number;
  height: number;
}

export const FORMAT_CONFIGS: Record<VideoFormat, FormatConfig> = {
  vertical_9_16: { width: 1080, height: 1920 },
  horizontal_16_9: { width: 1920, height: 1080 },
  square_1_1: { width: 1080, height: 1080 },
};

/**
 * Get the style config for a given style
 */
export function getStyleConfig(style: VideoStyle): StyleConfig {
  return STYLE_CONFIGS[style];
}

/**
 * Get the format config for a given format
 */
export function getFormatConfig(format: VideoFormat): FormatConfig {
  return FORMAT_CONFIGS[format];
}

/**
 * Google Fonts to load for each style
 */
export const GOOGLE_FONTS: Record<VideoStyle, string> = {
  professional: "Open+Sans:wght@400;600",
  luxury: "Playfair+Display:wght@400;500",
  casual: "Montserrat:wght@400;500;600",
  energetic: "Roboto:wght@400;700;800",
  minimal: "Inter:wght@300;400",
};
