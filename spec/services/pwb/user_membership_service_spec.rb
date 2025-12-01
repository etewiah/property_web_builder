require 'rails_helper'

module Pwb
  RSpec.describe UserMembershipService do
    let(:user) { FactoryBot.create(:pwb_user) }
    let(:website_a) { FactoryBot.create(:pwb_website, subdomain: 'tenant-a') }
    let(:website_b) { FactoryBot.create(:pwb_website, subdomain: 'tenant-b') }
    
    describe '.grant_access' do
      it 'creates a new membership' do
        expect {
          described_class.grant_access(user: user, website: website_a, role: 'admin')
        }.to change(UserMembership, :count).by(1)
        
        membership = UserMembership.last
        expect(membership.user).to eq(user)
        expect(membership.website).to eq(website_a)
        expect(membership.role).to eq('admin')
        expect(membership.active).to be true
      end
      
      it 'updates existing membership if present' do
        # Create initial membership
        described_class.grant_access(user: user, website: website_a, role: 'member')
        
        # Grant again with different role
        expect {
          described_class.grant_access(user: user, website: website_a, role: 'admin')
        }.not_to change(UserMembership, :count)
        
        membership = UserMembership.last
        expect(membership.role).to eq('admin')
      end
    end
    
    describe '.revoke_access' do
      it 'deactivates membership' do
        described_class.grant_access(user: user, website: website_a)
        
        described_class.revoke_access(user: user, website: website_a)
        
        membership = UserMembership.last
        expect(membership.active).to be false
      end
    end
    
    describe '.list_user_websites' do
      before do
        described_class.grant_access(user: user, website: website_a, role: 'admin')
        described_class.grant_access(user: user, website: website_b, role: 'member')
      end
      
      it 'lists all accessible websites' do
        websites = described_class.list_user_websites(user: user)
        expect(websites).to include(website_a, website_b)
      end
      
      it 'filters by role' do
        admin_sites = described_class.list_user_websites(user: user, role: 'admin')
        expect(admin_sites).to include(website_a)
        expect(admin_sites).not_to include(website_b)
      end
    end
    
    describe 'integration with User model' do
      before do
        described_class.grant_access(user: user, website: website_a, role: 'admin')
        described_class.grant_access(user: user, website: website_b, role: 'member')
      end
      
      it 'correctly reports admin status via user helper' do
        expect(user.admin_for?(website_a)).to be true
        expect(user.admin_for?(website_b)).to be false
      end
      
      it 'correctly reports role via user helper' do
        expect(user.role_for(website_a)).to eq('admin')
        expect(user.role_for(website_b)).to eq('member')
      end
    end
  end
end
