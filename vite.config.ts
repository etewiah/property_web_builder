import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import VuePlugin from '@vitejs/plugin-vue'
import { quasar, transformAssetUrls } from '@quasar/vite-plugin'
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  define: {
    // Vue 3 feature flags for production - suppresses dev mode warnings
    // See: https://vuejs.org/api/compile-time-flags.html
    __VUE_OPTIONS_API__: true,
    __VUE_PROD_DEVTOOLS__: false,
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
  },
  plugins: [
    RubyPlugin(),
    VuePlugin({
      template: { transformAssetUrls }
    }),
    quasar({
      // sassVariables: 'src/quasar-variables.sass'
    }),
    // Bundle analyzer - run with ANALYZE=true to generate report
    process.env.ANALYZE && visualizer({
      open: true,
      filename: 'tmp/bundle-stats.html',
      gzipSize: true,
      brotliSize: true,
    })
  ].filter(Boolean),
})
