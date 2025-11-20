# API Integration and Authentication

This guide explains how to connect your standalone Quasar frontend to the PropertyWebBuilder Rails API, handle authentication, and manage user sessions.

## Configuring API Communication

To enable communication between the Quasar application and the Rails API, you need to configure the API endpoint in your frontend project.

### Environment Variables

Create a `.env` file in the root of your Quasar project to store environment-specific variables. For local development, this file should contain the following:

```
VUE_APP_API_URL=http://localhost:3000/api/v1
```

Replace the URL with your production API endpoint in your deployment environment.

### Making API Requests

We recommend using `axios` for making API requests. The Quaso CLI should have already installed it, but if not, you can add it to your project with:

```bash
npm install axios
```

Create a boot file to configure a global `axios` instance with the API endpoint:

**`src/boot/axios.js`**

```javascript
import axios from 'axios';

const api = axios.create({
  baseURL: process.env.VUE_APP_API_URL,
  withCredentials: true, // Important for sessions
});

export { api };
```

## Authentication

The PropertyWebBuilder API uses Devise for user authentication. Here’s how to implement login, logout, and session management in your Quasar app.

### User Login

Create a login form that collects the user's email and password. When the form is submitted, send a POST request to the `/users/sign_in` endpoint:

```javascript
import { api } from 'boot/axios';

async function login(email, password) {
  try {
    const response = await api.post('/users/sign_in', {
      user: { email, password },
    });
    // Handle successful login
  } catch (error) {
    // Handle login error
  }
}
```

### User Logout

To log out a user, send a DELETE request to the `/users/sign_out` endpoint:

```javascript
async function logout() {
  try {
    await api.delete('/users/sign_out');
    // Handle successful logout
  } catch (error) {
    // Handle logout error
  }
}
```

### Protecting Routes

Use Vue Router's navigation guards to protect routes that require authentication. Check for a valid user session before allowing access to a protected route:

```javascript
// src/router/index.js
import { createRouter, createWebHistory } from 'vue-router';
import routes from './routes';

const Router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes,
});

Router.beforeEach((to, from, next) => {
  if (to.matched.some(record => record.meta.requiresAuth)) {
    // Check for user session
    if (!isAuthenticated()) {
      next({
        path: '/login',
        query: { redirect: to.fullPath }
      });
    } else {
      next();
    }
  } else {
    next();
  }
});

function isAuthenticated() {
  // Implement your session check logic here
  // For example, check for a valid session cookie or token
  return false;
}

export default Router;
```
