# PropertyWebBuilder

Lütfen burada PropertyWebBuilder'a bir katkı yaparak bu projeyi desteklemeye yardımcı olun: https://opencollective.com/property_web_builder

[![Backers on Open Collective](https://opencollective.com/property_web_builder/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/property_web_builder/sponsors/badge.svg)](#sponsors)
[![Build Status](https://api.travis-ci.org/etewiah/property_web_builder.svg?branch=master)](https://api.travis-ci.org/etewiah/property_web_builder)
[![Gitter](https://badges.gitter.im/dev-1pr/1pr.svg)](https://gitter.im/property_web_builder/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=body_badge)
[![Open Source Helpers](https://www.codetriage.com/etewiah/property_web_builder/badges/users.svg)](https://www.codetriage.com/etewiah/property_web_builder)

Bu proje raylar ekosisteminde göze batan bir boşluğa hitaben oluşturuldu: emlak web siteleri için açık kaynaklı bir proje eksikliği.

Netice, WordPress'in emlak web siteleri oluşturmak için baskın bir araç haline geldiğidir. Bu idealden uzaktır ve PropertyWebBuilder buna hitap etmek istiyor.

Bunun hakkında daha fazlasını burada okuyun: [http://propertywebbuilder.com](http://propertywebbuilder.com)

## [Demo](https://propertywebbuilder.herokuapp.com/)

Şu adreste bir demo deneyebilirsiniz: [https://propertywebbuilder.herokuapp.com](https://propertywebbuilder.herokuapp.com/)

Admin panelini görmek için, admin@example.com kullanıcısı olarak "pwb123456" şifresi ile oturum açın.

![pwb_iphone_landing](https://cloud.githubusercontent.com/assets/1741198/22990222/bfec0168-f3b8-11e6-89df-b950c4979970.png)

PropertyWebBuilder ile oluşturulan bir yapım sitesinin bir örneğini buradan görebilirsiniz:

[http://re-renting.com](http://re-renting.com)

## Teknik bilginiz olmaksınız kendi gerçek emlak websitenizi oluşturun

PropertyWebBuilder ile bir website oluşturmanın en basit yolu kullanabileceğiniz ücretsiz bir plana sahip güvenilir bir servis sağlayıcı olan Heroku kullanmaktır.

[Heroku için hesap oluştur](https://signup.heroku.com/identity), aşağıdaki butona tıkla ve birkaç dakika içinde siteniz hazır olacak

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/etewiah/pwb-for-heroku)

Bir hesap oluşturduğunuz sırada kredi kartı bilgileri sorulabilir fakat websiteyi oluşturmak ve denemek için ücretlendirilmeyeceksiniz. Sadece hizmeti yükseltirseniz ödeme yapmanız gerekecek. İşte Heroku’nun nasıl uygulanacağı ile ilgili bir video:

[![Depoly PWB to heroku](http://img.youtube.com/vi/hyapXTwGyr4/0.jpg)](http://www.youtube.com/watch?v=hyapXTwGyr4 "Deploy PWB to heroku")


## Bağımsız bir site olarak kurun

PWB, Rails uygulamada mevcut bir Ruby içinde bir motor olarak dahil edilmek için tasarlandı. Bu repoda, PWB içeren Rails uygulamasında bir Ruby’m var.

[https://github.com/etewiah/pwb-for-heroku](https://github.com/etewiah/pwb-for-heroku)

İsimden de anlaşılacağı gibi, proje herokuya uygulanabilir fakat aşağıdaki gibi lokal olarak da kurulabilir:

```bash
git clone https://github.com/etewiah/pwb-for-heroku.git
cd pwb-for-heroku
rails db:create
rails db:migrate
rails pwb:db:seed
rails pwb:db:seed_pages
```


## Mevcut bir Rail uygulaması içinde kurulum

Uygulamanızın Gemfile’I içine şu satırları ekleyerek mevcut  bir Rails projesine kurun:

```ruby
gem 'pwb', git: 'https://github.com/etewiah/property_web_builder', branch: 'master'
gem 'globalize', git: 'https://github.com/globalize/globalize'
gem 'paloma', github: 'fredngo/paloma'
```

Ayrıca, veritabanınız olarak Postgres kullandığınıza emin olun (“pg” gemli ve yerel kurulmuş Postgres yanında – 9.5 sürümü veya üstü)
Ve daha sonra şunu yapın:
```bash
$ bundle
```

routes.rb dosyanıza aşağıdakileri ekleyerek PropertyWebBuilder’ı monte edin:
```ruby
mount Pwb::Engine => '/'
```

ve konsoldan ff komutlarını çalıştırın:
```bash
rails pwb:install:migrations
rails db:create
rails db:migrate
rails pwb:db:seed
rails pwb:db:seed_pages
```

## Rails Sürümü

PropertyWebBuilder  Rails '>= 5.1.0' ile çalışır

## Ruby Sürümü

PropertyWebBuilder Ruby >= 2.0.0 ile çalışır.


## Özellikler

* Çoklu dil
* Çoklu para birimi
* Güçlü arama bileşeni
* Tam özellikli admin paneli
* Google maps entegrasyonu
* Özelleştirilebilir görünüm ve his
* Kolayca uzatılabilir
* Arama motoru dostu
* Mobil dostu duyarlı düzen
* Tamamen açık kaynaklı

## Çok yakında

Bunlar aylar geçtikçe eeklemeyi planladığım bazı özellikler. Listede olmayan ihtiyacınız olan birşey varsa, lütfen bana bildirin. Ayrıca, bu özelliklerden hangisine öncelik vermem gerektiğini bilmekle ilgileniyorum.

* [Daha fazla dil](https://github.com/etewiah/property_web_builder/issues/4)
* [Daha fazla tema](https://github.com/etewiah/property_web_builder/issues/3)
* Mobil uygulama (iOS VE Android))
* [RETS desteği (MLS içeriğini senkronlamaya izin vermek için)](https://github.com/etewiah/property_web_builder/issues/2)
* Insightly ve Basecamp gibi üçüncü parti uygulamalarla entegrasyon
* Kiralık mülkler için tam kalenderleme işlevselliği
* WordPress bloglarını içe aktarma becerisi
* Zillow API’den komşuluk bilgisi
* Diğer para birimlerine anlık fiyat dönüşümleri


## Katkıda bulun ve sevgiyi yay
Karşılaştığınız herhangi bir problem için bu projeye ve dosya sorunlarına katkıda bulunmanız için teşvik ediyoruz.

Hoşunuza gittiyse, yıldızlayın ve haberi [Twitter](https://twitter.com/prptywebbuilder), [LinkedIn](https://www.linkedin.com/company/propertywebbuilder) ve [Facebook](https://www.facebook.com/propertywebbuilder)'da yayın.  Ayrıca bu projede github bildirimlerine de abone olabilirsiniz.

Lütfen PropertyWebBuilder'ın geliştirilmesine katkıda bulunmayı göz önünde bulundurun. Özel artırmalar için ödeme yapmak isterseniz, lütfen bana doğrudan email gönderin (propertywebbuilder.com’da açık kaynak).

PropertyWebBuilder'ın mümkün olduğunca çok dilde kullanışlı olmasını istiyorum, yani çevirilerle ilgili herhangi bir yardım çok değerli olacaktır. Bu belgenin temel bir İspanyolca versiyonu burada bulunabilir:
[https://github.com/etewiah/property_web_builder/blob/master/README_es.md](https://github.com/etewiah/property_web_builder/blob/master/README_es.md)

Yeni bir dilin nasıl ekleneceği ile ilgili açıklamalar için, lütfen şuraya bakın:
[https://github.com/etewiah/property_web_builder/wiki/Adding-translations-for-a-new-language](https://github.com/etewiah/property_web_builder/wiki/Adding-translations-for-a-new-language)
<!--
---

Thanks to the awesome [Locale](http://www.localeapp.com/) contributing to the translations is super easy!

- Edit the translations directly on the [property_web_builder](http://www.localeapp.com/projects/public?search=property_web_builder) project on Locale.
- **That's it!**
- The maintainer will then pull translations from the Locale project and push to Github.
-->

## Katkıda Bulunanlar

Bu projenin katkıda bulunan tüm insanlara teşekkürü vardır. [[Contribute]](CONTRIBUTING.md).
<a href="https://github.com/etewiah/property_web_builder/graphs/contributors"><img src="https://opencollective.com/property_web_builder/contributors.svg?width=890" /></a>


## Destekleyenler

Tüm destekçilerimize teşekkür ederiz! 🙏 [[Become a backer](https://opencollective.com/property_web_builder#backer)]

<a href="https://opencollective.com/property_web_builder#backers" target="_blank"><img src="https://opencollective.com/property_web_builder/backers.svg?width=890"></a>


## Sponsorlar

Bir sponsor olarak bu projeyi destekleyin. Logonuz sitenize giden bir link ile burada gösterilecek. [[Sponsor Ol](https://opencollective.com/property_web_builder#sponsor)]

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

