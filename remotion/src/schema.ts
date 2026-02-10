import { z } from "zod";
import { zColor } from "@remotion/zod-types";

/**
 * Schema for a single scene in the video
 * Matches the output from Video::ScriptGenerator
 */
export const SceneSchema = z.object({
  photoIndex: z.number(),
  photoUrl: z.string().url(),
  duration: z.number().min(1).max(30),
  caption: z.string(),
  transition: z.enum(["fade", "slide", "zoom", "dissolve"]),
});

/**
 * Video style options matching Ruby Video::ScriptGenerator styles
 */
export const VideoStyleSchema = z.enum([
  "professional",
  "luxury",
  "casual",
  "energetic",
  "minimal",
]);

/**
 * Video format options
 */
export const VideoFormatSchema = z.enum([
  "vertical_9_16",
  "horizontal_16_9",
  "square_1_1",
]);

/**
 * Property details for the intro/outro
 */
export const PropertySchema = z.object({
  address: z.string(),
  propertyType: z.string().optional(),
  bedrooms: z.number().optional(),
  bathrooms: z.number().optional(),
  squareFeet: z.number().optional(),
  price: z.string().optional(),
  yearBuilt: z.number().optional(),
});

/**
 * Branding configuration
 */
export const BrandingSchema = z.object({
  logoUrl: z.string().url().optional(),
  primaryColor: zColor().optional(),
  secondaryColor: zColor().optional(),
});

/**
 * Main schema for the ListingVideo composition
 * This matches the data structure from Rails Video::TemplateBuilder
 */
export const ListingVideoSchema = z.object({
  // Core content
  scenes: z.array(SceneSchema).min(1).max(20),
  property: PropertySchema,

  // Styling
  style: VideoStyleSchema,
  format: VideoFormatSchema,

  // Audio
  voiceoverUrl: z.string().url().optional(),
  backgroundMusicUrl: z.string().url().optional(),
  backgroundMusicVolume: z.number().min(0).max(1).default(0.2),

  // Branding
  branding: BrandingSchema.optional(),

  // Metadata
  title: z.string().optional(),
});

export type Scene = z.infer<typeof SceneSchema>;
export type VideoStyle = z.infer<typeof VideoStyleSchema>;
export type VideoFormat = z.infer<typeof VideoFormatSchema>;
export type Property = z.infer<typeof PropertySchema>;
export type Branding = z.infer<typeof BrandingSchema>;
export type ListingVideoProps = z.infer<typeof ListingVideoSchema>;
