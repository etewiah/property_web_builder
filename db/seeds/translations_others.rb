# load File.join(Rails.root, 'db', 'seeds', 'translations.rb')
# unless I18n::Backend::ActiveRecord::Translation.all.length > 10
  I18n::Backend::ActiveRecord::Translation.create!(
    [
      {locale: "ru", key: "extras.aireAcondicionado", value: "Кондиционер", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.aireAcondicionado", value: "Aire condicionat", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.alarma", value: "Сигнализация", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.alarma", value: "Alarma", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.amueblado", value: "Меблированная", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.amueblado", value: "Moblat", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.armariosEmpotrados", value: "Встроенные Шкафы", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.armariosEmpotrados", value: "Armaris Encastats", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.ascensor", value: "Лифт", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.ascensor", value: "Ascensor", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.balcon", value: "Балкон", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.balcon", value: "Balcó", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.banoTurco", value: "Турецкая Баня", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.banoTurco", value: "Bany turc", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.calefaccionCentral", value: "Центральное Отопление", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.calefaccionCentral", value: "Calefacció Central", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.calefaccionElectrica", value: "Электрическое Отопление", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.calefaccionElectrica", value: "Calefacció Elèctrica", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.calefaccionPropano", value: "Газовое Отопление", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.calefaccionPropano", value: "Calefacció Propà", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.cocinaIndependiente", value: "Отдельная Кухня", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.cocinaIndependiente", value: "Cuina Independent", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.electrodomesticos", value: "Электро-Бытовая техника", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.electrodomesticos", value: "Electrodomèstics", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.energiaSolar", value: "Солнечные Батареи", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.energiaSolar", value: "Energia Solar", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.garajeComunitario", value: "Общий Гараж с Парковочным местом", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.garajeComunitario", value: "Garatge Comunitari", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.garajePrivado", value: "Собственный Гараж", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.garajePrivado", value: "Garatge Privat", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.gresCeramica", value: "Керамическая Плитка", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.gresCeramica", value: "Gres Ceràmica", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.horno", value: "Жарочный Шкаф-Духовка", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.horno", value: "Forn", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.jacuzzi", value: "Джакузи", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.jacuzzi", value: "Jacuzzi", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.jardinComunitario", value: "Сад Общего Пользования", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.jardinComunitario", value: "Jardí Comunitari", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.jardinPrivado", value: "Собственный Сад", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.jardinPrivado", value: "Jardí Privat", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.lavadero", value: "Прачечная", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.lavadero", value: "Afareig", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.lavadora", value: "Стиральная Машина", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.lavadora", value: "Rentadora", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.microondas", value: "Микроволновая Печь", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.microondas", value: "Microones", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.nevera", value: "Холодильник", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.nevera", value: "Nevera", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.parquet", value: "Паркет", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.parquet", value: "Parquet", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.piscinaClimatizada", value: "Климатизированный Бассейн ", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.piscinaClimatizada", value: "Piscina climatitzada", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.piscinaComunitaria", value: "Общий Бассейн", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.piscinaComunitaria", value: "Piscina comunitària", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.piscinaPrivada", value: "Личный Бассейн", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.piscinaPrivada", value: "Piscina privada", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.puertaBlindada", value: "Бронированная Дверь", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.puertaBlindada", value: "Porta Blindada", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.sauna", value: "Сауна", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.sauna", value: "Sauna", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.servPorteria", value: "Швейцар/Портье", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.servPorteria", value: "Serv. porteria", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.sueloMarmol", value: "Мраморные Полы", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.sueloMarmol", value: "Sòl Marbre", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.terraza", value: "Терраса", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.terraza", value: "Terrassa", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.trastero", value: "Подсобное Помещение", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.trastero", value: "Traster", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.tv", value: "Телевизор", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.tv", value: "TV", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.videoportero", value: "Видеонаблюдение", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.videoportero", value: "Videoporter", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.vigilancia", value: "Охрана", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.vigilancia", value: "Vigilància", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.vistasAlMar", value: "Вид на Море", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.vistasAlMar", value: "Vistes al mar", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.zComunitaria", value: "Общественная зона", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.zComunitaria", value: "Z. Comunitària", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.zonaDeportiva", value: "Зона для спорта", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.zonaDeportiva", value: "Zona Esportiva", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.cercaDeServicios", value: "Рядом со всеми удобствами/коммуникациями", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.cercaDeServicios", value: "Prop de Serveis", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.calefaccionGasCiudad", value: "Городское Газовое Отопление", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.calefaccionGasCiudad", value: "Calefacción gas ciudad", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.calefaccionGasoleo", value: "Дизельное отопление", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.calefaccionGasoleo", value: "Ccalefacció gasoil", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.zonasInfantiles", value: "Зона для детей", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.zonasInfantiles", value: "Zones infantils", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.sueloRadiante", value: "Полы с Подогревом", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.sueloRadiante", value: "Terra radiant", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.semiamueblado", value: "Частично меблированная", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.semiamueblado", value: "Semi moblat", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.chimenea", value: "Камин", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.chimenea", value: "Xemeneia", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.barbacoa", value: "Барбекю", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.barbacoa", value: "Barbacoa", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.porsche", value: "Веранда/Крыльцо", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.porsche", value: "Porsche", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.solarium", value: "Солярий", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.solarium", value: "Solarium", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.patioInterior", value: "Внутренний дворик", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.patioInterior", value: "Pati interior", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.vistasALaMontana", value: "Вид на Горы", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.vistasALaMontana", value: "Vistes a la muntanya", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.vistasAlJardin", value: "Вид на Сад", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.vistasAlJardin", value: "Vistes al jardí", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.urbanizacion", value: "Урбанизация", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.urbanizacion", value: "Urbanització", interpolations: [], is_proc: false},

      {locale: "ru", key: "extras.zonaTranquila", value: "Спокойная зона", interpolations: [], is_proc: false},
      {locale: "ca", key: "extras.zonaTranquila", value: "Zona tranquil · la", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.apartamento", value: "Квартира", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.apartamento", value: "Apartamento", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.chaletIndependiente", value: "undefined", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.chaletIndependiente", value: "Chalet independiente", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.bungalow", value: "Таунхаус", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.bungalow", value: "Bungalow", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.inversion", value: "Инвестиции", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.inversion", value: "Inversión", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.solar", value: "undefined", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.solar", value: "Solar", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.duplex", value: "Дуплекс", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.duplex", value: "Dúplex", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.piso", value: "квартира", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.piso", value: "Piso", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.hotel", value: "Отели", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.hotel", value: "Hotel", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.chaletAdosado", value: "Сдвоенный дом", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.chaletAdosado", value: "Chalet Adosado", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.atico", value: "Penthouse", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.atico", value: "Ático", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.estudio", value: "Studio", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.estudio", value: "Estudio", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.garaje", value: "Garage", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.garaje", value: "Garaje", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.local", value: "Commercial premises", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.local", value: "Local", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.trastero", value: "Warehouse", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.trastero", value: "Trastero", interpolations: [], is_proc: false},

      {locale: "ru", key: "propertyTypes.casaRural", value: "undefined", interpolations: [], is_proc: false},
      {locale: "ca", key: "propertyTypes.casaRural", value: "Casa Rural", interpolations: [], is_proc: false},
  ])
# end
