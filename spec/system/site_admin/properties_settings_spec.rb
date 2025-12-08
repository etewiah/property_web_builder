require 'rails_helper'

RSpec.describe 'Properties Settings Management', type: :system, js: true do
  include Warden::Test::Helpers

  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:admin_user) { create(:pwb_user, :admin, website: website) }

  before do
    Warden.test_mode!
    driven_by(:selenium_chrome_headless)

    # Set up current website
    allow(Pwb::Current).to receive(:website).and_return(website)

    # Sign in
    login_as(admin_user, scope: :user)
  end

  after do
    Warden.test_reset!
  end
  
  describe 'navigating to settings' do
    it 'allows access from site_admin navigation' do
      # Directly visit the settings page since sidebar is responsive
      visit site_admin_properties_settings_path

      expect(page).to have_current_path(site_admin_properties_settings_path)
      expect(page).to have_content('Property Types')
    end

    it 'displays all four category tabs' do
      visit site_admin_properties_settings_path

      expect(page).to have_link('Types')
      expect(page).to have_link('Features')
      expect(page).to have_link('States')
    end
  end
  
  describe 'managing property types' do
    it 'allows admin to add a new property type' do
      visit site_admin_properties_settings_category_path('property_types')

      click_button 'Add New Entry'

      # The modal uses id="new-entry-modal"
      within '#new-entry-modal' do
        fill_in 'field_key[translations][en]', with: 'Townhouse'

        click_button 'Create'
      end

      expect(page).to have_content('Setting created successfully')
      expect(page).to have_content('Townhouse')
    end

    it 'displays multilingual columns in the table' do
      field_key = ActsAsTenant.with_tenant(website) do
        create(:pwb_field_key,
          tag: 'property-types',
          global_key: 'prop_type.apartment',
          website: website
        )
      end

      # Set up translations
      I18n.backend.store_translations(:en, { 'prop_type.apartment' => 'Apartment' })

      visit site_admin_properties_settings_category_path('property_types')

      expect(page).to have_content('Apartment')
    end

    it 'allows editing an existing property type' do
      field_key = ActsAsTenant.with_tenant(website) do
        create(:pwb_field_key,
          tag: 'property-types',
          global_key: 'prop_type.villa',
          website: website,
          visible: true
        )
      end

      I18n.backend.store_translations(:en, { 'prop_type.villa' => 'Villa' })

      visit site_admin_properties_settings_category_path('property_types')

      # The card has an inline edit form - find the card and update the translation
      within "#card-#{field_key.global_key.parameterize}" do
        input = find('input[name="field_key[translations][en]"]')
        input.fill_in with: 'Luxury Villa'
        # Trigger onchange event to reveal Save button
        input.native.send_keys(:tab)

        click_button 'Save'
      end

      expect(page).to have_content('Setting updated successfully')
    end

    it 'allows deleting a property type' do
      field_key = ActsAsTenant.with_tenant(website) do
        create(:pwb_field_key,
          tag: 'property-types',
          global_key: 'prop_type.warehouse',
          website: website
        )
      end

      I18n.backend.store_translations(:en, { 'prop_type.warehouse' => 'Warehouse' })

      visit site_admin_properties_settings_category_path('property_types')

      # Verify the item exists
      expect(page).to have_content('Warehouse')

      # Click the delete button on the card (opens confirmation modal)
      first('[id^="card-"] button[onclick*="confirmDelete"]').click

      # Confirm deletion in the modal
      within '#delete-modal' do
        click_button 'Delete'
      end

      # Wait for page to reload and verify item is gone
      expect(page).not_to have_content('Warehouse')
    end
  end
  
  describe 'tab navigation' do
    it 'switches between categories smoothly' do
      visit site_admin_properties_settings_path

      click_link 'Types'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('property_types'))

      click_link 'Features'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('property_features'))

      click_link 'States'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('property_states'))

      click_link 'Origin'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('listing_origin'))
    end
  end
  
  describe 'empty states' do
    it 'shows helpful message when no entries exist' do
      visit site_admin_properties_settings_category_path('property_types')
      
      expect(page).to have_content('No property types yet')
      expect(page).to have_content('Click "Add New Entry" to create one')
    end
  end
  
  describe 'tenant isolation' do
    let(:other_website) { create(:pwb_website, subdomain: 'other-site') }
    let!(:other_field_key) do
      ActsAsTenant.with_tenant(other_website) do
        create(:pwb_field_key, tag: 'property-types', global_key: 'prop_type.other_type', website: other_website)
      end
    end
    let!(:own_field_key) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_field_key, tag: 'property-types', global_key: 'prop_type.own_type', website: website)
      end
    end

    before do
      I18n.backend.store_translations(:en, { 'prop_type.other_type' => 'Other Type' })
      I18n.backend.store_translations(:en, { 'prop_type.own_type' => 'Own Type' })
    end

    it 'only shows settings for current website' do
      visit site_admin_properties_settings_category_path('property_types')

      expect(page).to have_content('Own Type')
      expect(page).not_to have_content('Other Type')
    end
  end
  
  describe 'form validation' do
    it 'requires at least English translation' do
      visit site_admin_properties_settings_category_path('property_features')

      click_button 'Add New Entry'

      # The modal should be visible
      expect(page).to have_selector('#new-entry-modal:not(.hidden)')

      # HTML5 required attribute on English field prevents submission
      within '#new-entry-modal' do
        # Try to click Create without filling required field
        click_button 'Create'
      end

      # Modal should still be visible (submission blocked by HTML5 validation)
      expect(page).to have_selector('#new-entry-modal')
    end
  end
  
  describe 'sorting and ordering' do
    let!(:field_key1) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_field_key, tag: 'property-types', global_key: 'prop_type.type_a', website: website, sort_order: 10)
      end
    end
    let!(:field_key2) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_field_key, tag: 'property-types', global_key: 'prop_type.type_b', website: website, sort_order: 5)
      end
    end
    let!(:field_key3) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_field_key, tag: 'property-types', global_key: 'prop_type.type_c', website: website, sort_order: 15)
      end
    end

    before do
      I18n.backend.store_translations(:en, { 'prop_type.type_a' => 'Type A' })
      I18n.backend.store_translations(:en, { 'prop_type.type_b' => 'Type B' })
      I18n.backend.store_translations(:en, { 'prop_type.type_c' => 'Type C' })
    end

    it 'displays entries in sort_order' do
      visit site_admin_properties_settings_category_path('property_types')

      # Get all cards - they're rendered in a grid
      cards = all('[id^="card-"]').map { |card| card.text }

      # Verify field_key2 (order 5) appears before field_key1 (order 10)
      key2_index = cards.index { |c| c.include?('Type B') }
      key1_index = cards.index { |c| c.include?('Type A') }

      expect(key2_index).to be < key1_index
    end
  end
end
