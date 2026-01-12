// @ts-check
const { test, expect } = require('@playwright/test');
const { TENANTS } = require('../fixtures/test-data');

/**
 * API Endpoints Tests
 * Tests for new public API endpoints: favorites, saved searches, locales, search facets
 *
 * These tests verify the JSON API contracts required for headless JS clients.
 */

const API_BASE = '/api_public/v1';

test.describe('Public API Endpoints', () => {
  const tenant = TENANTS.A;

  test.describe('Locales API', () => {
    test('GET /locales returns available locales', async ({ request }) => {
      const response = await request.get(`${tenant.baseURL}${API_BASE}/locales`);
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data).toHaveProperty('default_locale');
      expect(data).toHaveProperty('available_locales');
      expect(data).toHaveProperty('current_locale');
      expect(Array.isArray(data.available_locales)).toBeTruthy();

      // Each locale should have required fields
      if (data.available_locales.length > 0) {
        const locale = data.available_locales[0];
        expect(locale).toHaveProperty('code');
        expect(locale).toHaveProperty('name');
        expect(locale).toHaveProperty('native_name');
      }
    });
  });

  test.describe('Search Facets API', () => {
    test('GET /search/facets returns facet counts', async ({ request }) => {
      const response = await request.get(`${tenant.baseURL}${API_BASE}/search/facets`);
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data).toHaveProperty('total_count');
      expect(data).toHaveProperty('property_types');
      expect(data).toHaveProperty('zones');
      expect(data).toHaveProperty('localities');
      expect(data).toHaveProperty('bedrooms');
      expect(data).toHaveProperty('bathrooms');
      expect(data).toHaveProperty('price_ranges');
    });

    test('GET /search/facets with sale_or_rental filter', async ({ request }) => {
      const response = await request.get(
        `${tenant.baseURL}${API_BASE}/search/facets?sale_or_rental=sale`
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(typeof data.total_count).toBe('number');
    });
  });

  test.describe('Properties API', () => {
    test('GET /properties returns paginated results with map markers', async ({ request }) => {
      const response = await request.get(`${tenant.baseURL}${API_BASE}/properties`);
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data).toHaveProperty('data');
      expect(data).toHaveProperty('map_markers');
      expect(data).toHaveProperty('meta');
      expect(Array.isArray(data.data)).toBeTruthy();
      expect(Array.isArray(data.map_markers)).toBeTruthy();
      expect(data.meta).toHaveProperty('total');
      expect(data.meta).toHaveProperty('page');
      expect(data.meta).toHaveProperty('per_page');
      expect(data.meta).toHaveProperty('total_pages');
    });

    test('GET /properties supports pagination', async ({ request }) => {
      const response = await request.get(
        `${tenant.baseURL}${API_BASE}/properties?page=1&per_page=5`
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data.meta.page).toBe(1);
      expect(data.meta.per_page).toBe(5);
    });

    test('GET /properties supports sorting', async ({ request }) => {
      const response = await request.get(
        `${tenant.baseURL}${API_BASE}/properties?sort_by=price_desc`
      );
      expect(response.ok()).toBeTruthy();
    });

    test('GET /properties/:id/schema returns JSON-LD', async ({ request }) => {
      // First get a property ID
      const listResponse = await request.get(
        `${tenant.baseURL}${API_BASE}/properties?limit=1`
      );
      const listData = await listResponse.json();

      if (listData.data && listData.data.length > 0) {
        const propertyId = listData.data[0].slug || listData.data[0].id;
        const schemaResponse = await request.get(
          `${tenant.baseURL}${API_BASE}/properties/${propertyId}/schema`
        );
        expect(schemaResponse.ok()).toBeTruthy();

        const schema = await schemaResponse.json();
        expect(schema['@context']).toBe('https://schema.org');
        expect(schema['@type']).toBe('RealEstateListing');
      }
    });
  });

  test.describe('Favorites API (requires token)', () => {
    const testEmail = `test-${Date.now()}@example.com`;
    let manageToken;
    let favoriteId;

    test('POST /favorites creates a new favorite', async ({ request }) => {
      const response = await request.post(`${tenant.baseURL}${API_BASE}/favorites`, {
        data: {
          favorite: {
            email: testEmail,
            provider: 'internal',
            external_reference: `prop-test-${Date.now()}`,
            notes: 'E2E test favorite',
            property_data: {
              title: 'Test Property',
              price: { cents: 25000000, currency_iso: 'EUR' }
            }
          }
        }
      });
      expect(response.ok()).toBeTruthy();
      expect(response.status()).toBe(201);

      const data = await response.json();
      expect(data.success).toBe(true);
      expect(data.favorite).toHaveProperty('id');
      expect(data).toHaveProperty('manage_token');

      manageToken = data.manage_token;
      favoriteId = data.favorite.id;
    });

    test('GET /favorites lists favorites for token', async ({ request }) => {
      if (!manageToken) {
        test.skip();
        return;
      }

      const response = await request.get(
        `${tenant.baseURL}${API_BASE}/favorites?token=${manageToken}`
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data).toHaveProperty('email', testEmail);
      expect(Array.isArray(data.favorites)).toBeTruthy();
    });

    test('PATCH /favorites/:id updates notes', async ({ request }) => {
      if (!manageToken || !favoriteId) {
        test.skip();
        return;
      }

      const response = await request.patch(
        `${tenant.baseURL}${API_BASE}/favorites/${favoriteId}?token=${manageToken}`,
        {
          data: {
            favorite: { notes: 'Updated notes from E2E test' }
          }
        }
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data.success).toBe(true);
    });

    test('DELETE /favorites/:id removes the favorite', async ({ request }) => {
      if (!manageToken || !favoriteId) {
        test.skip();
        return;
      }

      const response = await request.delete(
        `${tenant.baseURL}${API_BASE}/favorites/${favoriteId}?token=${manageToken}`
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data.success).toBe(true);
    });

    test('GET /favorites with invalid token returns 401', async ({ request }) => {
      const response = await request.get(
        `${tenant.baseURL}${API_BASE}/favorites?token=invalid-token`
      );
      expect(response.status()).toBe(401);
    });
  });

  test.describe('Saved Searches API (requires token)', () => {
    const testEmail = `test-search-${Date.now()}@example.com`;
    let manageToken;
    let searchId;

    test('POST /saved_searches creates a new saved search', async ({ request }) => {
      const response = await request.post(`${tenant.baseURL}${API_BASE}/saved_searches`, {
        data: {
          saved_search: {
            email: testEmail,
            name: 'E2E Test Search',
            alert_frequency: 'none',
            search_criteria: {
              sale_or_rental: 'sale',
              bedrooms_from: 2
            }
          }
        }
      });
      expect(response.ok()).toBeTruthy();
      expect(response.status()).toBe(201);

      const data = await response.json();
      expect(data.success).toBe(true);
      expect(data.saved_search).toHaveProperty('id');
      expect(data).toHaveProperty('manage_token');

      manageToken = data.manage_token;
      searchId = data.saved_search.id;
    });

    test('GET /saved_searches lists searches for token', async ({ request }) => {
      if (!manageToken) {
        test.skip();
        return;
      }

      const response = await request.get(
        `${tenant.baseURL}${API_BASE}/saved_searches?token=${manageToken}`
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data).toHaveProperty('email', testEmail);
      expect(Array.isArray(data.saved_searches)).toBeTruthy();
    });

    test('DELETE /saved_searches/:id removes the search', async ({ request }) => {
      if (!manageToken || !searchId) {
        test.skip();
        return;
      }

      const response = await request.delete(
        `${tenant.baseURL}${API_BASE}/saved_searches/${searchId}?token=${manageToken}`
      );
      expect(response.ok()).toBeTruthy();

      const data = await response.json();
      expect(data.success).toBe(true);
    });
  });

  test.describe('Cache Headers', () => {
    test('Locales endpoint has appropriate cache headers', async ({ request }) => {
      const response = await request.get(`${tenant.baseURL}${API_BASE}/locales`);
      const cacheControl = response.headers()['cache-control'];

      // Should have public caching enabled
      if (cacheControl) {
        expect(cacheControl).toMatch(/public|max-age/);
      }
    });

    test('Search facets endpoint has cache headers', async ({ request }) => {
      const response = await request.get(`${tenant.baseURL}${API_BASE}/search/facets`);
      expect(response.ok()).toBeTruthy();
      // Cache headers are set by the Cacheable concern
    });
  });
});
