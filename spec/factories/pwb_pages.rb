FactoryBot.define do
  factory :pwb_page, class: "Pwb::Page" do
    # trait :about_us do
    #   association :page_parts, factory: :pwb_page_part, page_part_key: "our_agency"
    # end

    # trait :home_page do
    #   slug "home"
    # end

    after(:create) do |page, _evaluator|
      create(:pwb_link, :top_nav, page_slug: page.slug)
    end

    factory :contact_us_with_rails_page_part do
      slug { "contact-us" }
      after(:create) do |page, _evaluator|
        # form_and_map is a pwb_page_part trait
        # create(:pwb_page_part, :form_and_map, page: page)
        # below ensures there is some visible content
        create(:form_and_map_rails_part_content, page: page)
      end
    end

    factory :page_with_content_html_page_part do
      after(:create) do |page, _evaluator|
        # content_html is a pwb_page_part trait
        create(:pwb_page_part, :content_html, page: page)
        # create(:page_content_with_content, page: page)
        page_part_manager = Pwb::PagePartManager.new "content_html", page
        content = page_part_manager.find_or_create_content
        content.raw = "Sell Your Property"
        content.save!
      end
    end

    # about_us will create page_part data after the page has been created
    # alternative discussed here:
    # https://stackoverflow.com/questions/10846732/factory-girl-create-association-with-existing-object
    factory :about_us_page_with_page_part do
      # page_parts_count is declared as a transient attribute and available in
      # attributes on the factory, as well as the callback via the evaluator
      transient do
        page_parts_count { 5 }
      end

      # the after(:create) yields two values; the page instance itself and the
      # evaluator, which stores all values from the factory, including transient
      # attributes; `create_list`'s second argument is the number of records
      # to create and we make sure the page is associated properly to the page_part
      after(:create) do |page, _evaluator|
        create(:pwb_page_part, :content_html, page: page)
        # create_list(:pwb_page_part, evaluator.page_parts_count, page: page)
      end
    end
  end
end
