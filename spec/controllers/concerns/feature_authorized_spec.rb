# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeatureAuthorized, type: :request do
  # Test using the domains controller which requires 'custom_domain' feature
  describe 'feature gating' do
    let(:website) { create(:website) }
    let(:admin_user) { create(:user, :admin, website: website) }

    before do
      sign_in admin_user
      allow_any_instance_of(ApplicationController).to receive(:current_website).and_return(website)
      allow_any_instance_of(SiteAdminController).to receive(:current_website).and_return(website)
    end

    context 'when feature is NOT available on the plan' do
      let(:basic_plan) { create(:pwb_plan, :starter, features: ['basic_themes']) }

      before do
        # Create subscription with a plan that doesn't have custom_domain
        create(:pwb_subscription, :active, website: website, plan: basic_plan)
      end

      it 'redirects to billing page with alert message' do
        get site_admin_domain_path

        expect(response).to redirect_to(site_admin_billing_path)
        follow_redirect!
        expect(flash[:alert]).to include('not included in your current plan')
      end

      it 'returns forbidden status for JSON requests' do
        get site_admin_domain_path, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('feature_not_authorized')
        expect(json['feature']).to eq('custom_domain')
      end
    end

    context 'when feature IS available on the plan' do
      let(:pro_plan) { create(:pwb_plan, :professional, features: ['basic_themes', 'custom_domain']) }

      before do
        # Create subscription with a plan that has custom_domain
        create(:pwb_subscription, :active, website: website, plan: pro_plan)
      end

      it 'allows access to the page' do
        get site_admin_domain_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Domain Settings')
      end
    end

    context 'when website has no subscription' do
      # No subscription = no plan features check (returns false from has_feature?)
      it 'redirects to billing page' do
        get site_admin_domain_path

        expect(response).to redirect_to(site_admin_billing_path)
      end
    end
  end
end
