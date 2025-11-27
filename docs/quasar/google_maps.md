# Google Maps Integration

PropertyWebBuilder uses Google Maps for displaying property locations and for address autocomplete functionality in the admin panel.

## Configuration

To use Google Maps, you must provide a valid API Key.

1.  **Get an API Key**: Visit the [Google Maps Platform Console](https://console.cloud.google.com/google/maps-apis/overview) and create a project. Enable the **Maps JavaScript API** and **Places API**. Create an API Key.
2.  **Set Environment Variable**:
    - Create a `.env` file in the root of your project (if it doesn't exist).
    - Add the following line:
      ```bash
      VITE_GMAPS_API_KEY=your_actual_api_key_here
      ```

## Implementation Details

The integration uses the [`@fawmi/vue-google-maps`](https://github.com/fawmi/vue-google-maps) library.

### Initialization

The library is initialized with `loading: 'async'` to ensure optimal performance.

-   **Standalone App**: Configured in [`standalone_quasar_app/src/boot/google-maps.js`](../../standalone_quasar_app/src/boot/google-maps.js).
-   **Admin Panel (Rails)**: Configured in [`app/frontend/entrypoints/v-admin.js`](../../app/frontend/entrypoints/v-admin.js).

### Components

#### Map Display
The `MapViewContainer` component is used to display a map with property markers.
-   **Location**: [`standalone_quasar_app/src/components/widgets/MapViewContainer.vue`](../../standalone_quasar_app/src/components/widgets/MapViewContainer.vue)

#### Address Autocomplete
The `PropertyLocationForm` component uses `GMapAutocomplete` for address search and `MapAddressField` for displaying the selected location.
-   **Location**: [`app/frontend/v-admin-app/src/components/editor-forms/PropertyLocationForm.vue`](../../app/frontend/v-admin-app/src/components/editor-forms/PropertyLocationForm.vue)

## Troubleshooting

-   **InvalidKeyMapError**: Ensure your `VITE_GMAPS_API_KEY` is correct and has the necessary APIs enabled (Maps JavaScript API, Places API).
-   **Performance Warnings**: We use `loading: 'async'` to avoid blocking the main thread. If you see warnings, check the console for details.
