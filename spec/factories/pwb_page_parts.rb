FactoryGirl.define do
  factory :pwb_page_part, class: 'Pwb::PagePart' do
    # factory :form_and_map_rails_part do
    #   page_part_key "form_and_map"
    #   is_rails_part true
    #   after(:create) do |page_part, evaluator|
    #     create(:pwb_content, :main_content, pages: [page_part.page])
    #   end
    # end

    # trait :form_and_map do
    #   page_part_key "form_and_map"
    #   is_rails_part true
    # end

    trait :content_html do
      page_part_key "content_html"
    end
    trait :footer_content_html_for_website do
      page_part_key "footer_content_html"
      template "<p>{{ page_part['main_content']['content'] %> }}</p>"
      # page_slug "website"
      # extra {} needed for json object below
      editor_setup {
        {
          tabTitleKey: "pageSections.rawHtml.title",
          editorBlocks: [
            [
              {
                "label": "main_content",
                "isHtml": "true"
            }]
          ]
        }
      }
    end
  end
end
