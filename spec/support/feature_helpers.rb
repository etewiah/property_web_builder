module FeatureHelpers
  # https://code.tutsplus.com/articles/ruby-page-objects-for-capybara-connoisseurs--cms-25204
  def sign_in_as(email, password)
    # visit root_path
    # fill_in      'Email', with: email
    # click_button 'Submit'
    Capybara.raise_server_errors = false
    # above needed to prevent this error:
    # No route matches [GET] "/assets/icons/ellipsis.png"

    visit('/admin')
    # puts current_url
    # require 'pry'; binding.pry
    # save_and_open_page
    fill_in('Email', with: email)
    fill_in('Password', with: password)
    click_button('Sign in')

  end
end
