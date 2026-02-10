import { Composition } from "remotion";
import { ListingVideo, calculateVideoDuration } from "./ListingVideo";
import { ListingVideoSchema, ListingVideoProps } from "./schema";
import { getStyleConfig, getFormatConfig } from "./styles";

/**
 * Default props for previewing in Remotion Studio
 * These match the structure from Video::ScriptGenerator
 */
const defaultProps: ListingVideoProps = {
  property: {
    address: "123 Ocean View Drive, Malibu",
    propertyType: "Luxury Beach House",
    bedrooms: 5,
    bathrooms: 4,
    squareFeet: 4200,
    price: "$4,500,000",
    yearBuilt: 2019,
  },
  scenes: [
    {
      photoIndex: 0,
      photoUrl: "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1920",
      duration: 5,
      caption: "Welcome to this stunning oceanfront property",
      transition: "fade",
    },
    {
      photoIndex: 1,
      photoUrl: "https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1920",
      duration: 5,
      caption: "Spacious open-concept living area with panoramic views",
      transition: "slide",
    },
    {
      photoIndex: 2,
      photoUrl: "https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=1920",
      duration: 5,
      caption: "Gourmet chef's kitchen with premium appliances",
      transition: "fade",
    },
    {
      photoIndex: 3,
      photoUrl: "https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1920",
      duration: 5,
      caption: "Primary suite with private balcony",
      transition: "dissolve",
    },
    {
      photoIndex: 4,
      photoUrl: "https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=1920",
      duration: 5,
      caption: "Resort-style pool and outdoor living space",
      transition: "fade",
    },
  ],
  style: "luxury",
  format: "horizontal_16_9",
  backgroundMusicVolume: 0.15,
  branding: {
    primaryColor: "#1a1a2e",
  },
};

/**
 * Calculate metadata for dynamic duration based on scenes
 */
const calculateMetadata = async ({ props }: { props: ListingVideoProps }) => {
  const fps = 30;
  const styleConfig = getStyleConfig(props.style);
  const formatConfig = getFormatConfig(props.format);
  const durationInFrames = calculateVideoDuration(props.scenes, fps, styleConfig);

  return {
    durationInFrames,
    width: formatConfig.width,
    height: formatConfig.height,
    fps,
  };
};

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* Main listing video composition */}
      <Composition
        id="ListingVideo"
        component={ListingVideo}
        schema={ListingVideoSchema}
        defaultProps={defaultProps}
        calculateMetadata={calculateMetadata}
        // Fallback values (overridden by calculateMetadata)
        durationInFrames={900}
        fps={30}
        width={1920}
        height={1080}
      />

      {/* Vertical format variant for social media */}
      <Composition
        id="ListingVideo-Vertical"
        component={ListingVideo}
        schema={ListingVideoSchema}
        defaultProps={{
          ...defaultProps,
          format: "vertical_9_16",
        }}
        calculateMetadata={calculateMetadata}
        durationInFrames={900}
        fps={30}
        width={1080}
        height={1920}
      />

      {/* Square format variant for Instagram feed */}
      <Composition
        id="ListingVideo-Square"
        component={ListingVideo}
        schema={ListingVideoSchema}
        defaultProps={{
          ...defaultProps,
          format: "square_1_1",
        }}
        calculateMetadata={calculateMetadata}
        durationInFrames={900}
        fps={30}
        width={1080}
        height={1080}
      />
    </>
  );
};
