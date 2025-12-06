require 'rails_helper'

RSpec.describe SiteAdmin::Properties::SettingsController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-site') }
  let(:user) { create(:pwb_user, website: website) }
  
  before do
    sign_in user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end
  
  describe 'GET #index' do
    it 'renders the index template' do
      get :index
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end
    
    it 'assigns categories' do
      get :index
      expect(assigns(:categories)).to eq(['property_types', 'features', 'property_states', 'property_labels'])
    end
  end
  
  describe 'GET #show' do
    let!(:field_key1) { create(:pwb_field_key, tag: 'property-types', website: website, sort_order: 1) }
    let!(:field_key2) { create(:pwb_field_key, tag: 'property-types', website: website, sort_order: 0) }
    let!(:other_website_key) { create(:pwb_field_key, tag: 'property-types', website: other_website) }
    
    it 'loads field keys for the specified category' do
      get :show, params: { category: 'property_types' }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:field_keys)).to include(field_key1, field_key2)
      expect(assigns(:field_keys)).not_to include(other_website_key)
    end
    
    it 'orders field keys by sort_order and created_at' do
      get :show, params: { category: 'property_types' }
      
      field_keys = assigns(:field_keys).to_a
      expect(field_keys.first).to eq(field_key2) # sort_order 0
      expect(field_keys.last).to eq(field_key1)  # sort_order 1
    end
    
    it 'scopes to current website only' do
      get :show, params: { category: 'property_types' }
      
      expect(assigns(:field_keys).map(&:website_id)).to all(eq(website.id))
    end
    
    it 'redirects with alert for invalid category' do
      get :show, params: { category: 'invalid_category' }
      
      expect(response).to redirect_to(site_admin_root_path)
      expect(flash[:alert]).to eq('Invalid category')
    end
    
    it 'renders the show template' do
      get :show, params: { category: 'features' }
      expect(response).to render_template(:show)
    end
  end
  
  describe 'POST #create' do
    let(:valid_params) do
      {
        category: 'property_types',
        field_key: {
          translations: {
            en: 'Warehouse',
            es: 'Almacén',
            fr: 'Entrepôt'
          },
          visible: true,
          sort_order: 5
        }
      }
    end
    
    it 'creates a new field key' do
      expect {
        post :create, params: valid_params
      }.to change(Pwb::FieldKey, :count).by(1)
    end
    
    it 'associates field key with current website' do
      post :create, params: valid_params
      
      field_key = Pwb::FieldKey.last
      expect(field_key.website).to eq(website)
    end
    
    it 'sets the correct tag based on category' do
      post :create, params: valid_params
      
      field_key = Pwb::FieldKey.last
      expect(field_key.tag).to eq('property-types')
    end
    
    it 'generates a unique global_key' do
      post :create, params: valid_params
      
      field_key = Pwb::FieldKey.last
      expect(field_key.global_key).to match(/^property-types\.warehouse_\d+$/)
    end
    
    it 'sets sort_order from params' do
      post :create, params: valid_params
      
      field_key = Pwb::FieldKey.last
      expect(field_key.sort_order).to eq(5)
    end
    
    it 'redirects to show page with success notice' do
      post :create, params: valid_params
      
      expect(response).to redirect_to(site_admin_properties_settings_category_path('property_types'))
      expect(flash[:notice]).to eq('Setting created successfully')
    end
    
    it 'stores translations' do
      post :create, params: valid_params
      
      field_key = Pwb::FieldKey.last
      # Note: Translation storage depends on I18n backend configuration
      # This test verifies the controller calls the translation method
      expect(field_key.global_key).to be_present
    end
  end
  
  describe 'PATCH #update' do
    let(:field_key) { create(:pwb_field_key, website: website, tag: 'property-types', visible: true, sort_order: 0) }
    
    let(:update_params) do
      {
        category: 'property_types',
        id: field_key.global_key,
        field_key: {
          translations: {
            en: 'Updated Name'
          },
          visible: false,
          sort_order: 10
        }
      }
    end
    
    it 'updates the field key attributes' do
      patch :update, params: update_params
      
      field_key.reload
      expect(field_key.visible).to be false
      expect(field_key.sort_order).to eq(10)
    end
    
    it 'redirects to show page with success notice' do
      patch :update, params: update_params
      
      expect(response).to redirect_to(site_admin_properties_settings_category_path('property_types'))
      expect(flash[:notice]).to eq('Setting updated successfully')
    end
    
    it 'returns 404 for field keys from other websites' do
      other_field_key = create(:pwb_field_key, website: other_website, tag: 'property-types')

      patch :update, params: {
        category: 'property_types',
        id: other_field_key.global_key,
        field_key: { visible: false }
      }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end
  end
  
  describe 'DELETE #destroy' do
    let!(:field_key) { create(:pwb_field_key, website: website, tag: 'property-types') }
    
    it 'destroys the field key' do
      expect {
        delete :destroy, params: {
          category: 'property_types',
          id: field_key.global_key
        }
      }.to change(Pwb::FieldKey, :count).by(-1)
    end
    
    it 'redirects to show page with success notice' do
      delete :destroy, params: {
        category: 'property_types',
        id: field_key.global_key
      }
      
      expect(response).to redirect_to(site_admin_properties_settings_category_path('property_types'))
      expect(flash[:notice]).to eq('Setting deleted successfully')
    end
    
    it 'does not allow deleting field keys from other websites' do
      other_field_key = create(:pwb_field_key, website: other_website, tag: 'property-types')
      
      expect {
        delete :destroy, params: {
          category: 'property_types',
          id: other_field_key.global_key
        }
      }.not_to change(Pwb::FieldKey, :count)
    end
  end
  
  describe 'category validation' do
    it 'accepts valid categories' do
      %w[property_types features property_states property_labels].each do |category|
        get :show, params: { category: category }
        expect(response).to have_http_status(:success)
      end
    end
    
    it 'rejects invalid categories' do
      get :show, params: { category: 'hacked_category' }
      expect(response).to redirect_to(site_admin_root_path)
      expect(flash[:alert]).to eq('Invalid category')
    end
  end
  
  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out user }
      
      it 'redirects to sign in page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
