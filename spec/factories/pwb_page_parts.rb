FactoryGirl.define do
  factory :pwb_page_part, class: 'Pwb::PagePart' do
    trait :content_html do
      fragment_key "content_html"
    end
    
  end
end
