require 'rails_helper'

module Pwb
  RSpec.describe UserMembership, type: :model do
    let(:user) { FactoryBot.create(:pwb_user) }
    let(:website) { FactoryBot.create(:pwb_website) }
    
    subject { described_class.new(user: user, website: website, role: 'member') }
    
    describe 'validations' do
      it 'validates presence of role' do
        subject.role = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:role]).to include("can't be blank")
      end

      it 'validates inclusion of role' do
        subject.role = 'invalid_role'
        expect(subject).not_to be_valid
        expect(subject.errors[:role]).to include("is not included in the list")
      end
      
      it 'validates uniqueness of user scoped to website' do
        subject.save!
        duplicate = described_class.new(user: user, website: website, role: 'admin')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include("already has a membership for this website")
      end
    end
    
    describe 'roles' do
      it 'identifies admin roles correctly' do
        membership = described_class.new(role: 'admin')
        expect(membership.admin?).to be true
        expect(membership.owner?).to be false
        
        membership.role = 'owner'
        expect(membership.admin?).to be true
        expect(membership.owner?).to be true
        
        membership.role = 'member'
        expect(membership.admin?).to be false
      end
    end
    
    describe 'scopes' do
      let!(:active_member) { described_class.create!(user: FactoryBot.create(:pwb_user), website: website, role: 'member', active: true) }
      let!(:inactive_member) { described_class.create!(user: FactoryBot.create(:pwb_user), website: website, role: 'member', active: false) }
      let!(:admin) { described_class.create!(user: FactoryBot.create(:pwb_user), website: website, role: 'admin', active: true) }
      
      it 'active scope returns only active memberships' do
        expect(described_class.active).to include(active_member, admin)
        expect(described_class.active).not_to include(inactive_member)
      end
      
      it 'admins scope returns only admin/owner roles' do
        expect(described_class.admins).to include(admin)
        expect(described_class.admins).not_to include(active_member)
      end
    end
  end
end
