# Introduction to the Standalone Quasar Frontend

This documentation provides a comprehensive guide to building and deploying a standalone frontend for the PropertyWebBuilder application using the Quasar framework. A standalone frontend offers several advantages over a traditional monolithic architecture, including:

- **Improved Performance:** By decoupling the frontend from the Rails backend, we can serve the user interface from a dedicated static host, reducing latency and improving load times.
- **Enhanced Scalability:** The frontend and backend can be scaled independently, allowing us to allocate resources more efficiently based on application demand.
- **Better Developer Experience:** A modern frontend framework like Quasar provides a more productive and enjoyable development experience, with features like hot-reloading, a rich component library, and a powerful CLI.
- **Future-Proof Architecture:** A standalone frontend makes it easier to adopt new technologies and frameworks in the future without requiring a complete rewrite of the application.

## Project Setup

To get started, you will need to install the Quasar CLI and create a new project. The following steps will guide you through the process:

1. **Install the Quasar CLI:**

   ```bash
   npm install -g @quasar/cli
   ```

2. **Create a new Quasar project:**

   ```bash
   quasar create pwb-frontend
   ```

3. **Configure the project:**

   - **Select a preset:** Choose the `Vue 3` preset.
   - **Choose a CSS preprocessor:** Select `Sass with SCSS syntax`.
   - **Select a feature:** Enable `TypeScript` and `ESLint`.
   - **Choose a linting preset:** Select a preset that best fits your coding style.
   - **Enable features:** Enable `Vuex` and `Axios`.

4. **Navigate to the project directory:**

   ```bash
   cd pwb-frontend
   ```

5. **Start the development server:**

   ```bash
   quasar dev
   ```

Once the development server is running, you can access the application at `http://localhost:8080`.

## Directory Structure

A well-organized directory structure is essential for maintaining a large frontend application. We recommend the following structure for the new Quasar project:

```
pwb-frontend/
├── src/
│   ├── assets/
│   ├── components/
│   ├── layouts/
│   ├── pages/
│   ├── router/
│   ├── store/
│   └── boot/
├── public/
├── quasar.conf.js
├── package.json
└── ...
```

- **`src/assets`:** Static assets such as images, fonts, and stylesheets.
- **`src/components`:** Reusable Vue.js components.
- **`src/layouts`:** Application layouts that define the overall structure of the user interface.
- **`src/pages`:** Page components that are mapped to routes.
- **`src/router`:** Vue Router configuration.
- **`src/store`:** Vuex store modules for managing application state.
- **`src/boot`:** Boot files for initializing libraries and setting up the application.

This structure provides a solid foundation for building a scalable and maintainable frontend application. In the following sections, we will cover API integration, authentication, component migration, Google Maps integration, and deployment in more detail.

- [Google Maps Integration](./google_maps.md)

