# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_user_memberships
# Database name: primary
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  role       :string           default("member"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_user_memberships_on_user_id       (user_id)
#  index_pwb_user_memberships_on_website_id    (website_id)
#  index_user_memberships_on_user_and_website  (user_id,website_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
