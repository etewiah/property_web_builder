# frozen_string_literal: true

module Pwb
  # Service to render email templates with Liquid variables
  # Falls back to default templates if no custom template exists
  class EmailTemplateRenderer
    attr_reader :website, :template_key

    # Default templates used when no custom template exists
    DEFAULT_TEMPLATES = {
      "enquiry.general" => {
        subject: "New enquiry from {{ visitor_name }}",
        body_html: <<~HTML
          <h2>New General Enquiry</h2>
          <p>You have received a new enquiry from your website.</p>
          <table style="border-collapse: collapse; width: 100%;">
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd;"><strong>Name:</strong></td>
              <td style="padding: 8px; border: 1px solid #ddd;">{{ visitor_name }}</td>
            </tr>
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd;"><strong>Email:</strong></td>
              <td style="padding: 8px; border: 1px solid #ddd;">{{ visitor_email }}</td>
            </tr>
            {% if visitor_phone %}
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd;"><strong>Phone:</strong></td>
              <td style="padding: 8px; border: 1px solid #ddd;">{{ visitor_phone }}</td>
            </tr>
            {% endif %}
          </table>
          <h3>Message:</h3>
          <p>{{ message }}</p>
        HTML
      },
      "enquiry.property" => {
        subject: "Property enquiry: {{ property_title }}",
        body_html: <<~HTML
          <h2>New Property Enquiry</h2>
          <p>You have received an enquiry about a property.</p>
          <h3>Property Details:</h3>
          <p><strong>{{ property_title }}</strong><br>
          Reference: {{ property_reference }}<br>
          <a href="{{ property_url }}">View Property</a></p>
          <h3>Contact Information:</h3>
          <table style="border-collapse: collapse; width: 100%;">
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd;"><strong>Name:</strong></td>
              <td style="padding: 8px; border: 1px solid #ddd;">{{ visitor_name }}</td>
            </tr>
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd;"><strong>Email:</strong></td>
              <td style="padding: 8px; border: 1px solid #ddd;">{{ visitor_email }}</td>
            </tr>
            {% if visitor_phone %}
            <tr>
              <td style="padding: 8px; border: 1px solid #ddd;"><strong>Phone:</strong></td>
              <td style="padding: 8px; border: 1px solid #ddd;">{{ visitor_phone }}</td>
            </tr>
            {% endif %}
          </table>
          <h3>Message:</h3>
          <p>{{ message }}</p>
        HTML
      },
      "enquiry.auto_reply" => {
        subject: "Thank you for contacting {{ website_name }}",
        body_html: <<~HTML
          <h2>Thank you for your enquiry</h2>
          <p>Dear {{ visitor_name }},</p>
          <p>Thank you for contacting {{ website_name }}. We have received your message and will get back to you as soon as possible.</p>
          <p>Best regards,<br>
          The {{ website_name }} Team</p>
        HTML
      },
      "alert.new_property" => {
        subject: "New property matching your criteria: {{ property_title }}",
        body_html: <<~HTML
          <h2>New Property Alert</h2>
          <p>Dear {{ subscriber_name }},</p>
          <p>A new property matching your search criteria has been listed:</p>
          <h3>{{ property_title }}</h3>
          <p><strong>Price:</strong> {{ property_price }}</p>
          <p><a href="{{ property_url }}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Property</a></p>
          <p>Best regards,<br>
          {{ website_name }}</p>
        HTML
      },
      "alert.price_change" => {
        subject: "Price reduced: {{ property_title }}",
        body_html: <<~HTML
          <h2>Price Change Alert</h2>
          <p>Dear {{ subscriber_name }},</p>
          <p>Good news! The price has changed for a property you're watching:</p>
          <h3>{{ property_title }}</h3>
          <p><strong>Old Price:</strong> <s>{{ old_price }}</s><br>
          <strong>New Price:</strong> {{ new_price }}</p>
          <p><a href="{{ property_url }}" style="background-color: #28a745; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Property</a></p>
          <p>Best regards,<br>
          {{ website_name }}</p>
        HTML
      },
      "user.welcome" => {
        subject: "Welcome to {{ website_name }}",
        body_html: <<~HTML
          <h2>Welcome!</h2>
          <p>Dear {{ user_name }},</p>
          <p>Welcome to {{ website_name }}! Your account has been successfully created.</p>
          <p>You can now:</p>
          <ul>
            <li>Save your favorite properties</li>
            <li>Set up property alerts</li>
            <li>Track your enquiries</li>
          </ul>
          <p>Best regards,<br>
          The {{ website_name }} Team</p>
        HTML
      },
      "user.password_reset" => {
        subject: "Reset your password for {{ website_name }}",
        body_html: <<~HTML
          <h2>Password Reset Request</h2>
          <p>Dear {{ user_name }},</p>
          <p>We received a request to reset your password. Click the button below to create a new password:</p>
          <p><a href="{{ reset_url }}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Reset Password</a></p>
          <p>If you didn't request this, you can safely ignore this email.</p>
          <p>Best regards,<br>
          The {{ website_name }} Team</p>
        HTML
      }
    }.freeze

    def initialize(website:, template_key:)
      @website = website
      @template_key = template_key
    end

    # Render the email with the given variables
    # Returns a hash with :subject, :body_html, and :body_text
    def render(variables = {})
      template = find_template
      variables_with_defaults = add_default_variables(variables)

      if template
        {
          subject: template.render_subject(variables_with_defaults),
          body_html: template.render_body_html(variables_with_defaults),
          body_text: template.render_body_text(variables_with_defaults)
        }
      else
        render_default_template(variables_with_defaults)
      end
    end

    # Check if a custom template exists for this website
    def custom_template_exists?
      find_template.present?
    end

    # Get the custom template if it exists
    def find_template
      @template ||= EmailTemplate.find_for_website(website, template_key)
    end

    # Get the default template content for creating customized versions
    def default_template_content
      default = DEFAULT_TEMPLATES[template_key]
      return nil unless default

      {
        template_key: template_key,
        name: EmailTemplate::TEMPLATE_KEYS[template_key],
        subject: default[:subject],
        body_html: default[:body_html],
        body_text: html_to_text(default[:body_html])
      }
    end

    private

    def render_default_template(variables)
      default = DEFAULT_TEMPLATES[template_key]
      return nil unless default

      {
        subject: render_liquid(default[:subject], variables),
        body_html: render_liquid(default[:body_html], variables),
        body_text: html_to_text(render_liquid(default[:body_html], variables))
      }
    end

    def add_default_variables(variables)
      defaults = {
        "website_name" => website&.company_display_name || "Our Website"
      }
      defaults.merge(variables.stringify_keys)
    end

    def render_liquid(template_string, variables)
      template = Liquid::Template.parse(template_string)
      template.render(variables)
    rescue Liquid::SyntaxError => e
      Rails.logger.error("Liquid template syntax error: #{e.message}")
      template_string
    end

    def html_to_text(html)
      # Simple HTML to text conversion
      text = html.dup
      text.gsub!(/<br\s*\/?>/i, "\n")
      text.gsub!(/<\/p>/i, "\n\n")
      text.gsub!(/<\/h[1-6]>/i, "\n\n")
      text.gsub!(/<li>/i, "• ")
      text.gsub!(/<\/li>/i, "\n")
      text.gsub!(/<a[^>]*href=["']([^"']*)["'][^>]*>([^<]*)<\/a>/i, '\2 (\1)')
      text.gsub!(/<[^>]*>/, "")
      text.gsub!(/&nbsp;/, " ")
      text.gsub!(/&amp;/, "&")
      text.gsub!(/&lt;/, "<")
      text.gsub!(/&gt;/, ">")
      text.gsub!(/\n{3,}/, "\n\n")
      text.strip
    end
  end
end
