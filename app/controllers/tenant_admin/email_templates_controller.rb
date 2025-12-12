# frozen_string_literal: true

module TenantAdmin
  # EmailTemplatesController
  # Manages email templates across all websites (tenant admin level)
  class EmailTemplatesController < TenantAdminController
    before_action :set_website
    before_action :set_template, only: [:show, :edit, :update, :destroy, :preview]

    def index
      @websites = Pwb::Website.unscoped.order(:subdomain)

      if @website
        # Show templates for specific website
        @template_keys = Pwb::EmailTemplate::TEMPLATE_KEYS
        @custom_templates = @website.email_templates.index_by(&:template_key)
      else
        # Show overview of all websites and their template customizations
        @template_counts = Pwb::EmailTemplate.unscoped
                                              .group(:website_id)
                                              .count
      end
    end

    def show
      # Show the custom template or the default
    end

    def new
      @template_key = params[:template_key]

      unless Pwb::EmailTemplate::TEMPLATE_KEYS.key?(@template_key)
        redirect_to tenant_admin_email_templates_path(website_id: @website&.id), alert: "Invalid template type"
        return
      end

      # Pre-populate with default template content
      renderer = Pwb::EmailTemplateRenderer.new(website: @website, template_key: @template_key)
      defaults = renderer.default_template_content

      @email_template = @website.email_templates.build(
        template_key: @template_key,
        name: defaults[:name],
        subject: defaults[:subject],
        body_html: defaults[:body_html],
        body_text: defaults[:body_text],
        description: "Customize the #{defaults[:name]} email"
      )
    end

    def create
      @email_template = @website.email_templates.build(email_template_params)

      if @email_template.save
        redirect_to tenant_admin_email_template_path(@email_template),
                    notice: "Email template was successfully created."
      else
        @template_key = @email_template.template_key
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # Edit form
    end

    def update
      if @email_template.update(email_template_params)
        redirect_to tenant_admin_email_template_path(@email_template),
                    notice: "Email template was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      website_id = @email_template.website_id
      @email_template.destroy
      redirect_to tenant_admin_email_templates_path(website_id: website_id),
                  notice: "Email template was deleted. Default template will now be used."
    end

    def preview
      @preview = @email_template.preview_with_sample_data
    end

    # Preview a template key using default template (for templates not yet customized)
    def preview_default
      template_key = params[:template_key]

      unless Pwb::EmailTemplate::TEMPLATE_KEYS.key?(template_key)
        render json: { error: "Invalid template type" }, status: :bad_request
        return
      end

      renderer = Pwb::EmailTemplateRenderer.new(website: @website, template_key: template_key)
      sample_variables = generate_sample_variables(template_key)
      @preview = renderer.render(sample_variables)
      @template_key = template_key

      render :preview_default
    end

    private

    def set_website
      if params[:website_id].present?
        @website = Pwb::Website.unscoped.find(params[:website_id])
      elsif params[:id].present?
        # When accessing a specific template, get the website from it
        template = Pwb::EmailTemplate.unscoped.find_by(id: params[:id])
        @website = template&.website
      end
    end

    def set_template
      @email_template = Pwb::EmailTemplate.unscoped.find(params[:id])
      @website ||= @email_template.website
    end

    def email_template_params
      params.require(:pwb_email_template).permit(
        :template_key, :name, :description, :subject, :body_html, :body_text, :active
      )
    end

    def generate_sample_variables(template_key)
      variables = Pwb::EmailTemplate::TEMPLATE_VARIABLES[template_key] || []
      sample_data = {
        "website_name" => @website&.company_display_name || "Your Company",
        "visitor_name" => "John Smith",
        "visitor_email" => "john@example.com",
        "visitor_phone" => "+1 555-123-4567",
        "message" => "I am interested in learning more about your services.",
        "property_title" => "Beautiful 3 Bedroom House",
        "property_reference" => "PROP-001",
        "property_url" => "https://example.com/properties/1",
        "property_price" => "$350,000",
        "old_price" => "$375,000",
        "new_price" => "$350,000",
        "subscriber_name" => "Jane Doe",
        "user_name" => "Jane Doe",
        "user_email" => "jane@example.com",
        "reset_url" => "https://example.com/reset-password?token=abc123"
      }

      variables.each_with_object({}) { |var, hash| hash[var] = sample_data[var] }
    end
  end
end
