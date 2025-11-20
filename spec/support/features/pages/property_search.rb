module Pages
  class PropertySearch
    include Capybara::DSL

    # based on:
    # https://code.tutsplus.com/articles/ruby-page-objects-for-capybara-connoisseurs--cms-25204
    def search_rentals(min_price)
      # Capybara.ignore_hidden_elements = false
      # passing visible: false below would be like setting above
      # select(min_price, from: 'search_for_rent_price_from', visible: false)
      # Workaround for hidden select
      page.execute_script("
        var el = document.getElementById('search_for_rent_price_from');
        el.style.display = 'block';
        el.style.visibility = 'visible';
        el.style.opacity = '1';
        el.style.height = 'auto';
        el.style.width = 'auto';
      ")
      select(min_price, from: 'search_for_rent_price_from')
      page.execute_script("document.getElementById('search_for_rent_price_from').style.display = 'none';")
      click_button('Search')
    end

    # below used by calling
    # have_search_result_count
    def has_search_result_count?(expected_count)
      has_css?(".property-item", count: expected_count)
      # search_result_list.count.eql? expected_count
    end

    private

    def search_result_list
      # find(".property-item")
      all(".property-item")
    end
  end
end
