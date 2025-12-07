# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/constraints/tenant_admin_constraint'

RSpec.describe Constraints::TenantAdminConstraint do
  let(:constraint) { described_class.new }
  let(:website) { create(:pwb_website) }
  let(:warden) { double('warden') }
  let(:request) { double('request', env: { 'warden' => warden }) }

  describe '#matches?' do
    context 'when user is not authenticated' do
      before do
        allow(warden).to receive(:user).and_return(nil)
      end

      it 'returns false' do
        expect(constraint.matches?(request)).to be false
      end
    end

    context 'when user email is in TENANT_ADMIN_EMAILS' do
      let(:user) { create(:pwb_user, email: 'admin@example.com', website: website) }

      before do
        allow(warden).to receive(:user).and_return(user)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com,super@example.com')
      end

      it 'returns true' do
        expect(constraint.matches?(request)).to be true
      end
    end

    context 'when user email is in TENANT_ADMIN_EMAILS (case insensitive)' do
      let(:user) { create(:pwb_user, email: 'ADMIN@EXAMPLE.COM', website: website) }

      before do
        allow(warden).to receive(:user).and_return(user)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
      end

      it 'returns true' do
        expect(constraint.matches?(request)).to be true
      end
    end

    context 'when user email is NOT in TENANT_ADMIN_EMAILS' do
      let(:user) { create(:pwb_user, email: 'regular@example.com', website: website) }

      before do
        allow(warden).to receive(:user).and_return(user)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
      end

      it 'returns false' do
        expect(constraint.matches?(request)).to be false
      end
    end

    context 'when TENANT_ADMIN_EMAILS is empty' do
      let(:user) { create(:pwb_user, email: 'admin@example.com', website: website) }

      before do
        allow(warden).to receive(:user).and_return(user)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('')
      end

      it 'returns false' do
        expect(constraint.matches?(request)).to be false
      end
    end

    context 'when email list has whitespace' do
      let(:user) { create(:pwb_user, email: 'admin@example.com', website: website) }

      before do
        allow(warden).to receive(:user).and_return(user)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('  admin@example.com  ,  super@example.com  ')
      end

      it 'strips whitespace and returns true' do
        expect(constraint.matches?(request)).to be true
      end
    end

    context 'when BYPASS_ADMIN_AUTH is set in non-production' do
      let(:user) { create(:pwb_user, email: 'regular@example.com', website: website) }

      before do
        allow(warden).to receive(:user).and_return(user)
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('BYPASS_ADMIN_AUTH', 'false').and_return('true')
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
      end

      it 'returns true even for non-whitelisted users' do
        expect(constraint.matches?(request)).to be true
      end
    end

    context 'when BYPASS_ADMIN_AUTH is set in production' do
      let(:user) { create(:pwb_user, email: 'regular@example.com', website: website) }

      before do
        allow(warden).to receive(:user).and_return(user)
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('BYPASS_ADMIN_AUTH', 'false').and_return('true')
        allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
      end

      it 'ignores bypass and returns false for non-whitelisted users' do
        expect(constraint.matches?(request)).to be false
      end
    end
  end
end
