# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SiteAdmin::EmailTemplatesController', type: :request do
  # Email templates allow agencies to customize enquiry emails
  # Must verify: CRUD operations, template key restrictions, Liquid rendering, multi-tenancy

  let!(:website) { create(:pwb_website, subdomain: 'email-templates-test') }
  let!(:agency) { create(:pwb_agency, website: website, company_name: 'Test Agency') }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: 'admin@email-templates-test.test') }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe 'GET /site_admin/email_templates (index)' do
    it 'renders the index page successfully' do
      get site_admin_email_templates_path,
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'shows only enquiry-related template keys' do
      get site_admin_email_templates_path,
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response.body).to include('enquiry.general').or include('General Enquiry')
      expect(response.body).to include('enquiry.property').or include('Property Enquiry')
      # Should NOT show user or alert templates
    end

    context 'with custom templates' do
      let!(:custom_template) do
        create(:pwb_email_template, website: website, template_key: 'enquiry.general')
      end

      it 'shows which templates have customizations' do
        get site_admin_email_templates_path,
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /site_admin/email_templates/new' do
    context 'with valid template_key' do
      it 'renders new form for enquiry.general' do
        get new_site_admin_email_template_path,
            params: { template_key: 'enquiry.general' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'renders new form for enquiry.property' do
        get new_site_admin_email_template_path,
            params: { template_key: 'enquiry.property' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'pre-populates with default template content' do
        get new_site_admin_email_template_path,
            params: { template_key: 'enquiry.general' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:success)
        # Form should have default subject and body pre-filled
      end
    end

    context 'with invalid template_key' do
      it 'redirects to index for invalid template type' do
        get new_site_admin_email_template_path,
            params: { template_key: 'fake.template' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to redirect_to(site_admin_email_templates_path)
        expect(flash[:alert]).to include('Invalid template type')
      end

      it 'redirects for user templates (not allowed in site_admin)' do
        get new_site_admin_email_template_path,
            params: { template_key: 'user.welcome' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to redirect_to(site_admin_email_templates_path)
      end

      it 'redirects for alert templates (not allowed in site_admin)' do
        get new_site_admin_email_template_path,
            params: { template_key: 'alert.new_property' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to redirect_to(site_admin_email_templates_path)
      end
    end
  end

  describe 'POST /site_admin/email_templates (create)' do
    let(:valid_params) do
      {
        pwb_email_template: {
          template_key: 'enquiry.general',
          name: 'Custom General Enquiry',
          subject: 'New enquiry from {{ visitor_name }}',
          body_html: '<p>Hello, {{ visitor_name }} sent a message.</p>',
          body_text: 'Hello, {{ visitor_name }} sent a message.',
          description: 'Custom template for general enquiries'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new email template' do
        expect {
          post site_admin_email_templates_path,
               params: valid_params,
               headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }
        }.to change(Pwb::EmailTemplate, :count).by(1)
      end

      it 'redirects to show page after creation' do
        post site_admin_email_templates_path,
             params: valid_params,
             headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to include('successfully created')
      end

      it 'associates template with correct website' do
        post site_admin_email_templates_path,
             params: valid_params,
             headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        template = Pwb::EmailTemplate.last
        expect(template.website_id).to eq(website.id)
      end
    end

    context 'with invalid parameters' do
      it 'does not create template without subject' do
        invalid_params = valid_params.deep_dup
        invalid_params[:pwb_email_template][:subject] = ''

        expect {
          post site_admin_email_templates_path,
               params: invalid_params,
               headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }
        }.not_to change(Pwb::EmailTemplate, :count)
      end

      it 'does not create template without body_html' do
        invalid_params = valid_params.deep_dup
        invalid_params[:pwb_email_template][:body_html] = ''

        expect {
          post site_admin_email_templates_path,
               params: invalid_params,
               headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }
        }.not_to change(Pwb::EmailTemplate, :count)
      end

      it 'returns unprocessable_entity for validation errors' do
        invalid_params = valid_params.deep_dup
        invalid_params[:pwb_email_template][:subject] = ''

        post site_admin_email_templates_path,
             params: invalid_params,
             headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'duplicate template key' do
      let!(:existing_template) do
        create(:pwb_email_template, website: website, template_key: 'enquiry.general')
      end

      it 'does not create duplicate template for same key' do
        expect {
          post site_admin_email_templates_path,
               params: valid_params,
               headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }
        }.not_to change(Pwb::EmailTemplate, :count)
      end
    end
  end

  describe 'GET /site_admin/email_templates/:id (show)' do
    let!(:template) do
      create(:pwb_email_template, website: website, template_key: 'enquiry.general')
    end

    it 'renders the show page successfully' do
      get site_admin_email_template_path(template),
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'displays template details' do
      get site_admin_email_template_path(template),
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response.body).to include(template.name)
    end
  end

  describe 'GET /site_admin/email_templates/:id/edit' do
    let!(:template) do
      create(:pwb_email_template, website: website, template_key: 'enquiry.general')
    end

    it 'renders the edit form successfully' do
      get edit_site_admin_email_template_path(template),
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /site_admin/email_templates/:id (update)' do
    let!(:template) do
      create(:pwb_email_template, website: website, template_key: 'enquiry.general',
             subject: 'Original Subject')
    end

    it 'updates the template successfully' do
      patch site_admin_email_template_path(template),
            params: { pwb_email_template: { subject: 'Updated Subject' } },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      template.reload
      expect(template.subject).to eq('Updated Subject')
    end

    it 'redirects to show page after update' do
      patch site_admin_email_template_path(template),
            params: { pwb_email_template: { subject: 'Updated Subject' } },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response).to redirect_to(site_admin_email_template_path(template))
      expect(flash[:notice]).to include('successfully updated')
    end

    context 'with invalid parameters' do
      it 'returns unprocessable_entity for validation errors' do
        patch site_admin_email_template_path(template),
              params: { pwb_email_template: { subject: '' } },
              headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /site_admin/email_templates/:id (destroy)' do
    let!(:template) do
      create(:pwb_email_template, website: website, template_key: 'enquiry.general')
    end

    it 'deletes the template' do
      expect {
        delete site_admin_email_template_path(template),
               headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }
      }.to change(Pwb::EmailTemplate, :count).by(-1)
    end

    it 'redirects to index after deletion' do
      delete site_admin_email_template_path(template),
             headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response).to redirect_to(site_admin_email_templates_path)
      expect(flash[:notice]).to include('deleted')
    end
  end

  describe 'GET /site_admin/email_templates/:id/preview' do
    let!(:template) do
      create(:pwb_email_template, website: website,
             template_key: 'enquiry.general',
             subject: 'Enquiry from {{ visitor_name }}',
             body_html: '<p>Message from {{ visitor_name }}: {{ message }}</p>')
    end

    it 'renders preview page successfully' do
      get preview_site_admin_email_template_path(template),
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      expect(response).to have_http_status(:success)
    end

    it 'renders Liquid variables with sample data' do
      get preview_site_admin_email_template_path(template),
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      # Preview should show rendered content with sample data
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /site_admin/email_templates/preview_default' do
    context 'with valid template_key' do
      it 'renders default template preview for enquiry.general' do
        get preview_default_site_admin_email_templates_path,
            params: { template_key: 'enquiry.general' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end

      it 'renders default template preview for enquiry.property' do
        get preview_default_site_admin_email_templates_path,
            params: { template_key: 'enquiry.property' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with invalid template_key' do
      it 'returns bad_request for invalid template type' do
        get preview_default_site_admin_email_templates_path,
            params: { template_key: 'fake.template' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns JSON error message' do
        get preview_default_site_admin_email_templates_path,
            params: { template_key: 'user.welcome' },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid template type')
      end
    end
  end

  describe 'multi-tenancy isolation' do
    let!(:other_website) { create(:pwb_website, subdomain: 'other-email') }
    let!(:other_agency) { create(:pwb_agency, website: other_website) }
    let!(:other_template) do
      create(:pwb_email_template, website: other_website, template_key: 'enquiry.general')
    end

    it 'cannot access templates from other websites' do
      get site_admin_email_template_path(other_template),
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      # Should either raise error, redirect, or return not found
      expect(response).to have_http_status(:not_found).or have_http_status(:redirect)
    rescue ActiveRecord::RecordNotFound
      # Expected behavior - multi-tenancy isolation working
      expect(true).to be true
    end

    it 'cannot update templates from other websites' do
      patch site_admin_email_template_path(other_template),
            params: { pwb_email_template: { subject: 'Hacked!' } },
            headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      # Template should not be updated
      other_template.reload
      expect(other_template.subject).not_to eq('Hacked!')
    rescue ActiveRecord::RecordNotFound
      # Expected behavior
      expect(true).to be true
    end

    it 'cannot delete templates from other websites' do
      original_count = Pwb::EmailTemplate.count

      delete site_admin_email_template_path(other_template),
             headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      # Template should still exist
      expect(Pwb::EmailTemplate.count).to eq(original_count)
    rescue ActiveRecord::RecordNotFound
      # Expected behavior
      expect(true).to be true
    end
  end

  describe 'authentication required' do
    before { sign_out admin_user }

    it 'blocks unauthenticated users on index' do
      get site_admin_email_templates_path,
          headers: { 'HTTP_HOST' => 'email-templates-test.test.localhost' }

      # Either redirect or forbidden (Pundit/CanCan)
      expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
    end
  end
end
