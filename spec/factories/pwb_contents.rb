FactoryBot.define do
  factory :pwb_content, class: 'PwbTenant::Content' do
    key { "MyString" }
    tag { "MyString" }
    raw { "MyText" }
    website { Pwb::Website.first || association(:pwb_website) }

    trait :main_content do
      raw_en { "<h2>Sell Your Property with Us</h2>" }
    end
  end
end
