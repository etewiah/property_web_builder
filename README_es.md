# PropertyWebBuilder

[![Build Status](https://api.travis-ci.org/etewiah/property_web_builder.svg?branch=master)](https://api.travis-ci.org/etewiah/property_web_builder)

Este proyecto ha sido creado para llenar un gran vacio en el ecosistema rails: la falta de un proyecto opensource para sitios de bienes raices.

El resultado de esto es que wordpress se ha convertido en la herramienta dominante para crear sitios de bienes raices. Esto está lejos de lo ideal y PropertyWebBuilder busca solucionarlo.

Lee más sobre esto aquí: [http://propertywebbuilder.com](http://propertywebbuilder.com)

## [Demo](https://propertywebbuilder.herokuapp.com/)

Puedes probar una demo en [https://propertywebbuilder.herokuapp.com](https://propertywebbuilder.herokuapp.com/)

Para ver el panel de administrador, ingresa como el usuario admin@example.com con el password "pwb123456".

![pwb_iphone_landing](https://cloud.githubusercontent.com/assets/1741198/22990222/bfec0168-f3b8-11e6-89df-b950c4979970.png)

## Versión de Rails

PropertyWebBuilder funciona con Rails >= 5.1

## Versión de Ruby

PropertyWebBuilder funciona con Ruby >= 2.0.0.


## Instalación

Instala sobre un proyecto rails existente añadiendo estas líneas en el Gemfile de tu aplicación:

```ruby
gem 'pwb', git: 'https://github.com/etewiah/property_web_builder', branch: 'master'
gem 'globalize', git: 'https://github.com/globalize/globalize'
```

También asegurate de usar Postgres como base de datos (teniendo la gema "pg" y postgres instalado localmente )
Y luego ejecuta:
```bash
$ bundle
```
Monta PropertyWebBuilder añadiendo lo siguiente a tu archivo routs.rb:
```ruby
mount Pwb::Engine => '/'
```

y ejecuta los commandos ff desde la consola:
```bash
rails pwb:install:migrations
rails db:create
rails db:migrate
rails pwb:db:seed
rails pwb:db:seed_pages
```


## Utilizar con Heroku

PropertyWebBuilder se puede desplegar a heroku en unos minutos.

Este proyecto tiene instrucciones completas sobre cómo utilizar con heroku:

[Https://github.com/etewiah/pwb-for-heroku](https://github.com/etewiah/pwb-for-heroku)

O simplemente [registrarse en Heroku](https://signup.heroku.com/identity) y haz click en el botón de abajo:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/etewiah/pwb-for-heroku)

Puede ver un ejemplo de un sitio creado con PropertyWebBuilder aquí:

[Http://re-renting.propertywebbuilder.com](http://re-renting.com)

## Características

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

## Próximamente

Estas son algunas características que planeo añadir en los próximos meses. Si hay algo que te gustaría y no está en la lista, por favor házmelo saber. También estoy interesado en saber cuales de estas caracteristicas debería priorizar.

* More languages
* More themes
* Mobile app (iOS and android)
* RETS support (to allow synchronizing MLS content)
* Integration with third party apps such as Insightly and Basecamp
* Full calendering functionality for rental properties
* Ability to import WordPress blogs
* Neighbourhood information from Zillow API
* Instant price conversions into other currencies

## Contribuir y difundir el amor
Los animamos a que contribuyan a este proyecto y reporten issues para cualquier problema que encuentren.

Si te gusta, por favor dale una estrella al proyecto y corre la voz en [Twitter](https://twitter.com/prptywebbuilder), [LinkedIn](https://www.linkedin.com/company/propertywebbuilder) y [Facebook](https://www.facebook.com/propertywebbuilder).  También te puedes suscribir a las notificaciones de este proyecto en github.

Por favor considera hacer una contribución al desarrollo de PropertyWebBuilder. Si deseas pagar por una mejora específica, por favor envíame un correo directamente (opensource en propertywebbuilder.com).

Me gustaría que PropertyWebBuilder esté disponible en la mayor cantidad de idiomas posible, por lo que cualquer ayuda en traducir se agradecería mucho. Una versión en español de este documento se puede encontrar aquí:
[https://github.com/etewiah/property_web_builder/blob/master/README_es.md](https://github.com/etewiah/property_web_builder/blob/master/README_es.md)


## Patrocinadores

PropertyWebBuilder actualmente es patrocinado por Coddde, consultores de Ruby On Rails basados en España y Chile:
<a href="http://coddde.com/en/" rel="Coddde">
![Coddde](http://coddde.com/wp-content/uploads/2017/01/coddde_logo.png)
</a>

Si deseas patrocinar este projecto, por favor envíame un email diractamente (opensource en propertywebbuilder.com).


## Licencia
La gema está disponible en código abierto bajo los terminos de [Licencia MIT](http://opensource.org/licenses/MIT).
