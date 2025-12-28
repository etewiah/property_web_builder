# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::MessagesController, type: :controller do
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
    let!(:message_own) do
      Pwb::Message.create!(
        origin_email: 'sender@own.com',
        content: 'Own message',
        website_id: website.id
      )
    end

    let!(:message_other) do
      Pwb::Message.create!(
        origin_email: 'sender@other.com',
        content: 'Other message',
        website_id: other_website.id
      )
    end

    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'only includes messages from the current website' do
      get :index

      messages = assigns(:messages)
      expect(messages).to include(message_own)
      expect(messages).not_to include(message_other)
    end

    it 'all returned messages belong to current website' do
      3.times do |i|
        Pwb::Message.create!(origin_email: "test#{i}@own.com", content: "Test #{i}", website_id: website.id)
        Pwb::Message.create!(origin_email: "test#{i}@other.com", content: "Other #{i}", website_id: other_website.id)
      end

      get :index

      messages = assigns(:messages)
      expect(messages.pluck(:website_id).uniq).to eq([website.id])
    end

    describe 'search functionality' do
      let!(:searchable_message) do
        Pwb::Message.create!(
          origin_email: 'searchable@own.com',
          content: 'Searchable content',
          website_id: website.id
        )
      end

      let!(:other_searchable_message) do
        Pwb::Message.create!(
          origin_email: 'searchable@other.com',
          content: 'Searchable content',
          website_id: other_website.id
        )
      end

      it 'searches only within current website messages' do
        get :index, params: { search: 'searchable' }

        messages = assigns(:messages)
        expect(messages).to include(searchable_message)
        expect(messages).not_to include(other_searchable_message)
      end
    end
  end

  describe 'GET #show' do
    let!(:message_own) do
      Pwb::Message.create!(
        origin_email: 'sender@own.com',
        content: 'Own message',
        website_id: website.id,
        read: false
      )
    end

    let!(:message_other) do
      Pwb::Message.create!(
        origin_email: 'sender@other.com',
        content: 'Other message',
        website_id: other_website.id
      )
    end

    it 'allows viewing own website message' do
      get :show, params: { id: message_own.id }

      expect(response).to have_http_status(:success)
      expect(assigns(:message)).to eq(message_own)
    end

    it 'returns 404 for other website message' do
      get :show, params: { id: message_other.id }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end

    it 'returns 404 for non-existent message' do
      get :show, params: { id: SecureRandom.uuid }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('site_admin/shared/record_not_found')
    end

    describe 'marking message as read' do
      it 'marks an unread message as read when viewed' do
        expect(message_own.read?).to be false

        get :show, params: { id: message_own.id }

        message_own.reload
        expect(message_own.read?).to be true
      end

      it 'does not update an already-read message' do
        message_own.update!(read: true)

        # Record original timestamps
        original_updated_at = message_own.updated_at

        get :show, params: { id: message_own.id }

        message_own.reload
        expect(message_own.read?).to be true
        # updated_at should not change since we skip the update for already-read messages
        expect(message_own.updated_at).to be_within(1.second).of(original_updated_at)
      end

      it 'creates an audit log entry when marking as read' do
        expect {
          get :show, params: { id: message_own.id }
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        audit_log = Pwb::AuthAuditLog.last
        expect(audit_log.event_type).to eq('message_read')
        expect(audit_log.user).to eq(user)
        expect(audit_log.website).to eq(website)
        expect(audit_log.metadata['message_id']).to eq(message_own.id)
        expect(audit_log.metadata['message_origin_email']).to eq('sender@own.com')
      end

      it 'does not create an audit log for already-read messages' do
        message_own.update!(read: true)

        expect {
          get :show, params: { id: message_own.id }
        }.not_to change(Pwb::AuthAuditLog, :count)
      end
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out :user }

      it 'denies access' do
        get :index
        # May redirect to sign in or return 403 forbidden depending on auth configuration
        expect(response.status).to eq(302).or eq(403)
      end
    end
  end
end
