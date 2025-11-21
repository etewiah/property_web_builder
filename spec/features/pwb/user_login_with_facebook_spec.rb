require 'rails_helper'

module Pwb
  RSpec.feature "user logs in" do
    # http://www.jessespevack.com/blog/2016/10/16/how-to-test-drive-omniauth-google-oauth2-for-your-rails-app
    scenario "using facebook oauth2" do


      # if secrets are not set above, sign in link will not display
      stub_omniauth
      # visit root_path
      visit('/admin')
      # puts current_url

      expect(page).to have_link("Sign in with Facebook")
      click_link "Sign in with Facebook"
      expect(page).to have_content("You need to be an admin to access this")
      # expect(page).to have_link("Logout")
    end

    def stub_omniauth
      # first, set OmniAuth to run in test mode
      OmniAuth.config.test_mode = true
      # then, provide a set of fake oauth data that
      # omniauth will use when a user tries to authenticate:
      OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new({
                                                                      provider: "facebook",
                                                                      uid: "12345678910",
                                                                      info: {
                                                                        email: "dummy@dummy.com",
                                                                        first_name: "Ed",
                                                                        last_name: "Tee"
                                                                      },
                                                                      credentials: {
                                                                        token: "abcdefg12345",
                                                                        refresh_token: "12345abcdefg",
                                                                        expires_at: DateTime.now
                                                                      }
      })
    end
  end
end
