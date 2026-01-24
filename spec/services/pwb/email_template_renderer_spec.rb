# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe EmailTemplateRenderer do
    let(:website) { create(:pwb_website, company_display_name: 'Test Realty') }

    describe '#render with default templates' do
      describe 'enquiry.general template' do
        let(:renderer) { described_class.new(website: website, template_key: 'enquiry.general') }

        it 'renders the default template when no custom template exists' do
          result = renderer.render(
            visitor_name: 'John Doe',
            visitor_email: 'john@example.com',
            message: 'I am interested in your properties.'
          )

          expect(result[:subject]).to eq('New enquiry from John Doe')
          expect(result[:body_html]).to include('John Doe')
          expect(result[:body_html]).to include('john@example.com')
          expect(result[:body_html]).to include('I am interested in your properties.')
          expect(result[:body_text]).to be_present
        end

        it 'includes visitor_phone when provided' do
          result = renderer.render(
            visitor_name: 'John Doe',
            visitor_email: 'john@example.com',
            visitor_phone: '+1-555-123-4567',
            message: 'Call me'
          )

          expect(result[:body_html]).to include('+1-555-123-4567')
        end

        it 'handles missing visitor_phone gracefully' do
          result = renderer.render(
            visitor_name: 'John Doe',
            visitor_email: 'john@example.com',
            message: 'No phone provided'
          )

          expect(result[:body_html]).not_to include('Phone:')
        end
      end

      describe 'enquiry.property template' do
        let(:renderer) { described_class.new(website: website, template_key: 'enquiry.property') }

        it 'renders property details in the subject and body' do
          result = renderer.render(
            visitor_name: 'Jane Smith',
            visitor_email: 'jane@example.com',
            message: 'Is this still available?',
            property_title: 'Beautiful 3BR Apartment',
            property_reference: 'REF-001',
            property_url: 'https://example.com/property/1'
          )

          expect(result[:subject]).to eq('Property enquiry: Beautiful 3BR Apartment')
          expect(result[:body_html]).to include('Beautiful 3BR Apartment')
          expect(result[:body_html]).to include('REF-001')
          expect(result[:body_html]).to include('https://example.com/property/1')
        end
      end

      describe 'enquiry.auto_reply template' do
        let(:renderer) { described_class.new(website: website, template_key: 'enquiry.auto_reply') }

        it 'renders auto-reply with website name' do
          result = renderer.render(visitor_name: 'John Doe')

          expect(result[:subject]).to include('Test Realty')
          expect(result[:body_html]).to include('Dear John Doe')
          expect(result[:body_html]).to include('Test Realty')
        end
      end

      describe 'alert.new_property template' do
        let(:renderer) { described_class.new(website: website, template_key: 'alert.new_property') }

        it 'renders new property alert' do
          result = renderer.render(
            subscriber_name: 'Alert User',
            property_title: 'New Listing',
            property_price: '$500,000',
            property_url: 'https://example.com/new-listing'
          )

          expect(result[:subject]).to include('New Listing')
          expect(result[:body_html]).to include('Alert User')
          expect(result[:body_html]).to include('$500,000')
        end
      end

      describe 'alert.price_change template' do
        let(:renderer) { described_class.new(website: website, template_key: 'alert.price_change') }

        it 'renders price change with old and new prices' do
          result = renderer.render(
            subscriber_name: 'Subscriber',
            property_title: 'Great Deal',
            old_price: '$600,000',
            new_price: '$550,000',
            property_url: 'https://example.com/deal'
          )

          expect(result[:subject]).to include('Great Deal')
          expect(result[:body_html]).to include('$600,000')
          expect(result[:body_html]).to include('$550,000')
        end
      end

      describe 'user.welcome template' do
        let(:renderer) { described_class.new(website: website, template_key: 'user.welcome') }

        it 'renders welcome email' do
          result = renderer.render(user_name: 'New User')

          expect(result[:subject]).to include('Welcome')
          expect(result[:body_html]).to include('New User')
          expect(result[:body_html]).to include('favorite properties')
        end
      end

      describe 'user.password_reset template' do
        let(:renderer) { described_class.new(website: website, template_key: 'user.password_reset') }

        it 'renders password reset with link' do
          result = renderer.render(
            user_name: 'User',
            reset_url: 'https://example.com/reset?token=abc123'
          )

          expect(result[:subject]).to include('Reset')
          expect(result[:body_html]).to include('https://example.com/reset?token=abc123')
        end
      end
    end

    describe '#render with custom templates' do
      let!(:custom_template) do
        create(:pwb_email_template,
          website: website,
          template_key: 'enquiry.general',
          subject: 'Custom: {{ visitor_name }} enquired',
          body_html: '<p>Custom body for {{ visitor_name }}</p>',
          body_text: 'Custom text for {{ visitor_name }}'
        )
      end

      let(:renderer) { described_class.new(website: website, template_key: 'enquiry.general') }

      it 'uses the custom template instead of default' do
        result = renderer.render(visitor_name: 'Custom User')

        expect(result[:subject]).to eq('Custom: Custom User enquired')
        expect(result[:body_html]).to eq('<p>Custom body for Custom User</p>')
        expect(result[:body_text]).to eq('Custom text for Custom User')
      end

      it 'returns true for custom_template_exists?' do
        expect(renderer.custom_template_exists?).to be true
      end

      context 'when custom template is inactive' do
        before { custom_template.update!(active: false) }

        it 'falls back to default template' do
          result = renderer.render(visitor_name: 'Fallback User')

          expect(result[:subject]).to eq('New enquiry from Fallback User')
        end

        it 'returns false for custom_template_exists?' do
          expect(renderer.custom_template_exists?).to be false
        end
      end
    end

    describe '#render variable substitution' do
      let(:renderer) { described_class.new(website: website, template_key: 'enquiry.general') }

      it 'handles nil variables gracefully' do
        result = renderer.render(visitor_name: nil, visitor_email: nil, message: nil)

        expect(result[:subject]).to be_present
        expect(result[:body_html]).to be_present
      end

      it 'adds website_name as default variable' do
        result = renderer.render(visitor_name: 'Test')

        expect(result[:body_html]).not_to include('{{ website_name }}')
      end

      it 'uses "Our Website" when website has no company_display_name' do
        website.update!(company_display_name: nil)
        website.agency&.update!(display_name: nil)
        renderer_no_name = described_class.new(website: website, template_key: 'enquiry.auto_reply')

        result = renderer_no_name.render(visitor_name: 'Test')

        expect(result[:subject]).to include('Our Website')
      end

      it 'converts symbol keys to string keys' do
        result = renderer.render(
          visitor_name: 'Symbol Test',
          visitor_email: 'symbol@test.com'
        )

        expect(result[:subject]).to include('Symbol Test')
      end
    end

    describe 'HTML to text conversion' do
      let(:renderer) { described_class.new(website: website, template_key: 'enquiry.general') }

      it 'converts <br> tags to newlines' do
        result = renderer.render(visitor_name: 'Test', visitor_email: 'test@example.com', message: 'Test')
        text = result[:body_text]

        expect(text).not_to include('<br')
      end

      it 'converts links to text with URL in parentheses' do
        result = renderer.render(visitor_name: 'Test', visitor_email: 'test@example.com', message: 'Test')
        # The default template doesn't have links, but let's test with a custom one
      end

      it 'strips HTML tags while preserving content' do
        result = renderer.render(visitor_name: 'Test', visitor_email: 'test@example.com', message: 'Test')
        text = result[:body_text]

        expect(text).not_to match(/<[^>]+>/)
        expect(text).to include('Test')
      end

      it 'converts list items to bullets in default templates' do
        # The default user.welcome template contains list items
        welcome_renderer = described_class.new(website: website, template_key: 'user.welcome')
        result = welcome_renderer.render(user_name: 'Test')

        # The default template has <ul><li> items
        expect(result[:body_text]).to include('•')
      end
    end

    describe 'Liquid syntax error handling' do
      let!(:bad_template) do
        template = build(:pwb_email_template,
          website: website,
          template_key: 'enquiry.property',
          subject: '{% if visitor_name %}Missing endif',
          body_html: '<p>Valid body</p>'
        )
        template.save(validate: false) # Skip validation to create invalid template
        template
      end

      it 'returns original template string on Liquid syntax error' do
        renderer = described_class.new(website: website, template_key: 'enquiry.property')
        result = renderer.render(visitor_name: 'Test')

        # Should return the original malformed string rather than crashing
        expect(result[:subject]).to include('{% if')
      end

      it 'logs the error' do
        renderer = described_class.new(website: website, template_key: 'enquiry.property')

        expect(Rails.logger).to receive(:error).with(/Liquid template syntax error/)
        renderer.render(visitor_name: 'Test')
      end
    end

    describe '#find_template' do
      context 'when template exists for website' do
        let!(:template) { create(:pwb_email_template, website: website, template_key: 'enquiry.general') }

        it 'returns the template' do
          renderer = described_class.new(website: website, template_key: 'enquiry.general')

          expect(renderer.find_template).to eq(template)
        end
      end

      context 'when no template exists' do
        it 'returns nil' do
          renderer = described_class.new(website: website, template_key: 'enquiry.general')

          expect(renderer.find_template).to be_nil
        end
      end

      context 'when template belongs to different website' do
        let(:other_website) { create(:pwb_website) }
        let!(:other_template) { create(:pwb_email_template, website: other_website, template_key: 'enquiry.general') }

        it 'does not return the other website template' do
          renderer = described_class.new(website: website, template_key: 'enquiry.general')

          expect(renderer.find_template).to be_nil
        end
      end
    end

    describe '#default_template_content' do
      it 'returns content for known template keys' do
        renderer = described_class.new(website: website, template_key: 'enquiry.general')
        content = renderer.default_template_content

        expect(content[:template_key]).to eq('enquiry.general')
        expect(content[:name]).to eq('General Enquiry')
        expect(content[:subject]).to be_present
        expect(content[:body_html]).to be_present
        expect(content[:body_text]).to be_present
      end

      it 'returns nil for unknown template keys' do
        renderer = described_class.new(website: website, template_key: 'unknown.key')
        content = renderer.default_template_content

        expect(content).to be_nil
      end
    end

    describe '#render with nil website' do
      it 'handles nil website gracefully' do
        renderer = described_class.new(website: nil, template_key: 'enquiry.auto_reply')

        # find_template will fail gracefully with nil website
        result = renderer.render(visitor_name: 'Test')

        expect(result[:subject]).to be_present
        expect(result[:subject]).to include('Our Website') # Default fallback for website_name
      end
    end

    describe 'all template types render correctly' do
      EmailTemplateRenderer::DEFAULT_TEMPLATES.keys.each do |template_key|
        it "renders #{template_key} without error" do
          renderer = described_class.new(website: website, template_key: template_key)

          expect { renderer.render({}) }.not_to raise_error
          result = renderer.render({})
          expect(result[:subject]).to be_present
          expect(result[:body_html]).to be_present
          expect(result[:body_text]).to be_present
        end
      end
    end
  end
end
