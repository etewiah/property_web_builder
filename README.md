<p align="center">
  <img src="app/assets/images/pwb_logo.svg" alt="PropertyWebBuilder Logo" width="400">
</p>

# PropertyWebBuilder: real estate sites, real fast ⚡

Please help support this project by making a contribution to PropertyWebBuilder here: https://opencollective.com/property_web_builder

[![Backers on Open Collective](https://opencollective.com/property_web_builder/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/property_web_builder/sponsors/badge.svg)](#sponsors)
[![Gitter](https://badges.gitter.im/dev-1pr/1pr.svg)](https://gitter.im/property_web_builder/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=body_badge)
[![Open Source Helpers](https://www.codetriage.com/etewiah/property_web_builder/badges/users.svg)](https://www.codetriage.com/etewiah/property_web_builder)


## Version 2.1.0 - December 2025

PropertyWebBuilder continues to evolve with powerful new features for property websites.

### Latest Updates (v2.1)

**Embeddable Property Widgets**
- Embed property listings on any external website
- JavaScript and iframe embed options
- Customizable themes, colors, and layouts
- Domain restrictions for security
- Impression and click analytics

**Enhanced Admin Experience**
- Interactive map location picker for properties
- Improved dashboard with quick actions
- Setup wizard for new websites
- Multiple color palettes per theme (10 total)
- Better navigation organization

**Developer Improvements**
- Comprehensive request specs for all controllers
- Idempotent seeding (prevents duplicate data)
- Organized documentation structure
- E2E testing with Playwright support

---

## Version 2.0.0 Released - December 2025

PropertyWebBuilder 2.0 is a major release representing 5 years of development and 500+ commits since v1.4.0. This is essentially a complete rewrite with a modern architecture.

### What's New in 2.0

**Architecture Changes:**
- Converted from Rails engine to standalone application
- Full multi-tenancy with `acts_as_tenant` gem
- Dual admin interfaces: `site_admin` (super admin) and `tenant_admin` (per-tenant)
- New property model architecture: `RealtyAsset` with separate `SaleListing`/`RentalListing`

**Tech Stack Upgrades:**
- Rails 5.2 → 8.0
- Ruby 3.4.7
- Bootstrap → Tailwind CSS for public themes
- Globalize → Mobility for translations
- Cloudinary → ActiveStorage (S3/R2 compatible)

**New Features:**
- Seed packs system for scenario-based site setup
- Firebase authentication with Devise fallback
- New themes: Brisbane (luxury), Bologna, Bristol
- Enhanced theming with CSS variables and Liquid templates
- Faceted search with field key filtering
- Comprehensive SEO implementation
- Audit logging for authentication events
- Push notifications via ntfy.sh

See the full [CHANGELOG](./CHANGELOG.md) for details.


## Get your own instance of PropertyWebBuilder in minutes

<!-- You can try out a demo at [https://pwb-v2.herokuapp.com](https://pwb-v2.herokuapp.com/)

To see the admin panel, login as user admin@example.com with a password of "pwb123456". -->

The easiest way to try out PropertyWebBuilder is to sign up for a free trial account at [https://propertywebbuilder.com](https://propertywebbuilder.com).


![pwb_iphone_landing](https://cloud.githubusercontent.com/assets/1741198/22990222/bfec0168-f3b8-11e6-89df-b950c4979970.png)


<!-- [![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/etewiah/property_web_builder)

Here is a video about how to deploy to heroku:

[![Depoly PWB to heroku](http://img.youtube.com/vi/hyapXTwGyr4/0.jpg)](http://www.youtube.com/watch?v=hyapXTwGyr4 "Deploy PWB to heroku") -->


## Installation & Development

For detailed development instructions, including setup, testing, and troubleshooting, please refer to [DEVELOPMENT.md](DEVELOPMENT.md).

For comprehensive documentation covering architecture, APIs, frontend implementation, and more, visit the [Documentation Portal](./docs/).


### Branches

- **`master`** - Stable releases only. Use this for production deployments.
- **`develop`** - Active development. May contain work-in-progress features.

For production use, we recommend checking out a specific release tag:
```bash
git checkout v2.0.0
```

For detailed documentation, see the [docs folder](./docs/), which includes:
- [API Documentation](./docs/04_API.md)
- [Frontend Documentation](./docs/05_Frontend.md)
- [Multi-Tenancy Guide](./docs/multi_tenancy/README.md)
- [Theming System](./docs/11_Theming_System.md)
- [Seeding Guide](./docs/seeding/)
- [Deployment Guides](./docs/deployment/) for 10+ platforms

Additional auto-generated documentation is available at:
[https://deepwiki.com/etewiah/property_web_builder](https://deepwiki.com/etewiah/property_web_builder)



## Rails Version

PropertyWebBuilder runs with Rails '~> 8.0'

## Ruby Version

PropertyWebBuilder runs with Ruby 3.4.7 or higher.


## Features

* **Modern Tech Stack** - Rails 8, Ruby 3.4.7, Tailwind CSS
* **Multi-Tenancy** - Host multiple websites from a single installation
* **Multilingual** - Support for multiple languages with Mobility gem
* **Multi-currency** - Handle properties in different currencies
* **Powerful Search** - Faceted search with field key filtering
* **Dual Admin Panels** - Site admin (super admin) and tenant admin interfaces
* **Embeddable Widgets** - Embed property listings on external websites with customizable themes
* **Firebase Auth** - Optional Firebase authentication with Devise fallback
* **Modern Themes** - Brisbane, Bologna, Bristol themes with Tailwind CSS and color palettes
* **Seed Packs** - Scenario-based seeding for quick site setup
* **Google Maps Integration** - Interactive property maps with location picker
* **Customisable** - CSS variables, Liquid templates, page parts system
* **SEO Friendly** - Comprehensive SEO implementation
* **Responsive Design** - Mobile-friendly layouts
* **ActiveStorage** - S3/R2 compatible file storage (Cloudflare R2, AWS S3)
* **Setup Wizard** - Guided onboarding for new websites
* **Fully Open Source** - MIT License

## Deployment Options

PropertyWebBuilder can be deployed to multiple platforms. We have comprehensive deployment guides for:

* **[Render](./docs/deployment/render.md)** - Easy deployment with automatic builds
* **[Heroku](https://heroku.com/deploy?template=https://github.com/etewiah/property_web_builder)** - One-click deployment (no longer free)
* **[Dokku](./docs/deployment/dokku.md)** - Self-hosted PaaS
* **[Cloud66](./docs/deployment/cloud66.md)** - DevOps automation
* **[Koyeb](./docs/deployment/koyeb.md)** - Serverless platform
* **[Northflank](./docs/deployment/northflank.md)** - Developer platform
* **[Qoddi](./docs/deployment/qoddi.md)** - App hosting platform
* **[AlwaysData](./docs/deployment/alwaysdata.md)** - Hosting provider
* **[DomCloud](./docs/deployment/domcloud.md)** - Cloud hosting
* **[Argonaut](./docs/deployment/argonaut.md)** - Deployment automation
* **[Coherence](./docs/deployment/withcoherence.md)** - Full-stack cloud platform

For development setup instructions, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Coming Soon

These are features planned for future releases. If there's something you need that's not on the list, please let us know. Your feedback helps us prioritize!

* **Property Comparisons** - Side-by-side property comparison tool
* **Saved Searches** - Allow users to save and receive alerts for new matches
* **Virtual Tours** - 360° photo and video tour integration
* **Mobile Apps** - iOS and Android native apps
* ~~**RETS/IDX Support**~~ - *(Deprecated - RETS protocol being phased out; consider RESO Web API)*
* **CRM Integrations** - HubSpot, Salesforce, Pipedrive
* **Rental Calendar** - Availability and booking for short-term rentals
* **AI Property Descriptions** - Auto-generate property descriptions
* **More Languages** - [Help with translations appreciated!](https://github.com/etewiah/property_web_builder/issues/4)
* **More Themes** - [Community theme contributions welcome](https://github.com/etewiah/property_web_builder/issues/3)


## Contribute and spread the love
We encourage you to contribute to this project and file issues for any problems you encounter.

If you like it, please star it and spread the word on [Twitter](https://twitter.com/prptywebbuilder), [LinkedIn](https://www.linkedin.com/company/propertywebbuilder) and [Facebook](https://www.facebook.com/propertywebbuilder).  You can also subscribe to github notifications on this project.

Please consider making a contribution to the development of PropertyWebBuilder.  If you wish to pay for specific enhancements, please email me directly (opensource at propertywebbuilder.com).

<!--
---

Thanks to the awesome [Locale](http://www.localeapp.com/) contributing to the translations is super easy!

- Edit the translations directly on the [property_web_builder](http://www.localeapp.com/projects/public?search=property_web_builder) project on Locale.
- **That's it!**
- The maintainer will then pull translations from the Locale project and push to Github.
-->

## Contributors

This project exists thanks to all the people who contribute. [[Contribute]](CONTRIBUTING.md).
<a href="https://github.com/etewiah/property_web_builder/graphs/contributors"><img src="https://opencollective.com/property_web_builder/contributors.svg?width=890" /></a>


## Backers

Thank you to all our backers! 🙏 [[Become a backer](https://opencollective.com/property_web_builder#backer)]

<a href="https://opencollective.com/property_web_builder#backers" target="_blank"><img src="https://opencollective.com/property_web_builder/backers.svg?width=890"></a>


## Sponsors

Support this project by becoming a sponsor. Your logo will show up here with a link to your website. [[Become a sponsor](https://opencollective.com/property_web_builder#sponsor)]

<a href="https://opencollective.com/property_web_builder/sponsor/0/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/1/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/2/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/3/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/4/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/5/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/6/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/7/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/8/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/property_web_builder/sponsor/9/website" target="_blank"><img src="https://opencollective.com/property_web_builder/sponsor/9/avatar.svg"></a>



## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

