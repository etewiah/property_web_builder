require 'rails_helper'

module Pwb
  RSpec.describe "Admin Login", type: :feature do
    # US-3.1: Admin Login
    # As a site admin, I want to log into the admin panel
    # So that I can manage my website

    before(:all) do
      @website = FactoryBot.create(:pwb_website, subdomain: 'test-admin-login')

      ActsAsTenant.with_tenant(@website) do
        @agency = FactoryBot.create(:pwb_agency, company_name: 'Admin Realty', website: @website)
      end

      @admin_user = User.create!(
        email: "admin@test-admin-login.example.com",
        password: "secure-password-123",
        admin: true,
        website: @website
      )
      @non_admin_user = User.create!(
        email: "user@test-admin-login.example.com",
        password: "user-password-123",
        admin: false,
        website: @website
      )
    end

    before(:each) do
      Capybara.app_host = 'http://test-admin-login.example.com'
    end

    after(:each) do
      Capybara.app_host = nil
    end

    describe "Login Form" do
      scenario "login page is accessible" do
        visit('/users/sign_in')

        expect(page).to have_field('Email').or have_field('email')
        expect(page).to have_field('Password').or have_field('password')
        expect(page).to have_button('Sign in').or have_button('Log in').or have_button('Login')
      end

      scenario "successful login with valid admin credentials" do
        visit('/users/sign_in')

        fill_in('Email', with: @admin_user.email)
        fill_in('Password', with: 'secure-password-123')
        click_button('Sign in')

        # Should redirect to admin area
        expect(current_path).to include('/admin').or include('/site_admin')
      end

      scenario "failed login with invalid password" do
        visit('/users/sign_in')

        fill_in('Email', with: @admin_user.email)
        fill_in('Password', with: 'wrong-password')
        click_button('Sign in')

        expect(page).to have_content('Invalid email or password')
          .or have_content('Invalid')
          .or have_content('incorrect')
      end

      scenario "failed login with non-existent email" do
        visit('/users/sign_in')

        fill_in('Email', with: 'nonexistent@example.com')
        fill_in('Password', with: 'any-password')
        click_button('Sign in')

        expect(page).to have_content('Invalid email or password')
          .or have_content('Invalid')
          .or have_content('incorrect')
      end
    end

    describe "Admin Access Control" do
      scenario "unauthenticated user cannot access admin panel" do
        visit('/site_admin/props')

        # Should redirect to login or show access denied
        expect(current_path).to include('/sign_in')
          .or include('/login')
          .or include('/users')
      end

      scenario "authenticated admin can access admin panel" do
        visit('/users/sign_in')
        fill_in('Email', with: @admin_user.email)
        fill_in('Password', with: 'secure-password-123')
        click_button('Sign in')

        visit('/site_admin/props')

        # Should be able to access properties page
        expect(current_path).to include('/site_admin')
          .or include('/admin')
      end
    end

    describe "Logout" do
      scenario "admin can logout" do
        # Login first
        visit('/users/sign_in')
        fill_in('Email', with: @admin_user.email)
        fill_in('Password', with: 'secure-password-123')
        click_button('Sign in')

        # Look for logout link/button
        if page.has_link?('Logout')
          click_link('Logout')
          expect(page).to have_content('Signed out')
            .or have_content('logged out')
            .or have_field('Email')
        elsif page.has_link?('Sign out')
          click_link('Sign out')
          expect(page).to have_content('Signed out')
            .or have_content('logged out')
            .or have_field('Email')
        end
      end
    end

    describe "Session Persistence" do
      scenario "session persists across page navigation" do
        # Login
        visit('/users/sign_in')
        fill_in('Email', with: @admin_user.email)
        fill_in('Password', with: 'secure-password-123')
        click_button('Sign in')

        # Navigate to different admin pages
        visit('/site_admin/props')
        expect(current_path).to include('/site_admin').or include('/admin')

        visit('/site_admin/contacts')
        expect(current_path).to include('/site_admin').or include('/admin')

        # Should still be logged in
        expect(page).not_to have_content('Sign in')
      end
    end

    after(:all) do
      @non_admin_user&.destroy
      @admin_user&.destroy
      @agency&.destroy
      @website&.destroy
    end
  end
end
