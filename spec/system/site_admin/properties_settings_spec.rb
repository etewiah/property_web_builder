require 'rails_helper'

RSpec.describe 'Properties Settings Management', type: :system, js: true do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:admin_user) { create(:pwb_user, website: website) }
  
  before do
    driven_by(:selenium_chrome_headless)
    
    # Set up current website
    allow(Pwb::Current).to receive(:website).and_return(website)
    
    # Sign in
    login_as(admin_user, scope: :user)
  end
  
  describe 'navigating to settings' do
    it 'allows access from site_admin navigation' do
      visit site_admin_root_path
      
      within('.sidebar') do
        click_link 'Properties'
        click_link 'Settings'
      end
      
      expect(page).to have_current_path(site_admin_properties_settings_path)
      expect(page).to have_content('Properties Settings')
    end
    
    it 'displays all four category tabs' do
      visit site_admin_properties_settings_path
      
      expect(page).to have_link('Property Types')
      expect(page).to have_link('Features')
      expect(page).to have_link('Property States')
      expect(page).to have_link('Property Labels')
    end
  end
  
  describe 'managing property types' do
    it 'allows admin to add a new property type' do
      visit site_admin_properties_settings_category_path('property_types')
      
      click_button 'Add New Entry'
      
      within '#new-entry-form' do
        fill_in 'field_key[translations][en]', with: 'Townhouse'
        fill_in 'field_key[translations][es]', with: 'Casa adosada'
        fill_in 'field_key[sort_order]', with: '5'
        check 'field_key[visible]'
        
        click_button 'Create'
      end
      
      expect(page).to have_content('Setting created successfully')
      expect(page).to have_content('Townhouse')
      expect(page).to have_content('Casa adosada')
    end
    
    it 'displays multilingual columns in the table' do
      create(:pwb_field_key, 
        tag: 'property-types',
        global_key: 'prop_type.apartment',
        website: website
      )
      
      # Set up translations
      I18n.backend.store_translations(:en, { 'prop_type.apartment' => 'Apartment' })
      I18n.backend.store_translations(:es, { 'prop_type.apartment' => 'Apartamento' })
      
      visit site_admin_properties_settings_category_path('property_types')
      
      expect(page).to have_content('Apartment')
      expect(page).to have_content('Apartamento')
    end
    
    it 'allows editing an existing property type' do
      field_key = create(:pwb_field_key,
        tag: 'property-types',
        global_key: 'prop_type.villa',
        website: website,
        visible: true
      )
      
      visit site_admin_properties_settings_category_path('property_types')
      
      # Click edit button
      find("button[onclick*=\"toggleEditForm('#{field_key.global_key.parameterize}')\"]").click
      
      within "#edit-form-#{field_key.global_key.parameterize}" do
        fill_in 'field_key[translations][en]', with: 'Luxury Villa'
        uncheck 'field_key[visible]'
        
        click_button 'Update'
      end
      
      expect(page).to have_content('Setting updated successfully')
      
      field_key.reload
      expect(field_key.visible).to be false
    end
    
    it 'allows deleting a property type' do
      field_key = create(:pwb_field_key,
        tag: 'property-types',
        global_key: 'prop_type.warehouse',
        website: website
      )
      
      visit site_admin_properties_settings_category_path('property_types')
      
      accept_confirm do
        click_button 'Delete', match: :first
      end
      
      expect(page).to have_content('Setting deleted successfully')
      expect(page).not_to have_content(field_key.global_key)
    end
  end
  
  describe 'tab navigation' do
    it 'switches between categories smoothly' do
      visit site_admin_properties_settings_path
      
      click_link 'Property Types'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('property_types'))
      expect(page).to have_selector('.border-blue-500', text: 'Property Types')
      
      click_link 'Features'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('features'))
      expect(page).to have_selector('.border-blue-500', text: 'Features')
      
      click_link 'Property States'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('property_states'))
      
      click_link 'Property Labels'
      expect(page).to have_current_path(site_admin_properties_settings_category_path('property_labels'))
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
    let!(:other_field_key) { create(:pwb_field_key, tag: 'property-types', website: other_website) }
    let!(:own_field_key) { create(:pwb_field_key, tag: 'property-types', website: website) }
    
    it 'only shows settings for current website' do
      visit site_admin_properties_settings_category_path('property_types')
      
      expect(page).to have_content(own_field_key.global_key.split('.').last)
      expect(page).not_to have_content(other_field_key.global_key)
    end
  end
  
  describe 'form validation' do
    it 'requires at least English translation' do
      visit site_admin_properties_settings_category_path('features')
      
      click_button 'Add New Entry'
      
      within '#new-entry-form' do
        # Fill other languages but not English
        fill_in 'field_key[translations][es]', with: 'Piscina'
        
        click_button 'Create'
      end
      
      # HTML5 validation should prevent submission
      # The form should still be visible
      expect(page).to have_selector('#new-entry-form:not(.hidden)')
    end
  end
  
  describe 'sorting and ordering' do
    let!(:field_key1) { create(:pwb_field_key, tag: 'property-types', website: website, sort_order: 10) }
    let!(:field_key2) { create(:pwb_field_key, tag: 'property-types', website: website, sort_order: 5) }
    let!(:field_key3) { create(:pwb_field_key, tag: 'property-types', website: website, sort_order: 15) }
    
    it 'displays entries in sort_order' do
      visit site_admin_properties_settings_category_path('property_types')
      
      rows = all('tbody tr').map { |row| row.text }
      
      # Verify field_key2 (order 5) appears before field_key1 (order 10)
      key2_index = rows.index { |r| r.include?(field_key2.global_key.split('.').last) }
      key1_index = rows.index { |r| r.include?(field_key1.global_key.split('.').last) }
      
      expect(key2_index).to be < key1_index
    end
  end
end
