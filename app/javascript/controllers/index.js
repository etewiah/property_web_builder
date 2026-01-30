// This file registers all Stimulus controllers
// Uses bare specifiers to work with importmaps and CDN asset hosting
// DO NOT use relative imports (./xxx) - they won't resolve correctly with CDN

import { application } from "controllers/application"

// Existing controllers
import DropdownController from "controllers/dropdown_controller"
application.register("dropdown", DropdownController)

import FilterController from "controllers/filter_controller"
application.register("filter", FilterController)

import GalleryController from "controllers/gallery_controller"
application.register("gallery", GalleryController)

import TabsController from "controllers/tabs_controller"
application.register("tabs", TabsController)

import ToggleController from "controllers/toggle_controller"
application.register("toggle", ToggleController)

// New controllers (jQuery migration)
import ContactFormController from "controllers/contact_form_controller"
application.register("contact-form", ContactFormController)

import MapController from "controllers/map_controller"
application.register("map", MapController)

import LeafletMapController from "controllers/leaflet_map_controller"
application.register("leaflet-map", LeafletMapController)

import SearchFormController from "controllers/search_form_controller"
application.register("search-form", SearchFormController)

import SearchController from "controllers/search_controller"
application.register("search", SearchController)

import SearchHeaderController from "controllers/search_header_controller"
application.register("search-header", SearchHeaderController)

import ThemePaletteController from "controllers/theme_palette_controller"
application.register("theme-palette", ThemePaletteController)

import SkeletonController from "controllers/skeleton_controller"
application.register("skeleton", SkeletonController)

import LocationPickerController from "controllers/location_picker_controller"
application.register("location-picker", LocationPickerController)

import PriceGameController from "controllers/price_game_controller"
application.register("price-game", PriceGameController)

// Local storage controllers (GDPR-compliant)
import ConsentController from "controllers/consent_controller"
application.register("consent", ConsentController)

import LocalFavoritesController from "controllers/local_favorites_controller"
application.register("local-favorites", LocalFavoritesController)

import LocalSearchesController from "controllers/local_searches_controller"
application.register("local-searches", LocalSearchesController)

// AI content generation
import AiDescriptionController from "controllers/ai_description_controller"
application.register("ai-description", AiDescriptionController)
