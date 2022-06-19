import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import VuePlugin from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    VuePlugin(),
  ],
})
