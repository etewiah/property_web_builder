# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'pwb:seed_for_onboarding rake task', type: :task do
  before(:all) do
    Rails.application.load_tasks

    # Set up tenant settings to allow all themes used in tests
    Pwb::TenantSettings.delete_all
    Pwb::TenantSettings.create!(
      singleton_key: "default",
      default_available_themes: %w[default brisbane bologna barcelona biarritz]
    )
  end

  after(:all) do
    Pwb::TenantSettings.delete_all
  end

  before do
    # Clear any existing data
    Pwb::UserMembership.delete_all
    Pwb::User.delete_all
    Pwb::Agency.delete_all
    Pwb::Website.delete_all

    # Reset the rake task so it can be invoked multiple times
    Rake::Task['pwb:seed_for_onboarding'].reenable
  end

  describe 'pwb:seed_for_onboarding' do
    context 'with default settings' do
      it 'creates a website with live provisioning state' do
        expect { Rake::Task['pwb:seed_for_onboarding'].invoke }.to change { Pwb::Website.count }.by(1)

        website = Pwb::Website.last
        expect(website.subdomain).to eq('onboarding')
        expect(website.provisioning_state).to eq('live')
        expect(website.theme_name).to eq('default')
      end

      it 'creates an admin user with onboarding pending' do
        Rake::Task['pwb:seed_for_onboarding'].invoke

        user = Pwb::User.find_by(email: 'admin@example.com')
        expect(user).to be_present
        expect(user.admin).to be true
        expect(user.onboarding_state).to eq('active')
        expect(user.site_admin_onboarding_completed_at).to be_nil
      end

      it 'creates an agency for the website' do
        Rake::Task['pwb:seed_for_onboarding'].invoke

        website = Pwb::Website.last
        agency = Pwb::Agency.find_by(website: website)
        expect(agency).to be_present
      end

      it 'creates an owner membership for the user' do
        Rake::Task['pwb:seed_for_onboarding'].invoke

        user = Pwb::User.find_by(email: 'admin@example.com')
        website = Pwb::Website.last
        membership = Pwb::UserMembership.find_by(user: user, website: website)

        expect(membership).to be_present
        expect(membership.role).to eq('owner')
        expect(membership.active).to be true
      end
    end

    context 'with custom environment variables' do
      before do
        ENV['ADMIN_EMAIL'] = 'custom@agency.com'
        ENV['ADMIN_PASSWORD'] = 'secure123'
        ENV['SUBDOMAIN'] = 'my-agency'
        ENV['THEME'] = 'brisbane'
      end

      after do
        ENV.delete('ADMIN_EMAIL')
        ENV.delete('ADMIN_PASSWORD')
        ENV.delete('SUBDOMAIN')
        ENV.delete('THEME')
      end

      it 'uses custom admin email' do
        Rake::Task['pwb:seed_for_onboarding'].invoke

        user = Pwb::User.find_by(email: 'custom@agency.com')
        expect(user).to be_present
      end

      it 'uses custom subdomain' do
        Rake::Task['pwb:seed_for_onboarding'].invoke

        website = Pwb::Website.find_by(subdomain: 'my-agency')
        expect(website).to be_present
      end

      it 'uses custom theme' do
        Rake::Task['pwb:seed_for_onboarding'].invoke

        website = Pwb::Website.last
        expect(website.theme_name).to eq('brisbane')
      end
    end

    context 'when website already exists' do
      let!(:existing_website) { create(:pwb_website, subdomain: 'onboarding', provisioning_state: 'pending') }

      it 'updates existing website to live state' do
        expect { Rake::Task['pwb:seed_for_onboarding'].invoke }.not_to(change { Pwb::Website.count })

        existing_website.reload
        expect(existing_website.provisioning_state).to eq('live')
      end
    end

    context 'when user already exists' do
      let!(:website) { create(:pwb_website, subdomain: 'onboarding', provisioning_state: 'live') }
      let!(:existing_user) do
        create(:pwb_user,
               email: 'admin@example.com',
               website: website,
               site_admin_onboarding_completed_at: Time.current)
      end

      it 'resets the onboarding state for existing user' do
        Rake::Task['pwb:seed_for_onboarding'].invoke

        existing_user.reload
        expect(existing_user.site_admin_onboarding_completed_at).to be_nil
      end
    end
  end

  describe 'pwb:reset_onboarding' do
    let(:website) { create(:pwb_website, subdomain: 'resettest') }
    let!(:user) do
      create(:pwb_user,
             email: 'reset-test@example.com',
             website: website,
             site_admin_onboarding_completed_at: Time.current)
    end

    before do
      Rake::Task['pwb:reset_onboarding'].reenable
    end

    it 'resets onboarding for an existing user' do
      expect(user.site_admin_onboarding_completed_at).to be_present

      Rake::Task['pwb:reset_onboarding'].invoke('reset-test@example.com')

      user.reload
      expect(user.site_admin_onboarding_completed_at).to be_nil
    end

    context 'when user has onboarding already pending' do
      before { user.update!(site_admin_onboarding_completed_at: nil) }

      it 'reports that onboarding is already pending' do
        # Just ensure it doesn't error
        expect { Rake::Task['pwb:reset_onboarding'].invoke('reset-test@example.com') }.not_to raise_error
      end
    end
  end
end
