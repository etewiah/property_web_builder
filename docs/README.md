# PropertyWebBuilder Documentation

Welcome to the comprehensive documentation for PropertyWebBuilder - a modern, open-source platform for creating real estate websites.

## 📚 Table of Contents

### Getting Started

- [Main README](../README.md) - Project overview, features, and quick start
- [Development Guide](../DEVELOPMENT.md) - Setup, testing, and troubleshooting
- [Contributing Guidelines](../CONTRIBUTING.md) - How to contribute to the project
- [Changelog](../CHANGELOG.md) - Version history and updates

### Architecture & Implementation

1. [Overview](./01_Overview.md) - High-level architecture and main components
2. [Data Models](./02_Data_Models.md) - Database schema, models, validations, and associations
3. [Controllers](./03_Controllers.md) - Controller actions and request handling
4. [API Documentation](./04_API.md) - RESTful and GraphQL API details
5. [Frontend Architecture](./05_Frontend.md) - Vue.js applications and UI components
6. [Multi-Tenancy](./06_Multi_Tenancy.md) - Multi-tenant architecture and implementation
7. [Assets Management](./07_Assets_Management.md) - Asset pipeline and static files
8. [PagePart System](./08_PagePart_System.md) - Content management with Liquid templates, themes, and localization
9. **[Field Keys](./09_Field_Keys.md)** - Property labeling system for types, features, amenities, and search filtering

### Admin Panel

The admin panel has been completely reimplemented with Vue.js 3 and Quasar framework:

- [Implementation Details](./admin/01_Implementation_Details.md) - Technical implementation overview
- [Quasar Frontend](./admin/02_Quasar_Frontend_Implementation.md) - Standalone Quasar SPA setup

### Quasar Framework Integration

Comprehensive guides for the modern Vue.js 3 + Quasar frontend:

- [Introduction](./quasar/introduction.md) - Getting started with the Quasar frontend
- [API Integration](./quasar/api_integration.md) - Connecting to the Rails backend
- [Component Migration](./quasar/component_migration.md) - Migrating from EmberJS to Vue/Quasar
- [GraphQL Usage](./quasar/graphql.md) - Using GraphQL for data fetching
- [Deployment](./quasar/deployment.md) - Deploying the standalone frontend

### Deployment Guides

PropertyWebBuilder can be deployed to multiple platforms. Choose the one that fits your needs:

#### Popular Platforms
- **[Render](./deployment/render.md)** - Easy deployment with automatic builds and free tier
- **[Heroku](https://heroku.com/deploy?template=https://github.com/etewiah/property_web_builder)** - One-click deployment (no longer free)
- **[Dokku](./deployment/dokku.md)** - Self-hosted PaaS (open-source Heroku alternative)

#### Developer Platforms
- **[Cloud66](./deployment/cloud66.md)** - DevOps automation and orchestration
- **[Northflank](./deployment/northflank.md)** - Modern developer platform
- **[Coherence](./deployment/withcoherence.md)** - Full-stack cloud platform
- **[Argonaut](./deployment/argonaut.md)** - Deployment automation

#### Serverless & Cloud Hosting
- **[Koyeb](./deployment/koyeb.md)** - Serverless platform
- **[Qoddi](./deployment/qoddi.md)** - App hosting platform
- **[AlwaysData](./deployment/alwaysdata.md)** - European hosting provider
- **[DomCloud](./deployment/domcloud.md)** - Affordable cloud hosting

### Additional Documentation

- [Public App Documentation](./v-public-app-documentation.md) - Frontend public-facing application

## 🚀 Tech Stack

PropertyWebBuilder uses modern, industry-standard technologies:

- **Backend**: Ruby on Rails 8.0 with Ruby 3.4.7
- **Frontend**: Vue.js 3 with Quasar Framework
- **Build Tool**: Vite with vite-plugin-ruby
- **Database**: PostgreSQL
- **APIs**: RESTful and GraphQL
- **Maps**: Google Maps integration

## 🔗 External Resources

- **Live Demo**: Previously hosted on Heroku (currently unavailable due to free tier removal)
- **Auto-generated Docs**: [DeepWiki Documentation](https://deepwiki.com/etewiah/property_web_builder)
- **Repository**: [GitHub - etewiah/property_web_builder](https://github.com/etewiah/property_web_builder)
- **Community**: [Gitter Chat](https://gitter.im/property_web_builder/Lobby)

## 🤝 Getting Help

- **Issues**: Report bugs or request features on [GitHub Issues](https://github.com/etewiah/property_web_builder/issues)
- **Discussions**: Join the conversation on [Gitter](https://gitter.im/property_web_builder/Lobby)
- **Contributing**: See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines

## 📝 License

PropertyWebBuilder is open source software licensed under the [MIT License](../MIT-LICENSE).

---

**Last Updated**: December 2024

For the most up-to-date information, always refer to the main [README](../README.md) and individual documentation files.
