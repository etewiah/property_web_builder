# frozen_string_literal: true

module Pwb
  class EmailTemplate < ApplicationRecord
    self.table_name = 'pwb_email_templates'

    belongs_to :website, class_name: "Pwb::Website"

    # Template keys for different email types
    TEMPLATE_KEYS = {
      # Contact form emails
      "enquiry.general" => "General Enquiry",
      "enquiry.property" => "Property Enquiry",
      "enquiry.auto_reply" => "Enquiry Auto-Reply to Visitor",

      # Property alerts
      "alert.new_property" => "New Property Alert",
      "alert.price_change" => "Price Change Alert",

      # User emails
      "user.welcome" => "Welcome Email",
      "user.password_reset" => "Password Reset"
    }.freeze

    # Default variables available in each template type
    TEMPLATE_VARIABLES = {
      "enquiry.general" => %w[visitor_name visitor_email visitor_phone message website_name],
      "enquiry.property" => %w[visitor_name visitor_email visitor_phone message property_title property_reference property_url website_name],
      "enquiry.auto_reply" => %w[visitor_name website_name],
      "alert.new_property" => %w[subscriber_name property_title property_price property_url website_name],
      "alert.price_change" => %w[subscriber_name property_title old_price new_price property_url website_name],
      "user.welcome" => %w[user_name user_email website_name],
      "user.password_reset" => %w[user_name reset_url website_name]
    }.freeze

    # Validations
    validates :template_key, presence: true,
                             inclusion: { in: TEMPLATE_KEYS.keys, message: "is not a valid template type" }
    validates :name, presence: true, length: { maximum: 100 }
    validates :subject, presence: true, length: { maximum: 200 }
    validates :body_html, presence: true
    validates :template_key, uniqueness: { scope: :website_id, message: "already exists for this website" }

    # Scopes
    scope :active, -> { where(active: true) }
    scope :by_key, ->(key) { where(template_key: key) }

    # Find template for a website, falling back to default if not customized
    def self.find_for_website(website, template_key)
      active.find_by(website: website, template_key: template_key)
    end

    # Render the subject line with Liquid variables
    def render_subject(variables = {})
      render_liquid(subject, variables)
    end

    # Render the HTML body with Liquid variables
    def render_body_html(variables = {})
      render_liquid(body_html, variables)
    end

    # Render the plain text body with Liquid variables
    def render_body_text(variables = {})
      return nil if body_text.blank?

      render_liquid(body_text, variables)
    end

    # Get available variables for this template type
    def available_variables
      TEMPLATE_VARIABLES[template_key] || []
    end

    # Preview the template with sample data
    def preview_with_sample_data
      sample_data = generate_sample_data
      {
        subject: render_subject(sample_data),
        body_html: render_body_html(sample_data),
        body_text: render_body_text(sample_data)
      }
    end

    private

    def render_liquid(template_string, variables)
      template = Liquid::Template.parse(template_string)
      template.render(variables.stringify_keys)
    rescue Liquid::SyntaxError => e
      Rails.logger.error("Liquid template syntax error: #{e.message}")
      template_string # Return unrendered template on error
    end

    def generate_sample_data
      base_data = {
        "website_name" => website&.company_display_name || "Your Company",
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

      # Return only variables relevant to this template type
      available_variables.each_with_object({}) do |var, hash|
        hash[var] = base_data[var]
      end
    end
  end
end
