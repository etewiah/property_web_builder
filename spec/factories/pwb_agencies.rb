FactoryBot.define do
  factory :pwb_agency, class: 'PwbTenant::Agency' do
    sequence(:company_name) { |n| "Company #{n}" }
    sequence(:display_name) { |n| "Agency #{n}" }
    association :website, factory: :pwb_website
    
    trait :theme_default do
      # theme_name moved to website
    end
    trait :theme_berlin do
      # theme_name moved to website
    end
  end
end
