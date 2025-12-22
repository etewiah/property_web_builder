import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    // Bundle analyzer - run with ANALYZE=true to generate report
    process.env.ANALYZE && visualizer({
      open: true,
      filename: 'tmp/bundle-stats.html',
      gzipSize: true,
      brotliSize: true,
    })
  ].filter(Boolean),
})
