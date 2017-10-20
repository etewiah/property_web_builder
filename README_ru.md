# PropertyWebBuilder

[![Build Status](https://api.travis-ci.org/etewiah/property_web_builder.svg?branch=master)](https://api.travis-ci.org/etewiah/property_web_builder)

Среди всех проектов с открытым исходным кодом написанных на ruby on rails так никто и не решился написать решение для сайтов по продаже и аренде неджвижимости.  
В результате WordPress стал чуть ли не единственным инструментом для быстрого создания сайтов данной тематики. 
К сожалению его решение далеко от иделала. Чтобы компенсировать этот недостаток, проект PropertyBuilder пытается решить эту проблему. 
Данный проект написан с открытым исходным кодом на фреймворке Ruby On Rails.

Более подробнее можно прочить здесь: [http://propertywebbuilder.com](http://propertywebbuilder.com)

##[Demo](https://propertywebbuilder.herokuapp.com/)

Для начала можете посмотреть демо версию [https://propertywebbuilder.herokuapp.com](https://propertywebbuilder.herokuapp.com/)

Изучить функционал панели администратора можно авторизоваться со следующими данными: логин admin@example.com, пароль "pwb123456".

![pwb_iphone_landing](https://cloud.githubusercontent.com/assets/1741198/22990222/bfec0168-f3b8-11e6-89df-b950c4979970.png)

## Версия Rails

PropertyWebBuilder должна быть запущена с Rails >= 5.1.0

## Версия Ruby

PropertyWebBuilder  должна быть запущена с Ruby >= 2.0.0.


## Установка

В существующий проект Rails добавьте в Gemfile следующие строки:

```ruby
gem 'pwb', git: 'https://github.com/etewiah/property_web_builder', branch: 'master'
gem 'globalize', git: 'https://github.com/globalize/globalize'

```

Также убедитесь, что использутете базу данных Postgres(путем установки гема 'pg' и локальной версии Postgres) 
И после запустите:
```bash
$ bundle
```
Установитe PropertyWebBuilder, добавив следующие строки в файл routes.rb

```ruby
mount Pwb::Engine => '/'
```
И запустите следующие команды из коносоли:

```bash
rails pwb:install:migrations
rails db:create
rails db:migrate
rails pwb:db:seed
rails pwb:db:seed_pages
```