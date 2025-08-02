# PropertyWebBuilder

Please help support this project by making a contribution to PropertyWebBuilder here: https://opencollective.com/property_web_builder

[![Backers on Open Collective](https://opencollective.com/property_web_builder/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/property_web_builder/sponsors/badge.svg)](#sponsors)
[![Gitter](https://badges.gitter.im/dev-1pr/1pr.svg)](https://gitter.im/property_web_builder/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=body_badge)
[![Open Source Helpers](https://www.codetriage.com/etewiah/property_web_builder/badges/users.svg)](https://www.codetriage.com/etewiah/property_web_builder)


## August 2025 update

For the next month or two I will not be able to spend much time on this project as I have launched a new project that is taking up quite a bit of my time.  It is a house price guessing game ;)

Please check it out here and let me know what you think (and if you would like it to be open-sourced):

[https://housepriceguess.com/](https://housepriceguess.com/)

Right now PropertyWebBuilder is a standalone Ruby on Rails app (it is no longer a Ruby on Rails engine). It has also been upgraded to use Rails 7 and Ruby 3

I am currently working on a Rails 8 upgrade which will use the wonderful vite-ruby gem to re-implement the admin panel with vue.js and the quasar framework:

https://github.com/etewiah/property_web_builder/tree/vite

I have auto-generated some documentation using Devin deepwiki which can be found here:
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


## Install locally

PWB was previously designed to be included as an engine in an existing Ruby on Rails app. This is no longer the case and you can now run it directly as a standalone app.

It can also be installed locally as follows:

```bash
git clone https://github.com/etewiah/property_web_builder.git
cd property_web_builder
rails db:create
rails db:migrate
rails pwb:db:seed
```

## Rails Version

PropertyWebBuilder runs with Rails '~> 6.0'

## Ruby Version

PropertyWebBuilder runs with Ruby >= 3.0.0.


## Features

* Multilingual
* Multi-currency
* Powerful search component
* Fully featured admin panel
* Google maps integration
* Customisable look and feel
* Easily extendable
* Search engine friendly
* Mobile friendly responsive layout
* Fully open source

## Coming soon

These are some features I plan to add over the coming months.  If there is something you need which is not on the list, please let me know.  I am also interested in knowing which of these features I should prioritize.

* Instant price conversions into other currencies
* Migrate admin section from an ember js app to vue js using the quasar framework
* [More languages](https://github.com/etewiah/property_web_builder/issues/4)
* [More themes](https://github.com/etewiah/property_web_builder/issues/3)
* Mobile app (iOS and android)
* [RETS support (to allow synchronizing MLS content)](https://github.com/etewiah/property_web_builder/issues/2)
* Integration with third party apps such as Insightly and Basecamp
* Full calendering functionality for rental properties
* Ability to import WordPress blogs
* Neighbourhood information from Zillow API


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

