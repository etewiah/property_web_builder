require 'rails_helper'

module Pwb
  RSpec.describe User, type: :model do
    let(:user) { FactoryBot.create(:pwb_user, email: "user@example.org", password: "very-secret", admin: true) }
    it 'has a valid factory' do
      expect(user).to be_valid
    end

    describe 'role-based access methods' do
      let(:website) { FactoryBot.create(:pwb_website) }
      let(:other_website) { FactoryBot.create(:pwb_website) }
      let(:user) { FactoryBot.create(:pwb_user, website: website) }

      describe '#admin_for?' do
        context 'when user is owner for the website' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'owner', active: true)
          end

          it 'returns true' do
            expect(user.admin_for?(website)).to be true
          end
        end

        context 'when user is admin for the website' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'admin', active: true)
          end

          it 'returns true' do
            expect(user.admin_for?(website)).to be true
          end
        end

        context 'when user is member for the website' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'member', active: true)
          end

          it 'returns false' do
            expect(user.admin_for?(website)).to be false
          end
        end

        context 'when user is viewer for the website' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'viewer', active: true)
          end

          it 'returns false' do
            expect(user.admin_for?(website)).to be false
          end
        end

        context 'when user has no membership for the website' do
          it 'returns false' do
            expect(user.admin_for?(website)).to be false
          end
        end

        context 'when user has inactive admin membership' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'admin', active: false)
          end

          it 'returns false' do
            expect(user.admin_for?(website)).to be false
          end
        end

        context 'when user is admin for a different website' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: other_website, role: 'admin', active: true)
          end

          it 'returns false for the requested website' do
            expect(user.admin_for?(website)).to be false
          end

          it 'returns true for the other website' do
            expect(user.admin_for?(other_website)).to be true
          end
        end
      end

      describe '#role_for' do
        context 'when user has owner membership' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'owner', active: true)
          end

          it 'returns owner' do
            expect(user.role_for(website)).to eq('owner')
          end
        end

        context 'when user has admin membership' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'admin', active: true)
          end

          it 'returns admin' do
            expect(user.role_for(website)).to eq('admin')
          end
        end

        context 'when user has member membership' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'member', active: true)
          end

          it 'returns member' do
            expect(user.role_for(website)).to eq('member')
          end
        end

        context 'when user has no membership' do
          it 'returns nil' do
            expect(user.role_for(website)).to be_nil
          end
        end

        context 'when user has inactive membership' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'admin', active: false)
          end

          it 'returns nil' do
            expect(user.role_for(website)).to be_nil
          end
        end
      end

      describe '#accessible_websites' do
        let!(:membership1) { FactoryBot.create(:pwb_user_membership, user: user, website: website, role: 'member', active: true) }
        let!(:membership2) { FactoryBot.create(:pwb_user_membership, user: user, website: other_website, role: 'admin', active: true) }

        it 'returns all websites with active memberships' do
          expect(user.accessible_websites).to include(website, other_website)
        end

        context 'when one membership is inactive' do
          before { membership2.update!(active: false) }

          it 'excludes the inactive website' do
            expect(user.accessible_websites).to include(website)
            expect(user.accessible_websites).not_to include(other_website)
          end
        end
      end

      describe '#can_access_website?' do
        context 'when website is user primary website' do
          it 'returns true' do
            expect(user.can_access_website?(website)).to be true
          end
        end

        context 'when user has active membership' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: other_website, role: 'member', active: true)
          end

          it 'returns true' do
            expect(user.can_access_website?(other_website)).to be true
          end
        end

        context 'when user has inactive membership' do
          before do
            FactoryBot.create(:pwb_user_membership, user: user, website: other_website, role: 'member', active: false)
          end

          it 'returns false' do
            expect(user.can_access_website?(other_website)).to be false
          end
        end

        context 'when user has no relationship with website' do
          let(:random_website) { FactoryBot.create(:pwb_website) }

          it 'returns false' do
            expect(user.can_access_website?(random_website)).to be false
          end
        end

        context 'when website is nil' do
          it 'returns false' do
            expect(user.can_access_website?(nil)).to be false
          end
        end
      end
    end

    # tests authorization with omniauth
    describe '.find_for_oauth' do
      let!(:user) { FactoryBot.create(:pwb_user, email: "user@example.org", password: "very-secret") }
      let(:auth) { OmniAuth::AuthHash.new(provider: 'facebook', uid: '123456') }

      context 'user already has authorization' do
        it 'returns the user' do
          user.authorizations.create(provider: 'facebook', uid: '123456')
          expect(User.find_for_oauth(auth)).to eq user
        end
      end

      context 'user has not authorization' do
        context 'user already exists' do
          let(:auth) { OmniAuth::AuthHash.new(provider: 'facebook', uid: '123456', info: { email: user.email }) }
          it 'does not create new user' do
            expect { User.find_for_oauth(auth) }.to_not change(User, :count)
          end

          it 'creates authorization for user' do
            expect { User.find_for_oauth(auth) }.to change(user.authorizations, :count).by(1)
          end

          it 'creates authorization with provider and uid' do
            authorization = User.find_for_oauth(auth).authorizations.first

            expect(authorization.provider).to eq auth.provider
            expect(authorization.uid).to eq auth.uid
          end

          it 'returns the user' do
            expect(User.find_for_oauth(auth)).to eq user
          end
        end

        context 'user does not exist' do
          let(:auth) { OmniAuth::AuthHash.new(provider: 'facebook', uid: '123456', info: { email: 'new@user.com' }) }
          let(:website) { FactoryBot.create(:pwb_website) }

          it 'creates new user' do
            expect { User.find_for_oauth(auth, website: website) }.to change(User, :count).by(1)
          end

          it 'returns new user' do
            expect(User.find_for_oauth(auth, website: website)).to be_a(User)
          end

          it 'fills user email' do
            user = User.find_for_oauth(auth, website: website)
            expect(user.email).to eq auth.info[:email]
          end

          it 'creates authorization for user' do
            user = User.find_for_oauth(auth, website: website)
            expect(user.authorizations).to_not be_empty
          end

          it 'creates authorization with provider and uid' do
            authorization = User.find_for_oauth(auth, website: website).authorizations.first

            expect(authorization.provider).to eq auth.provider
            expect(authorization.uid).to eq auth.uid
          end
        end
      end
    end
  end
end
