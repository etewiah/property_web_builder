FactoryBot.define do
  factory :pwb_realty_asset, class: 'Pwb::RealtyAsset' do
    sequence(:reference) { |n| "ASSET-#{n}" }
    association :website, factory: :pwb_website

    count_bedrooms { 2 }
    count_bathrooms { 1 }
    count_toilets { 1 }
    count_garages { 0 }
    constructed_area { 80.0 }
    plot_area { 0.0 }
    year_construction { 2000 }

    street_address { '123 Test Street' }
    city { 'Test City' }
    postal_code { '12345' }
    country { 'Spain' }

    prop_type_key { 'apartment' }
    prop_state_key { 'good' }

    trait :with_location do
      latitude { 40.4168 }
      longitude { -3.7038 }
    end

    trait :luxury do
      count_bedrooms { 5 }
      count_bathrooms { 3 }
      count_garages { 2 }
      constructed_area { 300.0 }
      plot_area { 500.0 }
      prop_type_key { 'villa' }
    end

    trait :with_sale_listing do
      after(:create) do |asset|
        create(:pwb_sale_listing, :visible, realty_asset: asset)
      end
    end

    trait :with_rental_listing do
      after(:create) do |asset|
        create(:pwb_rental_listing, :visible, :long_term, realty_asset: asset)
      end
    end

    trait :with_short_term_rental do
      after(:create) do |asset|
        create(:pwb_rental_listing, :visible, :short_term, realty_asset: asset)
      end
    end

    trait :with_photos do
      after(:create) do |asset|
        create_list(:pwb_prop_photo, 2, realty_asset_id: asset.id)
      end
    end

    trait :with_features do
      after(:create) do |asset|
        create(:pwb_feature, realty_asset_id: asset.id, feature_key: 'pool')
        create(:pwb_feature, realty_asset_id: asset.id, feature_key: 'garden')
      end
    end

    trait :with_translations do
      after(:create) do |asset|
        # Create a legacy Pwb::Prop record to satisfy Globalize's globalized_model requirement
        # This is necessary during the migration period while translations are still managed through Pwb::Prop
        prop = Pwb::Prop.create!(
          website: asset.website,
          reference: asset.reference
        )

        # Create translations linked to both the prop (for Globalize) and the asset
        Pwb::Prop::Translation.create!(
          prop_id: prop.id,
          realty_asset_id: asset.id,
          locale: 'en',
          title: 'Test Property Title',
          description: 'A beautiful test property'
        )
        Pwb::Prop::Translation.create!(
          prop_id: prop.id,
          realty_asset_id: asset.id,
          locale: 'es',
          title: 'Titulo de Propiedad de Prueba',
          description: 'Una hermosa propiedad de prueba'
        )
      end
    end
  end
end
