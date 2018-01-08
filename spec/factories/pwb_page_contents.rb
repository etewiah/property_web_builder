FactoryGirl.define do
  factory :pwb_page_content, class: 'Pwb::PageContent' do
    factory :page_content_with_content do
      # page_part_key "content_html"
      after(:create) do |page_content, evaluator|
        create(:pwb_content, :main_content, pages: [page_content.page])
      end
    end

  end
end
