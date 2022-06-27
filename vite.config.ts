import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import VuePlugin from '@vitejs/plugin-vue'
import { quasar, transformAssetUrls } from '@quasar/vite-plugin'

export default defineConfig({
  // define: {
  //   'process.env.GMAPS_API_KEY': JSON.stringify(process.env.GMAPS_API_KEY),
  //   'process.env.DEBUG': JSON.stringify(process.env.DEBUG),
  // },
  plugins: [
    RubyPlugin(),
    VuePlugin({
      template: { transformAssetUrls }
    }),
    quasar({
      // sassVariables: 'src/quasar-variables.sass'
    })
  ],
})
