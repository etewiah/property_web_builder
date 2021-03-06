# load File.join(Rails.root, 'db', 'seeds', 'translations.rb')
I18n::Backend::ActiveRecord::Translation.create!(
  [
    {locale: "pl", key: "propertyStates.underConstruction", value: "W budowie"},
    {locale: "pl", key: "propertyStates.brandNew", value: "Całkiem nowy"},
    {locale: "pl", key: "propertyStates.segundaMano", value: "Drugiej ręki"},
    {locale: "pl", key: "propertyStates.nuevo", value: "Nowy"},
    {locale: "pl", key: "propertyStates.enConstruccion", value: "W budowie"},
    {locale: "pl", key: "propertyStates.aReformar", value: "Wymaga odnowienia"},

    {locale: "pl", key: "propertyOrigin.bank", value: "Przejęcie banku"},
    {locale: "pl", key: "propertyOrigin.new", value: "Nowo zbudowane"},
    {locale: "pl", key: "propertyOrigin.private", value: "Prywatna sprzedaż"},
    {locale: "pl", key: "propertyLabels.sold", value: "Sprzedany"},
    {locale: "pl", key: "propertyLabels.reserved", value: "Zarezerwowany"},

    {locale: "pl", key: "extras.aireAcondicionado", value: "Klimatyzacja"},
    {locale: "pl", key: "extras.alarma", value: "Alarm"},
    {locale: "pl", key: "extras.amueblado", value: "Meble"},
    {locale: "pl", key: "extras.armariosEmpotrados", value: "Pasująca Garderoba"},
    {locale: "pl", key: "extras.ascensor", value: "Winda"},
    {locale: "pl", key: "extras.balcon", value: "Balkon"},
    {locale: "pl", key: "extras.banoTurco", value: "Kąpiel Parowa"},
    {locale: "pl", key: "extras.calefaccionCentral", value: "Centralne Ogrzewanie"},
    {locale: "pl", key: "extras.calefaccionElectrica", value: "Ogrzewanie Elektryczne"},
    {locale: "pl", key: "extras.calefaccionPropano", value: "Ogrzewanie Propanem"},
    {locale: "pl", key: "extras.cocinaIndependiente", value: "Niezależna Kuchnia"},
    {locale: "pl", key: "extras.electrodomesticos", value: "Białe Towary"},
    {locale: "pl", key: "extras.energiaSolar", value: "Energia Słoneczna"},
    {locale: "pl", key: "extras.garajeComunitario", value: "Garaż Społecznościowy"},
    {locale: "pl", key: "extras.garajePrivado", value: "Prywatny Garaż"},
    {locale: "pl", key: "extras.gresCeramica", value: "Ceramiczna Podłoga"},
    {locale: "pl", key: "extras.horno", value: "Piekarnik"},
    {locale: "pl", key: "extras.jacuzzi", value: "Jacuzzi"},
    {locale: "pl", key: "extras.jardinComunitario", value: "Ogród Społecznościowy"},
    {locale: "pl", key: "extras.jardinPrivado", value: "Prywatny Ogród"},
    {locale: "pl", key: "extras.lavadero", value: "Pralnia"},
    {locale: "pl", key: "extras.lavadora", value: "Pralka"},
    {locale: "pl", key: "extras.microondas", value: "Kuchenka Mikrofalowa"},
    {locale: "pl", key: "extras.nevera", value: "Lodówka"},
    {locale: "pl", key: "extras.parquet", value: "Drewniana Podłoga"},
    {locale: "pl", key: "extras.piscinaClimatizada", value: "Ogrzewany Basen"},
    {locale: "pl", key: "extras.piscinaComunitaria", value: "Pula Społeczności"},
    {locale: "pl", key: "extras.piscinaPrivada", value: "Prywatny Basen"},
    {locale: "pl", key: "extras.porche", value: "Ganek"},
    {locale: "pl", key: "extras.puertaBlindada", value: "Stalowe Drzwi"},
    {locale: "pl", key: "extras.sauna", value: "Sauna"},
    {locale: "pl", key: "extras.servPorteria", value: "Obsługa Opiekuna"},
    {locale: "pl", key: "extras.sueloMarmol", value: "Podłoga Marmurowa"},
    {locale: "pl", key: "extras.terraza", value: "Taras"},
    {locale: "pl", key: "extras.trastero", value: "Przestrzeń Magazynowa"},
    {locale: "pl", key: "extras.tv", value: "Telewizja"},
    {locale: "pl", key: "extras.videoportero", value: "Wpis wideo - telefon"},
    {locale: "pl", key: "extras.vigilancia", value: "Bezpieczeństwo"},
    {locale: "pl", key: "extras.vistasAlMar", value: "Widoki na Morze"},
    {locale: "pl", key: "extras.zComunitaria", value: "Obszar Wspólnoty"},
    {locale: "pl", key: "extras.zonaDeportiva", value: "Strefa Sportowa"},
    {locale: "pl", key: "extras.cercaDeServicios", value: "Blisko Zakupów"},
    {locale: "pl", key: "extras.calefaccionGasCiudad", value: "Ogrzewanie Gazem Ziemnym"},
    {locale: "pl", key: "extras.calefaccionGasoleo", value: "Ogrzewanie Olejowe"},
    {locale: "pl", key: "extras.zonasInfantiles", value: "Strefa dla dzieci"},
    {locale: "pl", key: "extras.sueloRadiante", value: "Ogrzewanie podłogowe"},
    {locale: "pl", key: "extras.semiamueblado", value: "Pół umeblowane"},
    {locale: "pl", key: "extras.chimenea", value: "Kominek"},
    {locale: "pl", key: "extras.barbacoa", value: "Grill"},
    {locale: "pl", key: "extras.porsche", value: "Porsche"},
    {locale: "pl", key: "extras.solarium", value: "Solarium"},
    {locale: "pl", key: "extras.patioInterior", value: "Podwórko"},
    {locale: "pl", key: "extras.vistasALaMontana", value: "Widoki Górskie"},
    {locale: "pl", key: "extras.vistasAlJardin", value: "Widok na Ngród"},
    {locale: "pl", key: "extras.urbanizacion", value: "Urbanizacja"},
    {locale: "pl", key: "extras.zonaTranquila", value: "Ciche miejsce"},
    {locale: "pl", key: "propertyTypes.apartamento", value: "Apartment"},
    {locale: "pl", key: "propertyTypes.chaletIndependiente", value: "Szalet"},
    {locale: "pl", key: "propertyTypes.bungalow", value: "Bungalow"},
    {locale: "pl", key: "propertyTypes.inversion", value: "Inwestycja"},
    {locale: "pl", key: "propertyTypes.solar", value: "Wylądować"},
    {locale: "pl", key: "propertyTypes.duplex", value: "Dupleks"},
    {locale: "pl", key: "propertyTypes.piso", value: "Mieszkanie"},
    {locale: "pl", key: "propertyTypes.hotel", value: "Hotel"},
    {locale: "pl", key: "propertyTypes.chaletAdosado", value: "Częściowo-wolnostojący"},
    {locale: "pl", key: "propertyTypes.atico", value: "przybudówka na dachu"},
    {locale: "pl", key: "propertyTypes.estudio", value: "Studio"},
    {locale: "pl", key: "propertyTypes.garaje", value: "Garaż"},
    {locale: "pl", key: "propertyTypes.local", value: "Commercial premises"},
    {locale: "pl", key: "propertyTypes.trastero", value: "Magazyn"},
    {locale: "pl", key: "propertyTypes.casaRural", value: "Chatka"},
    {locale: "pl", key: "propertyTypes.edificioResidencial", value: "Budynek mieszkalny"},
    {locale: "pl", key: "propertyTypes.villa", value: "Willa"}


]
)
