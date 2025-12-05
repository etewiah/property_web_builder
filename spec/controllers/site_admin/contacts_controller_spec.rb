# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteAdmin::ContactsController, type: :controller do
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
    let!(:contact_own) do
      Pwb::Contact.create!(
        first_name: 'Own',
        last_name: 'Contact',
        primary_email: 'own@test.com',
        website_id: website.id
      )
    end

    let!(:contact_other) do
      Pwb::Contact.create!(
        first_name: 'Other',
        last_name: 'Contact',
        primary_email: 'other@test.com',
        website_id: other_website.id
      )
    end

    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'only includes contacts from the current website' do
      get :index

      contacts = assigns(:contacts)
      expect(contacts).to include(contact_own)
      expect(contacts).not_to include(contact_other)
    end

    it 'all returned contacts belong to current website' do
      # Create more contacts for both websites
      3.times do |i|
        Pwb::Contact.create!(first_name: "Test#{i}", website_id: website.id)
        Pwb::Contact.create!(first_name: "Other#{i}", website_id: other_website.id)
      end

      get :index

      contacts = assigns(:contacts)
      expect(contacts.pluck(:website_id).uniq).to eq([website.id])
    end

    describe 'search functionality' do
      let!(:searchable_contact) do
        Pwb::Contact.create!(
          first_name: 'Searchable',
          last_name: 'Person',
          primary_email: 'searchable@test.com',
          website_id: website.id
        )
      end

      let!(:other_searchable_contact) do
        Pwb::Contact.create!(
          first_name: 'Searchable',
          last_name: 'Other',
          primary_email: 'searchable@other.com',
          website_id: other_website.id
        )
      end

      it 'searches only within current website contacts' do
        get :index, params: { search: 'Searchable' }

        contacts = assigns(:contacts)
        expect(contacts).to include(searchable_contact)
        expect(contacts).not_to include(other_searchable_contact)
      end
    end
  end

  describe 'GET #show' do
    let!(:contact_own) do
      Pwb::Contact.create!(
        first_name: 'Own',
        last_name: 'Contact',
        primary_email: 'own@test.com',
        website_id: website.id
      )
    end

    let!(:contact_other) do
      Pwb::Contact.create!(
        first_name: 'Other',
        last_name: 'Contact',
        primary_email: 'other@test.com',
        website_id: other_website.id
      )
    end

    it 'allows viewing own website contact' do
      get :show, params: { id: contact_own.id }

      expect(response).to have_http_status(:success)
      expect(assigns(:contact)).to eq(contact_own)
    end

    it 'raises RecordNotFound for other website contact' do
      expect {
        get :show, params: { id: contact_other.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'does not expose non-existent contacts' do
      # When accessing a non-existent contact, an error is raised
      # The specific error type may vary based on the implementation
      expect {
        get :show, params: { id: 999999 }
      }.to raise_error(StandardError)
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
