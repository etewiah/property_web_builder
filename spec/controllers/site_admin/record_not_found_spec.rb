# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::PropsController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-site') }
  let(:user) { create(:pwb_user, :admin, website: website) }
  let(:non_existent_uuid) { SecureRandom.uuid }

  before do
    Pwb::Current.reset
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end

  describe 'record not found handling' do
    describe 'GET #show with non-existent property' do
      it 'returns 404 status' do
        get :show, params: { id: non_existent_uuid }
        expect(response).to have_http_status(:not_found)
      end

      it 'renders the record not found template' do
        get :show, params: { id: non_existent_uuid }
        expect(response).to render_template('site_admin/shared/record_not_found')
      end

      it 'preserves the URL (no redirect)' do
        get :show, params: { id: non_existent_uuid }
        expect(response).not_to be_redirect
      end

      it 'sets the resource type for display' do
        get :show, params: { id: non_existent_uuid }
        expect(assigns(:resource_type)).to eq('Prop')
      end
    end

    describe 'with property from another website' do
      let!(:other_property) do
        create(:pwb_realty_asset, website: other_website)
      end

      it 'returns 404 for cross-tenant access attempt' do
        get :show, params: { id: other_property.id }
        expect(response).to have_http_status(:not_found)
      end

      it 'renders the record not found template' do
        get :show, params: { id: other_property.id }
        expect(response).to render_template('site_admin/shared/record_not_found')
      end

      it 'does not expose the other tenant resource' do
        get :show, params: { id: other_property.id }
        expect(assigns(:prop)).to be_nil
      end
    end
  end
end
