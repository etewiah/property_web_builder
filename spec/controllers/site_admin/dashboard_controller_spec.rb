# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::DashboardController, type: :controller do
  let(:website) { create(:pwb_website, subdomain: 'test-site') }
  let(:other_website) { create(:pwb_website, subdomain: 'other-site') }
  let(:user) { create(:pwb_user, :admin, website: website) }

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user, scope: :user
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(controller).to receive(:current_website).and_return(website)
  end

  describe 'GET #index' do
    context 'with data from multiple websites' do
      before do
        # Create data for own website
        3.times do |i|
          Pwb::Contact.create!(first_name: "OwnContact#{i}", website_id: website.id)
          Pwb::Message.create!(origin_email: "own#{i}@test.com", content: "Own #{i}", website_id: website.id)
          Pwb::Page.create!(slug: "own-page-#{i}", website_id: website.id)
          Pwb::Content.create!(key: "own_content_#{i}", tag: 'test', website_id: website.id)
        end

        # Create data for other website (should NOT be counted)
        5.times do |i|
          Pwb::Contact.create!(first_name: "OtherContact#{i}", website_id: other_website.id)
          Pwb::Message.create!(origin_email: "other#{i}@test.com", content: "Other #{i}", website_id: other_website.id)
          Pwb::Page.create!(slug: "other-page-#{i}", website_id: other_website.id)
          Pwb::Content.create!(key: "other_content_#{i}", tag: 'test', website_id: other_website.id)
        end
      end

      it 'returns success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      describe 'statistics' do
        it 'only counts contacts from current website' do
          get :index

          stats = assigns(:stats)
          expect(stats[:total_contacts]).to eq(3)
        end

        it 'only counts messages from current website' do
          get :index

          stats = assigns(:stats)
          expect(stats[:total_messages]).to eq(3)
        end

        it 'only counts pages from current website' do
          get :index

          stats = assigns(:stats)
          expect(stats[:total_pages]).to eq(3)
        end

        it 'only counts contents from current website' do
          get :index

          stats = assigns(:stats)
          expect(stats[:total_contents]).to eq(3)
        end

        it 'does not include other website data in any stats' do
          get :index

          stats = assigns(:stats)
          # Each stat should be exactly 3 (our website's data), not 8 (total across both)
          expect(stats[:total_contacts]).not_to eq(8)
          expect(stats[:total_messages]).not_to eq(8)
          expect(stats[:total_pages]).not_to eq(8)
          expect(stats[:total_contents]).not_to eq(8)
        end
      end

      describe 'recent activity' do
        it 'only shows recent contacts from current website' do
          get :index

          recent_contacts = assigns(:recent_contacts)
          expect(recent_contacts.pluck(:website_id).uniq).to eq([website.id])
          expect(recent_contacts.count).to eq(3)
        end

        it 'only shows recent messages from current website' do
          get :index

          recent_messages = assigns(:recent_messages)
          expect(recent_messages.pluck(:website_id).uniq).to eq([website.id])
          expect(recent_messages.count).to eq(3)
        end

        it 'does not leak data from other websites in recent contacts' do
          get :index

          recent_contacts = assigns(:recent_contacts)
          other_website_contacts = recent_contacts.select { |c| c.website_id == other_website.id }
          expect(other_website_contacts).to be_empty
        end

        it 'does not leak data from other websites in recent messages' do
          get :index

          recent_messages = assigns(:recent_messages)
          other_website_messages = recent_messages.select { |m| m.website_id == other_website.id }
          expect(other_website_messages).to be_empty
        end
      end
    end

    context 'with empty website' do
      it 'returns zero counts when website has no data' do
        get :index

        stats = assigns(:stats)
        expect(stats[:total_contacts]).to eq(0)
        expect(stats[:total_messages]).to eq(0)
      end

      it 'returns empty recent activity arrays' do
        get :index

        expect(assigns(:recent_contacts)).to be_empty
        expect(assigns(:recent_messages)).to be_empty
      end
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'redirects to sign in page' do
        get :index
        expect(response).to redirect_to(new_user_session_path(locale: :en))
      end
    end
  end
end
