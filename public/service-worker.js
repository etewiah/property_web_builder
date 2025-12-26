// PropertyWebBuilder Service Worker
// Provides offline caching and performance optimization

const CACHE_NAME = 'pwb-cache-v1';
const STATIC_CACHE_NAME = 'pwb-static-v1';
const IMAGE_CACHE_NAME = 'pwb-images-v1';

// Static assets to pre-cache
const STATIC_ASSETS = [
  '/',
  '/offline.html'
];

// Cache strategies
const CACHE_STRATEGIES = {
  // Network first, fall back to cache
  networkFirst: async (request) => {
    try {
      const response = await fetch(request);
      if (response.ok) {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, response.clone());
      }
      return response;
    } catch (error) {
      const cached = await caches.match(request);
      return cached || caches.match('/offline.html');
    }
  },

  // Cache first, fall back to network
  cacheFirst: async (request) => {
    const cached = await caches.match(request);
    if (cached) return cached;

    try {
      const response = await fetch(request);
      if (response.ok) {
        const cache = await caches.open(STATIC_CACHE_NAME);
        cache.put(request, response.clone());
      }
      return response;
    } catch (error) {
      return new Response('Offline', { status: 503 });
    }
  },

  // Stale while revalidate - return cached, fetch in background
  staleWhileRevalidate: async (request) => {
    const cache = await caches.open(IMAGE_CACHE_NAME);
    const cached = await cache.match(request);

    const fetchPromise = fetch(request).then(response => {
      if (response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    }).catch(() => cached);

    return cached || fetchPromise;
  }
};

// Install event - pre-cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE_NAME)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          .filter(name => name.startsWith('pwb-') &&
                         name !== CACHE_NAME &&
                         name !== STATIC_CACHE_NAME &&
                         name !== IMAGE_CACHE_NAME)
          .map(name => caches.delete(name))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch event - apply caching strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') return;

  // Skip admin/editor routes
  if (url.pathname.startsWith('/admin') ||
      url.pathname.startsWith('/site_admin') ||
      url.pathname.includes('edit_mode=true')) {
    return;
  }

  // Images - stale while revalidate
  if (request.destination === 'image' ||
      url.pathname.match(/\.(jpg|jpeg|png|gif|webp|svg|ico)$/i) ||
      url.hostname === 'seed-assets.propertywebbuilder.com') {
    event.respondWith(CACHE_STRATEGIES.staleWhileRevalidate(request));
    return;
  }

  // Static assets (JS, CSS, fonts) - cache first
  if (request.destination === 'script' ||
      request.destination === 'style' ||
      request.destination === 'font' ||
      url.pathname.match(/\.(js|css|woff2?)$/i)) {
    event.respondWith(CACHE_STRATEGIES.cacheFirst(request));
    return;
  }

  // HTML pages - network first
  if (request.destination === 'document' ||
      request.headers.get('Accept')?.includes('text/html')) {
    event.respondWith(CACHE_STRATEGIES.networkFirst(request));
    return;
  }

  // Default - network first
  event.respondWith(CACHE_STRATEGIES.networkFirst(request));
});
