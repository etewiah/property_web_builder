# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiPublic::V1::BaseController, type: :controller do
  describe 'configuration' do
    it 'includes the SubdomainTenant concern' do
      expect(described_class.ancestors).to include(SubdomainTenant)
    end

    it 'has set_current_website_from_subdomain before_action from concern' do
      before_actions = described_class._process_action_callbacks
        .select { |cb| cb.kind == :before }
        .map(&:filter)
      
      expect(before_actions).to include(:set_current_website_from_subdomain)
    end
  end
end
