# PropertyWebBuilder

[![Build Status](https://api.travis-ci.org/etewiah/property_web_builder.svg?branch=master)](https://api.travis-ci.org/etewiah/property_web_builder)

This project has been created to address a glaring gap in the rails ecosystem: the lack of an open source project for real estate websites.  

The result is that WordPress has become the dominant tool for creating real estate websites.  This is far from ideal and PropertyWebBuilder seeks to address this.

Read more about this here: [http://propertywebbuilder.com](http://propertywebbuilder.com)

##[Demo](https://propertywebbuilder.herokuapp.com/)

You can try out a demo at [https://propertywebbuilder.herokuapp.com](https://propertywebbuilder.herokuapp.com/)

To see the admin panel, login as user admin@example.com with a password of "pwb123456".

![pwb_iphone_landing](https://cloud.githubusercontent.com/assets/1741198/22990222/bfec0168-f3b8-11e6-89df-b950c4979970.png)

## Rails Version

PropertyWebBuilder runs with Rails '>= 5.0.0', '< 5.1'
Support for Rails 5.1.0 will come soon

## Ruby Version

PropertyWebBuilder runs with Ruby >= 2.0.0.


## Installation

Install into an existing Rails project by adding these lines in your applications's Gemfile:

```ruby
gem 'pwb', git: 'https://github.com/etewiah/property_web_builder', branch: 'master'
gem 'globalize', git: 'https://github.com/globalize/globalize'
gem 'paloma', github: 'fredngo/paloma'
```

Also, be sure to use Postgres as your database (by having the "pg" gem and Postgres installed locally 
And then execute:
```bash
$ bundle
```

Mount the PropertyWebBuilder by adding the following to your routes.rb file:
```ruby
mount Pwb::Engine => '/'
```

and run the ff commands from the console:
```bash
rails pwb:install:migrations
rails db:create
rails db:migrate
rails pwb:db:seed
```

## Deploying to Heroku

PropertyWebBuilder can be deployed to heroku in a few minutes.

You can use this sample project with full instructions on deploying to heroku:

[https://github.com/etewiah/pwb-for-heroku](https://github.com/etewiah/pwb-for-heroku)


If you are too lazy to read about deploying, you can simply [sign up for Heroku](https://signup.heroku.com/identity) and click the button below:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/etewiah/pwb-for-heroku)

You can see an example of a site created with PropertyWebBuilder here:

[http://re-renting.com](http://re-renting.com)

And a video about how to deploy to heroku here:

[![Depoly PWB to heroku](http://img.youtube.com/vi/hyapXTwGyr4/0.jpg)](http://www.youtube.com/watch?v=hyapXTwGyr4 "Deploy PWB to heroku")

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

* [More languages](https://github.com/etewiah/property_web_builder/issues/4)
* [More themes](https://github.com/etewiah/property_web_builder/issues/3)
* Mobile app (iOS and android)
* [RETS support (to allow synchronizing MLS content)](https://github.com/etewiah/property_web_builder/issues/2)
* Integration with third party apps such as Insightly and Basecamp
* Full calendering functionality for rental properties
* Ability to import WordPress blogs
* Neighbourhood information from Zillow API
* Instant price conversions into other currencies


## Contribute and spread the love
We encourage you to contribute to this project and file issues for any problems you encounter.

If you like it, please star it and spread the word on [Twitter](https://twitter.com/prptywebbuilder), [LinkedIn](https://www.linkedin.com/company/propertywebbuilder) and [Facebook](https://www.facebook.com/propertywebbuilder).  You can also subscribe to github notifications on this project.  

Please consider making a contribution to the development of PropertyWebBuilder.  If you wish to pay for specific enhancements, please email me directly (opensource at propertywebbuilder.com).

I would like PropertyWebBuilder to be available in as many languages as possible so any help with translations will be much appreciated.  A basic Spanish version of this document can be found here:
[https://github.com/etewiah/property_web_builder/blob/master/README_es.md](https://github.com/etewiah/property_web_builder/blob/master/README_es.md)

---

Thanks to the awesome [Locale](http://www.localeapp.com/) contributing to the translations is super easy!

- Edit the translations directly on the [property_web_builder](http://www.localeapp.com/projects/public?search=property_web_builder) project on Locale.
- **That's it!**
- The maintainer will then pull translations from the Locale project and push to Github.


## Sponsors

PropertyWebBuilder is currently sponsored by Coddde, Ruby On Rails consultants based in Spain and Chile:
<a href="http://coddde.com/en/" rel="Coddde">
![Coddde](http://coddde.com/wp-content/uploads/2017/01/coddde_logo.png)
</a>

If you wish to sponsor this project please email me directly (opensource at propertywebbuilder.com).


## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

