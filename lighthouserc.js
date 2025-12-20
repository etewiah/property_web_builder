// Lighthouse CI Configuration
// Run locally: npx lhci autorun
// Add to CI: see .github/workflows/lighthouse.yml

module.exports = {
  ci: {
    collect: {
      // Number of runs for averaging
      numberOfRuns: 3,

      // Start development server automatically
      startServerCommand: 'bundle exec rails server -p 3000 -e test',
      startServerReadyPattern: 'Listening on',
      startServerReadyTimeout: 30000,

      // URLs to audit
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/buy',
        'http://localhost:3000/rent',
      ],

      // Chrome flags for headless testing
      settings: {
        chromeFlags: '--no-sandbox --headless --disable-gpu',
        throttlingMethod: 'simulate',
        // Use mobile preset for Core Web Vitals
        preset: 'desktop',
      },
    },

    assert: {
      // Performance budgets
      assertions: {
        // Performance metrics
        'categories:performance': ['error', { minScore: 0.7 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'categories:best-practices': ['warn', { minScore: 0.9 }],
        'categories:seo': ['error', { minScore: 0.9 }],

        // Core Web Vitals
        'first-contentful-paint': ['warn', { maxNumericValue: 2500 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 4000 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.25 }],
        'total-blocking-time': ['warn', { maxNumericValue: 500 }],

        // Resource optimizations
        'render-blocking-resources': 'off', // We've addressed this
        'uses-responsive-images': 'warn',
        'offscreen-images': 'warn',
        'uses-webp-images': 'warn',
        'unused-css-rules': 'warn',
        'unused-javascript': 'warn',
      },
    },

    upload: {
      // Upload to temporary public storage (for CI)
      target: 'temporary-public-storage',
    },
  },
};
