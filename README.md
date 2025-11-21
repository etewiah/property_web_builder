# PropertyWebBuilder

Please help support this project by making a contribution to PropertyWebBuilder here: https://opencollective.com/property_web_builder

[![Backers on Open Collective](https://opencollective.com/property_web_builder/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/property_web_builder/sponsors/badge.svg)](#sponsors)
[![Gitter](https://badges.gitter.im/dev-1pr/1pr.svg)](https://gitter.im/property_web_builder/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=body_badge)
[![Open Source Helpers](https://www.codetriage.com/etewiah/property_web_builder/badges/users.svg)](https://www.codetriage.com/etewiah/property_web_builder)


## November 2024 Update

PropertyWebBuilder has been significantly upgraded! 🎉

**Major Updates:**
- ✅ **Rails 8.0** - Upgraded to the latest Rails version with modern features
- ✅ **Ruby 3.4.7** - Running on the latest stable Ruby
- ✅ **Vite Integration** - Fast, modern build tooling with vite-ruby
- ✅ **Vue.js 3 + Quasar** - Admin panel completely reimplemented with modern frontend stack
- ✅ **Comprehensive Documentation** - Extensive docs for API, GraphQL, deployment, and Quasar integration

PropertyWebBuilder is now a standalone Ruby on Rails application (no longer a Rails engine) with a cutting-edge tech stack.

For detailed documentation, see the [docs folder](./docs/), which includes:
- [API Documentation](./docs/04_API.md)
- [Frontend/Vue.js Documentation](./docs/05_Frontend.md)
- [Quasar Implementation Guide](./docs/quasar/)
- [Deployment Guides](./docs/deployment/) for 10+ platforms

Additional auto-generated documentation is available at:
[https://deepwiki.com/etewiah/property_web_builder](https://deepwiki.com/etewiah/property_web_builder)

## Motivation

This project has been created to address a glaring gap in the rails ecosystem: the lack of an open source project for real estate websites.

The result is that WordPress has become the dominant tool for creating real estate websites.  This is far from ideal and PropertyWebBuilder seeks to address this.


## Demo

<!-- You can try out a demo at [https://pwb-v2.herokuapp.com](https://pwb-v2.herokuapp.com/)

To see the admin panel, login as user admin@example.com with a password of "pwb123456". -->

There was previously a demo hosted on heroku but since they ended the free plan I have had to take it down.

![pwb_iphone_landing](https://cloud.githubusercontent.com/assets/1741198/22990222/bfec0168-f3b8-11e6-89df-b950c4979970.png)


## Create your own real estate website with no technical knowledge

The simplest way to create a website with PropertyWebBuilder is to use Heroku, a trusted service provider.  They no longer have the free tier which was a great selling point but are still worth trying out.

Just [sign up for Heroku](https://signup.heroku.com/identity), click the button below and in a few minutes your site will be ready

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/etewiah/property_web_builder)

Here is a video about how to deploy to heroku:

[![Depoly PWB to heroku](http://img.youtube.com/vi/hyapXTwGyr4/0.jpg)](http://www.youtube.com/watch?v=hyapXTwGyr4 "Deploy PWB to heroku")


## Installation & Development

For detailed development instructions, including setup, testing, and troubleshooting, please refer to [DEVELOPMENT.md](DEVELOPMENT.md).

For comprehensive documentation covering architecture, APIs, frontend implementation, and more, visit the [Documentation Portal](./docs/).

## Rails Version

PropertyWebBuilder runs with Rails '~> 8.0'

## Ruby Version

PropertyWebBuilder runs with Ruby 3.4.7 or higher.


## Features

* **Modern Tech Stack** - Rails 8, Ruby 3.4.7, Vue.js 3, Quasar, Vite
* **Multilingual** - Support for multiple languages
* **Multi-currency** - Handle properties in different currencies
* **Powerful Search** - Advanced property search functionality
* **Modern Admin Panel** - Built with Vue.js 3 and Quasar framework
* **Google Maps Integration** - Interactive property maps
* **Customisable** - Flexible look and feel
* **Easily Extendable** - Well-documented architecture
* **SEO Friendly** - Optimized for search engines
* **Responsive Design** - Mobile-friendly layout
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

* Instant price conversions into other currencies
* [More languages](https://github.com/etewiah/property_web_builder/issues/4) - help with translations appreciated!
* [More themes](https://github.com/etewiah/property_web_builder/issues/3)
* Mobile apps (iOS and Android)
* [RETS support](https://github.com/etewiah/property_web_builder/issues/2) - for synchronizing MLS content
* Integration with third-party CRM systems (Insightly, Basecamp)
* Full calendaring functionality for rental properties
* WordPress blog import functionality
* Neighborhood information from Zillow API


## Contribute and spread the love
We encourage you to contribute to this project and file issues for any problems you encounter.

If you like it, please star it and spread the word on [Twitter](https://twitter.com/prptywebbuilder), [LinkedIn](https://www.linkedin.com/company/propertywebbuilder) and [Facebook](https://www.facebook.com/propertywebbuilder).  You can also subscribe to github notifications on this project.

Please consider making a contribution to the development of PropertyWebBuilder.  If you wish to pay for specific enhancements, please email me directly (opensource at propertywebbuilder.com).

I would like PropertyWebBuilder to be available in as many languages as possible so any help with translations will be much appreciated.  A basic Spanish version of this document can be found here:
[https://github.com/etewiah/property_web_builder/blob/master/README_es.md](https://github.com/etewiah/property_web_builder/blob/master/README_es.md)

For instructions on how to add a new language, please see:
[https://github.com/etewiah/property_web_builder/wiki/Adding-translations-for-a-new-language](https://github.com/etewiah/property_web_builder/wiki/Adding-translations-for-a-new-language)
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

