FactoryGirl.define do
  factory :pwb_page_content, class: 'Pwb::PageContent' do
    factory :form_and_map_rails_part_content do
      page_part_key "form_and_map"
      is_rails_part true
      visible_on_page true
    end

    factory :page_content_with_content do
      page_part_key "content_html"
      after(:create) do |page_content, _evaluator|
        create(:pwb_content, :main_content, page_part_key: "content_html", pages: [page_content.page])
      end
    end
  end
end
