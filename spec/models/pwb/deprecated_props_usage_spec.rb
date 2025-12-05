# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Deprecated props association usage", type: :model do
  describe "Code scanning for .props usage" do
    # List of files that are known to use .props for write operations (legacy APIs)
    # These are excluded from the scan as they require more complex migration
    EXCLUDED_FILES = [
      'app/controllers/pwb/api/v1/properties_controller.rb',
      'app/controllers/pwb/api_ext/v1/props_controller.rb',
      'lib/pwb/seed_runner.rb'
    ].freeze

    # Files that should use listed_properties for read operations
    READ_OPERATION_CONTROLLERS = [
      'app/controllers/pwb/welcome_controller.rb',
      'app/controllers/pwb/search_controller.rb',
      'app/controllers/pwb/props_controller.rb',
      'app/controllers/pwb/export/properties_controller.rb',
      'app/controllers/api_public/v1/properties_controller.rb',
      'app/graphql/mutations/submit_listing_enquiry.rb'
    ].freeze

    it "controllers do not use deprecated .props for read operations" do
      violations = []

      READ_OPERATION_CONTROLLERS.each do |relative_path|
        file_path = Rails.root.join(relative_path)
        next unless File.exist?(file_path)

        content = File.read(file_path)

        # Check for .props usage (but not in comments)
        content.each_line.with_index(1) do |line, line_number|
          # Skip comment lines
          next if line.strip.start_with?('#')

          # Check for patterns like website.props, current_website.props, @current_website.props
          if line.match?(/\.(props)\b(?!_)/) && !line.include?('listed_properties')
            violations << "#{relative_path}:#{line_number}: #{line.strip}"
          end
        end
      end

      if violations.any?
        fail "Found deprecated .props usage in controllers (should use .listed_properties):\n#{violations.join("\n")}"
      end
    end

    it "scans all controllers and views for unexpected .props usage" do
      # Scan patterns that indicate read operations using deprecated .props
      patterns_to_check = [
        'app/controllers/**/*.rb',
        'app/views/**/*.erb',
        'app/graphql/**/*.rb'
      ]

      violations = []

      patterns_to_check.each do |pattern|
        Dir.glob(Rails.root.join(pattern)).each do |file_path|
          relative_path = file_path.sub("#{Rails.root}/", '')

          # Skip excluded files (known legacy write APIs)
          next if EXCLUDED_FILES.any? { |excluded| relative_path.include?(excluded) }

          content = File.read(file_path)

          content.each_line.with_index(1) do |line, line_number|
            # Skip comment lines
            next if line.strip.start_with?('#')
            next if line.strip.start_with?('<%#')

            # Check for patterns that suggest using .props for querying properties
            # These patterns are commonly used for read operations
            read_patterns = [
              /\.props\.for_sale/,
              /\.props\.for_rent/,
              /\.props\.visible/,
              /\.props\.find\b/,
              /\.props\.where\b/,
              /\.props\.properties_search/,
              /\.props\.includes/,
              /\.props\.order/,
              /\.props\.limit/
            ]

            read_patterns.each do |pattern|
              if line.match?(pattern)
                violations << "#{relative_path}:#{line_number}: #{line.strip}"
                break
              end
            end
          end
        end
      end

      if violations.any?
        fail "Found deprecated .props usage for read operations (should use .listed_properties):\n#{violations.join("\n")}"
      end
    end
  end

  describe "Website association behavior" do
    let(:website) { create(:pwb_website) }

    it "has listed_properties association for read operations" do
      expect(website).to respond_to(:listed_properties)
      expect(website.listed_properties).to be_a(ActiveRecord::Relation)
    end

    it "has realty_assets association for write operations" do
      expect(website).to respond_to(:realty_assets)
      expect(website.realty_assets).to be_a(ActiveRecord::Relation)
    end

    it "listed_properties returns ListedProperty instances" do
      # ListedProperty is backed by a materialized view
      expect(website.listed_properties.klass).to eq(Pwb::ListedProperty)
    end

    it "ListedProperty is read-only" do
      property = Pwb::ListedProperty.new
      expect(property.readonly?).to be true
    end
  end

  describe "Controller property loading" do
    it "WelcomeController uses listed_properties" do
      source = File.read(Rails.root.join('app/controllers/pwb/welcome_controller.rb'))
      expect(source).to include('listed_properties')
      expect(source).not_to match(/\.props\.for_sale/)
      expect(source).not_to match(/\.props\.for_rent/)
    end

    it "SearchController uses listed_properties" do
      source = File.read(Rails.root.join('app/controllers/pwb/search_controller.rb'))
      expect(source).to include('listed_properties')
      expect(source).not_to match(/\.props\.for_sale/)
      expect(source).not_to match(/\.props\.for_rent/)
      expect(source).not_to match(/\.props\.visible/)
    end

    it "PropsController uses listed_properties" do
      source = File.read(Rails.root.join('app/controllers/pwb/props_controller.rb'))
      expect(source).to include('ListedProperty')
      expect(source).not_to match(/\.props\.find/)
      expect(source).not_to match(/Pwb::Prop\./)
    end

    it "Export::PropertiesController uses listed_properties" do
      source = File.read(Rails.root.join('app/controllers/pwb/export/properties_controller.rb'))
      expect(source).to include('listed_properties')
      expect(source).not_to match(/current_website\.props\b(?!_)/)
    end

    it "ApiPublic::V1::PropertiesController uses listed_properties" do
      source = File.read(Rails.root.join('app/controllers/api_public/v1/properties_controller.rb'))
      expect(source).to include('listed_properties')
      expect(source).not_to match(/\.props\.find/)
      expect(source).not_to match(/\.props\.properties_search/)
    end

    it "SubmitListingEnquiry mutation uses listed_properties" do
      source = File.read(Rails.root.join('app/graphql/mutations/submit_listing_enquiry.rb'))
      expect(source).to include('listed_properties')
      expect(source).not_to match(/\.props\.find/)
    end
  end
end
