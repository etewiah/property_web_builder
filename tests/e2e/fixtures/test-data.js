/**
 * Test data fixtures for E2E tests
 * These match the seed data created by db/seeds/e2e_seeds.rb
 */

// Tenant configurations
const TENANTS = {
  A: {
    subdomain: 'tenant-a',
    baseURL: 'http://tenant-a.e2e.localhost:3001',
    companyName: 'Tenant A Real Estate',
  },
  B: {
    subdomain: 'tenant-b',
    baseURL: 'http://tenant-b.e2e.localhost:3001',
    companyName: 'Tenant B Real Estate',
  }
};

// Admin user credentials (from e2e_seeds.rb)
const ADMIN_USERS = {
  TENANT_A: {
    email: 'admin@tenant-a.test',
    password: 'password123',
    tenant: TENANTS.A,
  },
  TENANT_B: {
    email: 'admin@tenant-b.test',
    password: 'password123',
    tenant: TENANTS.B,
  }
};

// Test property data
const PROPERTIES = {
  SALE: {
    title: 'Test Sale Property',
    price: '250000',
    bedrooms: '3',
    type: 'for-sale',
  },
  RENTAL: {
    title: 'Test Rental Property',
    price: '1500',
    bedrooms: '2',
    type: 'for-rent',
  }
};

// Page routes
const ROUTES = {
  HOME: '/',
  BUY: '/en/buy',
  RENT: '/en/rent',
  CONTACT: '/contact-us',
  ABOUT: '/about-us',
  LOGIN: '/users/sign_in',
  ADMIN: {
    DASHBOARD: '/site_admin',
    PROPERTIES: '/site_admin/props',
    CONTACTS: '/site_admin/contacts',
    SETTINGS: '/site_admin/properties/settings',
  }
};

module.exports = {
  TENANTS,
  ADMIN_USERS,
  PROPERTIES,
  ROUTES,
};
