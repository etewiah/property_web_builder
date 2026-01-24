# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe EmailTemplate, type: :model do
    let(:website) { create(:pwb_website) }

    describe 'associations' do
      it { is_expected.to belong_to(:website).class_name('Pwb::Website') }
    end

    describe 'validations' do
      subject { build(:pwb_email_template, website: website) }

      it { is_expected.to validate_presence_of(:template_key) }
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:subject) }
      it { is_expected.to validate_presence_of(:body_html) }
      it { is_expected.to validate_length_of(:name).is_at_most(100) }
      it { is_expected.to validate_length_of(:subject).is_at_most(200) }

      describe 'template_key inclusion' do
        it 'allows valid template keys' do
          EmailTemplate::TEMPLATE_KEYS.keys.each do |key|
            template = build(:pwb_email_template, website: website, template_key: key)
            expect(template).to be_valid
          end
        end

        it 'rejects invalid template keys' do
          template = build(:pwb_email_template, website: website, template_key: 'invalid.key')
          expect(template).not_to be_valid
          expect(template.errors[:template_key]).to include(match(/not a valid template type/))
        end
      end

      describe 'template_key uniqueness scoped to website' do
        let!(:existing_template) { create(:pwb_email_template, website: website, template_key: 'enquiry.general') }

        it 'does not allow duplicate template_key for same website' do
          duplicate = build(:pwb_email_template, website: website, template_key: 'enquiry.general')
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:template_key]).to include(match(/already exists/))
        end

        it 'allows same template_key for different website' do
          other_website = create(:pwb_website)
          template = build(:pwb_email_template, website: other_website, template_key: 'enquiry.general')
          expect(template).to be_valid
        end
      end
    end

    describe 'scopes' do
      let!(:active_template) { create(:pwb_email_template, website: website, active: true) }
      let!(:inactive_template) { create(:pwb_email_template, :property_enquiry, website: website, active: false) }

      describe '.active' do
        it 'returns only active templates' do
          expect(EmailTemplate.active).to include(active_template)
          expect(EmailTemplate.active).not_to include(inactive_template)
        end
      end

      describe '.by_key' do
        it 'returns templates with specified key' do
          expect(EmailTemplate.by_key('enquiry.general')).to include(active_template)
          expect(EmailTemplate.by_key('enquiry.property')).to include(inactive_template)
        end
      end
    end

    describe '.find_for_website' do
      let!(:template) { create(:pwb_email_template, website: website, template_key: 'enquiry.general', active: true) }

      it 'finds active template for website and key' do
        result = EmailTemplate.find_for_website(website, 'enquiry.general')
        expect(result).to eq(template)
      end

      it 'returns nil for inactive template' do
        template.update!(active: false)
        result = EmailTemplate.find_for_website(website, 'enquiry.general')
        expect(result).to be_nil
      end

      it 'returns nil when no template exists' do
        result = EmailTemplate.find_for_website(website, 'enquiry.property')
        expect(result).to be_nil
      end

      it 'does not return templates from other websites' do
        other_website = create(:pwb_website)
        result = EmailTemplate.find_for_website(other_website, 'enquiry.general')
        expect(result).to be_nil
      end
    end

    describe '#render_subject' do
      let(:template) do
        create(:pwb_email_template,
          website: website,
          subject: 'Hello {{ visitor_name }}!'
        )
      end

      it 'renders Liquid variables in subject' do
        result = template.render_subject('visitor_name' => 'John')
        expect(result).to eq('Hello John!')
      end

      it 'handles symbol keys' do
        result = template.render_subject(visitor_name: 'Jane')
        expect(result).to eq('Hello Jane!')
      end

      it 'handles missing variables gracefully' do
        result = template.render_subject({})
        expect(result).to eq('Hello !')
      end
    end

    describe '#render_body_html' do
      let(:template) do
        create(:pwb_email_template,
          website: website,
          body_html: '<p>Message from {{ visitor_name }}: {{ message }}</p>'
        )
      end

      it 'renders Liquid variables in body_html' do
        result = template.render_body_html(
          'visitor_name' => 'John',
          'message' => 'Hello there'
        )
        expect(result).to eq('<p>Message from John: Hello there</p>')
      end
    end

    describe '#render_body_text' do
      let(:template) do
        create(:pwb_email_template,
          website: website,
          body_text: 'Plain text for {{ visitor_name }}'
        )
      end

      it 'renders Liquid variables in body_text' do
        result = template.render_body_text('visitor_name' => 'John')
        expect(result).to eq('Plain text for John')
      end

      it 'returns nil when body_text is blank' do
        template.update!(body_text: nil)
        result = template.render_body_text('visitor_name' => 'John')
        expect(result).to be_nil
      end
    end

    describe 'Liquid syntax error handling' do
      let(:template) do
        t = build(:pwb_email_template,
          website: website,
          subject: '{% if name %}Broken template',
          body_html: '<p>Valid body</p>'
        )
        t.save(validate: false)
        t
      end

      it 'returns original string on syntax error and logs error' do
        expect(Rails.logger).to receive(:error).with(/Liquid template syntax error/)
        result = template.render_subject('name' => 'Test')
        expect(result).to eq('{% if name %}Broken template')
      end
    end

    describe '#available_variables' do
      EmailTemplate::TEMPLATE_KEYS.keys.each do |key|
        it "returns variables for #{key}" do
          template = build(:pwb_email_template, website: website, template_key: key)
          variables = template.available_variables

          expect(variables).to be_an(Array)
          expect(variables).to include('website_name')
        end
      end

      it 'returns correct variables for enquiry.general' do
        template = build(:pwb_email_template, website: website, template_key: 'enquiry.general')
        expect(template.available_variables).to include('visitor_name', 'visitor_email', 'message')
      end

      it 'returns correct variables for enquiry.property' do
        template = build(:pwb_email_template, website: website, template_key: 'enquiry.property')
        expect(template.available_variables).to include('property_title', 'property_reference', 'property_url')
      end

      it 'returns empty array for unknown template key' do
        template = build(:pwb_email_template, website: website)
        allow(template).to receive(:template_key).and_return('unknown.key')
        expect(template.available_variables).to eq([])
      end
    end

    describe '#preview_with_sample_data' do
      let(:template) do
        create(:pwb_email_template,
          website: website,
          template_key: 'enquiry.general',
          subject: 'Enquiry from {{ visitor_name }}',
          body_html: '<p>{{ visitor_name }} ({{ visitor_email }}) says: {{ message }}</p>',
          body_text: '{{ visitor_name }} says: {{ message }}'
        )
      end

      it 'renders template with sample data' do
        preview = template.preview_with_sample_data

        expect(preview[:subject]).to include('John Smith')
        expect(preview[:body_html]).to include('John Smith')
        expect(preview[:body_html]).to include('john@example.com')
        expect(preview[:body_text]).to include('John Smith')
      end

      it 'uses website company_display_name for website_name' do
        website.update!(company_display_name: 'Preview Company')
        template.update!(body_html: '<p>{{ website_name }}</p>')

        preview = template.preview_with_sample_data

        expect(preview[:body_html]).to include('Preview Company')
      end
    end

    describe 'TEMPLATE_KEYS constant' do
      it 'contains all expected template types' do
        expected_keys = %w[
          enquiry.general
          enquiry.property
          enquiry.auto_reply
          alert.new_property
          alert.price_change
          user.welcome
          user.password_reset
        ]

        expect(EmailTemplate::TEMPLATE_KEYS.keys).to match_array(expected_keys)
      end

      it 'has human-readable names for all keys' do
        EmailTemplate::TEMPLATE_KEYS.each do |key, name|
          expect(name).to be_a(String)
          expect(name).not_to be_empty
        end
      end
    end

    describe 'TEMPLATE_VARIABLES constant' do
      it 'has variables defined for all template keys' do
        EmailTemplate::TEMPLATE_KEYS.keys.each do |key|
          expect(EmailTemplate::TEMPLATE_VARIABLES).to have_key(key)
          expect(EmailTemplate::TEMPLATE_VARIABLES[key]).to be_an(Array)
        end
      end
    end
  end
end
