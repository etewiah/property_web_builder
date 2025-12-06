FactoryBot.define do
  factory :pwb_page_content, class: 'PwbTenant::PageContent' do
    association :website, factory: :pwb_website
    sequence(:page_part_key) { |n| "page_part_key_#{n}" }

    factory :form_and_map_rails_part_content do
      page_part_key { "form_and_map" }
      is_rails_part { true }
      visible_on_page { true }
      # Use page's website if page is provided, otherwise use factory's website
      website { page&.website || association(:pwb_website) }
    end

    # factory :page_content_with_content do
    #   # somehow page_content is getting created without page_part_key
    #   page_part_key "content_html"
    #   after(:create) do |page_content, _evaluator|
    #     # it seems that in the creation of the related content, perhaps another page_content join object is being created
    #     # create(:pwb_content, :main_content, page_part_key: "content_html", pages: [page_content.page])
    #   end
    # end
  end
end
