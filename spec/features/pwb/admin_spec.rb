require 'rails_helper'

module Pwb
  RSpec.describe "Admin panel", type: :feature, js: true do
    pending "need to figure out why test below fails on travis"

    # before(:all) do
    #   @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
    # end

    # scenario 'sign in works' do
    #   sign_in_as @admin_user.email, @admin_user.password
    #   # byebug
    #   expect(page).to have_link(nil, href: '/en/admin/properties/new')

    #   # above fails with this error in Travis CI but not locally:
    #   # Failure/Error: expect(page).to have_link(nil, href: '/en/admin/properties/new')
    #   # expected to find link nil with href "/en/admin/properties/new" but there were no matches
    # end


    # after(:all) do
    #   @admin_user.destroy
    # end
  end
end
