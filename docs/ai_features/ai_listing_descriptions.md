# AI Listing Descriptions

## Overview

Auto-generate compelling property descriptions from property attributes using AI models (Claude, GPT, etc.). This feature integrates with the existing property creation flow in site_admin and leverages PWB's multi-language infrastructure.

## Value Proposition

- **Time Savings**: Generate professional descriptions in seconds instead of 15-30 minutes
- **Consistency**: Maintain brand voice across all listings
- **Multi-language**: Generate descriptions in multiple languages simultaneously
- **Compliance**: Built-in Fair Housing compliance scanning
- **SEO Optimization**: Generate SEO-friendly titles and meta descriptions

## Data Model

### New Tables

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_ai_generation_requests.rb
class CreateAiGenerationRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_ai_generation_requests do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :user, foreign_key: { to_table: :pwb_users }
      t.references :generatable, polymorphic: true  # SaleListing, RentalListing, etc.

      t.string :request_type, null: false  # 'listing_description', 'social_post', 'market_report'
      t.string :ai_provider, null: false   # 'anthropic', 'openai', 'google'
      t.string :ai_model, null: false      # 'claude-sonnet-4-20250514', 'gpt-4o', etc.
      t.string :locale, null: false, default: 'en'

      t.jsonb :input_data, null: false, default: {}    # Property attributes sent to AI
      t.jsonb :output_data, default: {}                # Generated content
      t.jsonb :options, default: {}                    # tone, style, word_count, etc.

      t.string :status, null: false, default: 'pending'  # pending, processing, completed, failed
      t.text :error_message

      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :cost_cents, precision: 10, scale: 4

      t.timestamps
    end

    add_index :pwb_ai_generation_requests, [:website_id, :request_type]
    add_index :pwb_ai_generation_requests, [:generatable_type, :generatable_id]
    add_index :pwb_ai_generation_requests, :status
  end
end
```

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_ai_writing_rules.rb
class CreateAiWritingRules < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_ai_writing_rules do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      t.string :name, null: false
      t.text :description
      t.text :rules_prompt, null: false  # Custom instructions for AI
      t.string :tone, default: 'professional'  # professional, casual, luxury, etc.
      t.string :rule_type, default: 'listing'  # listing, social, general

      t.boolean :active, default: true
      t.boolean :is_default, default: false

      t.timestamps
    end

    add_index :pwb_ai_writing_rules, [:website_id, :rule_type]
    add_index :pwb_ai_writing_rules, [:website_id, :is_default]
  end
end
```

### Model Definitions

```ruby
# app/models/pwb/ai_generation_request.rb
module Pwb
  class AiGenerationRequest < ApplicationRecord
    belongs_to :website
    belongs_to :user, optional: true
    belongs_to :generatable, polymorphic: true, optional: true

    enum :status, {
      pending: 'pending',
      processing: 'processing',
      completed: 'completed',
      failed: 'failed'
    }

    enum :request_type, {
      listing_description: 'listing_description',
      listing_title: 'listing_title',
      seo_metadata: 'seo_metadata',
      social_post: 'social_post',
      market_report: 'market_report'
    }

    validates :request_type, :ai_provider, :ai_model, :locale, presence: true
    validates :input_data, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :for_listing, ->(listing) { where(generatable: listing) }
  end
end
```

```ruby
# app/models/pwb/ai_writing_rule.rb
module Pwb
  class AiWritingRule < ApplicationRecord
    belongs_to :website

    validates :name, :rules_prompt, presence: true
    validates :name, uniqueness: { scope: :website_id }

    scope :active, -> { where(active: true) }
    scope :for_listings, -> { where(rule_type: 'listing') }
    scope :default_rule, -> { where(is_default: true) }

    TONE_OPTIONS = %w[professional casual luxury friendly informative persuasive].freeze

    validates :tone, inclusion: { in: TONE_OPTIONS }
  end
end
```

## Service Layer

### AI Provider Abstraction

```ruby
# app/services/ai/base_provider.rb
module Ai
  class BaseProvider
    attr_reader :model, :options

    def initialize(model:, options: {})
      @model = model
      @options = options
    end

    def generate(prompt:, system_prompt: nil)
      raise NotImplementedError
    end

    def estimate_cost(input_tokens:, output_tokens:)
      raise NotImplementedError
    end

    protected

    def track_usage(input_tokens:, output_tokens:)
      {
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        cost_cents: estimate_cost(input_tokens: input_tokens, output_tokens: output_tokens)
      }
    end
  end
end
```

```ruby
# app/services/ai/anthropic_provider.rb
module Ai
  class AnthropicProvider < BaseProvider
    MODELS = {
      'claude-sonnet-4-20250514' => { input: 0.003, output: 0.015 },  # per 1K tokens
      'claude-haiku-3-5-20241022' => { input: 0.00025, output: 0.00125 }
    }.freeze

    def generate(prompt:, system_prompt: nil)
      client = Anthropic::Client.new

      response = client.messages.create(
        model: model,
        max_tokens: options[:max_tokens] || 1024,
        system: system_prompt,
        messages: [{ role: 'user', content: prompt }]
      )

      {
        content: response.content.first.text,
        usage: track_usage(
          input_tokens: response.usage.input_tokens,
          output_tokens: response.usage.output_tokens
        )
      }
    end

    def estimate_cost(input_tokens:, output_tokens:)
      pricing = MODELS[model] || MODELS.values.first
      ((input_tokens * pricing[:input]) + (output_tokens * pricing[:output])) / 10.0
    end
  end
end
```

### Listing Description Generator

```ruby
# app/services/ai/listing_description_generator.rb
module Ai
  class ListingDescriptionGenerator
    attr_reader :listing, :locale, :options

    def initialize(listing:, locale: 'en', options: {})
      @listing = listing
      @locale = locale
      @options = options.with_defaults(
        tone: 'professional',
        word_count: 150,
        include_cta: true,
        highlight_features: true
      )
    end

    def generate
      request = create_request

      begin
        request.processing!

        result = provider.generate(
          prompt: build_prompt,
          system_prompt: system_prompt
        )

        processed = post_process(result[:content])

        request.update!(
          status: :completed,
          output_data: {
            description: processed[:description],
            compliance_warnings: processed[:warnings]
          },
          input_tokens: result[:usage][:input_tokens],
          output_tokens: result[:usage][:output_tokens],
          cost_cents: result[:usage][:cost_cents]
        )

        request
      rescue StandardError => e
        request.update!(status: :failed, error_message: e.message)
        raise
      end
    end

    private

    def provider
      @provider ||= Ai::AnthropicProvider.new(
        model: options[:model] || 'claude-sonnet-4-20250514',
        options: { max_tokens: 1024 }
      )
    end

    def create_request
      Pwb::AiGenerationRequest.create!(
        website: listing.website,
        user: options[:user],
        generatable: listing,
        request_type: :listing_description,
        ai_provider: 'anthropic',
        ai_model: options[:model] || 'claude-sonnet-4-20250514',
        locale: locale,
        input_data: property_attributes,
        options: options.except(:user, :model)
      )
    end

    def property_attributes
      asset = listing.realty_asset

      {
        property_type: asset.prop_type_key,
        bedrooms: asset.count_bedrooms,
        bathrooms: asset.count_bathrooms,
        toilets: asset.count_toilets,
        garages: asset.count_garages,
        constructed_area_sqm: asset.constructed_area,
        plot_area_sqm: asset.plot_area,
        year_built: asset.year_construction,
        energy_rating: asset.energy_rating,

        location: {
          city: asset.city,
          region: asset.region,
          neighborhood: asset.street_name,
          country: asset.country
        },

        listing_type: listing.class.name.demodulize.underscore,
        price: format_price(listing),

        features: asset.features.pluck(:feature_key),

        # Existing content for context
        existing_title: listing.title,
        existing_description: listing.description
      }.compact
    end

    def format_price(listing)
      if listing.is_a?(Pwb::SaleListing)
        Money.new(listing.price_sale_current_cents, listing.price_sale_current_currency).format
      else
        "#{Money.new(listing.price_rental_monthly_current_cents, listing.price_rental_monthly_current_currency).format}/month"
      end
    end

    def build_prompt
      <<~PROMPT
        Generate a compelling property listing description based on the following details:

        ## Property Details
        #{property_attributes.to_yaml}

        ## Requirements
        - Write approximately #{options[:word_count]} words
        - Tone: #{options[:tone]}
        - Language: #{locale_name}
        - #{options[:include_cta] ? 'Include a call-to-action at the end' : 'No call-to-action needed'}
        - #{options[:highlight_features] ? 'Highlight key features prominently' : 'Keep features subtle'}

        #{custom_rules_section}

        Write ONLY the description text, no headers or labels.
      PROMPT
    end

    def system_prompt
      <<~SYSTEM
        You are an expert real estate copywriter. You write compelling, accurate property descriptions that:
        - Highlight the property's best features
        - Use vivid but truthful language
        - Follow Fair Housing guidelines (never mention protected classes, neighborhoods in discriminatory context, etc.)
        - Are optimized for search engines without keyword stuffing
        - Create emotional connection with potential buyers/renters

        IMPORTANT: Never use discriminatory language or imply preferences for certain types of people.
        Avoid: "perfect for families", "ideal for young professionals", "quiet neighborhood" (can imply discrimination)
        Instead: "spacious layout", "convenient location", "peaceful setting"
      SYSTEM
    end

    def custom_rules_section
      rule = listing.website.ai_writing_rules.for_listings.default_rule.first
      return '' unless rule

      <<~RULES
        ## Brand Guidelines
        #{rule.rules_prompt}
      RULES
    end

    def locale_name
      { 'en' => 'English', 'es' => 'Spanish', 'fr' => 'French', 'de' => 'German' }[locale] || locale
    end

    def post_process(content)
      warnings = FairHousingComplianceChecker.scan(content)

      {
        description: content.strip,
        warnings: warnings
      }
    end
  end
end
```

### Fair Housing Compliance Checker

```ruby
# app/services/ai/fair_housing_compliance_checker.rb
module Ai
  class FairHousingComplianceChecker
    # Protected classes under Fair Housing Act
    VIOLATION_PATTERNS = {
      familial_status: [
        /perfect for (families|couples|singles)/i,
        /ideal for (young|retired|elderly)/i,
        /no (kids|children|pets)/i,
        /adult (community|only|living)/i
      ],
      race_ethnicity: [
        /ethnic neighborhood/i,
        /diverse area/i,
        /integrated community/i
      ],
      religion: [
        /near (church|mosque|synagogue|temple)/i,
        /christian|muslim|jewish|hindu community/i
      ],
      disability: [
        /must be able to/i,
        /no wheelchairs/i,
        /able-bodied/i
      ],
      national_origin: [
        /english speakers only/i,
        /american neighborhood/i
      ]
    }.freeze

    SUGGESTIONS = {
      'perfect for families' => 'spacious layout with multiple bedrooms',
      'ideal for young professionals' => 'convenient urban location',
      'quiet neighborhood' => 'peaceful residential setting',
      'near church' => 'near local amenities',
      'adult community' => 'age-qualified community (55+)' # This is legal
    }.freeze

    def self.scan(text)
      warnings = []

      VIOLATION_PATTERNS.each do |category, patterns|
        patterns.each do |pattern|
          if text.match?(pattern)
            match = text.match(pattern)[0]
            warnings << {
              category: category,
              matched_text: match,
              suggestion: SUGGESTIONS[match.downcase] || "Consider rephrasing '#{match}'",
              severity: :warning
            }
          end
        end
      end

      warnings
    end
  end
end
```

## API Endpoints

### Generate Description Endpoint

```ruby
# config/routes.rb (add to api_manage namespace)
namespace :api_manage do
  namespace :v1 do
    scope "/:locale" do
      # ... existing routes ...

      # AI Generation endpoints
      namespace :ai do
        resources :listing_descriptions, only: [:create, :show] do
          collection do
            post :preview  # Generate without saving to listing
          end
        end
        resources :writing_rules, only: [:index, :create, :update, :destroy]
      end
    end
  end
end
```

```ruby
# app/controllers/api_manage/v1/ai/listing_descriptions_controller.rb
module ApiManage
  module V1
    module Ai
      class ListingDescriptionsController < BaseController
        before_action :find_listing, only: [:create]

        # POST /api_manage/v1/:locale/ai/listing_descriptions
        # Generate and optionally save description to listing
        def create
          generator = ::Ai::ListingDescriptionGenerator.new(
            listing: @listing,
            locale: params[:locale],
            options: generation_options
          )

          request = generator.generate

          # Optionally apply to listing
          if params[:apply] && request.completed?
            apply_to_listing(request)
          end

          render json: {
            success: true,
            request_id: request.id,
            description: request.output_data['description'],
            compliance_warnings: request.output_data['compliance_warnings'],
            usage: {
              input_tokens: request.input_tokens,
              output_tokens: request.output_tokens,
              cost_cents: request.cost_cents
            }
          }, status: :created
        end

        # POST /api_manage/v1/:locale/ai/listing_descriptions/preview
        # Preview generation without a specific listing
        def preview
          # Build a temporary listing-like object from params
          generator = ::Ai::ListingDescriptionGenerator.new(
            listing: build_preview_listing,
            locale: params[:locale],
            options: generation_options.merge(preview: true)
          )

          request = generator.generate

          render json: {
            success: true,
            description: request.output_data['description'],
            compliance_warnings: request.output_data['compliance_warnings']
          }
        end

        # GET /api_manage/v1/:locale/ai/listing_descriptions/:id
        def show
          request = current_website.ai_generation_requests
                                   .listing_description
                                   .find(params[:id])

          render json: {
            id: request.id,
            status: request.status,
            description: request.output_data['description'],
            compliance_warnings: request.output_data['compliance_warnings'],
            created_at: request.created_at.iso8601
          }
        end

        private

        def find_listing
          listing_type = params[:listing_type] || 'sale'

          @listing = if listing_type == 'sale'
            Pwb::SaleListing.joins(:realty_asset)
                           .where(pwb_realty_assets: { website_id: current_website.id })
                           .find(params[:listing_id])
          else
            Pwb::RentalListing.joins(:realty_asset)
                             .where(pwb_realty_assets: { website_id: current_website.id })
                             .find(params[:listing_id])
          end
        end

        def generation_options
          {
            user: current_user,
            tone: params[:tone] || 'professional',
            word_count: (params[:word_count] || 150).to_i,
            include_cta: params[:include_cta] != 'false',
            highlight_features: params[:highlight_features] != 'false',
            model: params[:model]
          }
        end

        def apply_to_listing(request)
          description = request.output_data['description']

          I18n.with_locale(params[:locale]) do
            @listing.update!(description: description)
          end
        end

        def build_preview_listing
          # Create an in-memory listing object for preview
          OpenStruct.new(
            website: current_website,
            realty_asset: build_preview_asset,
            class: OpenStruct.new(name: 'Pwb::SaleListing'),
            price_sale_current_cents: params.dig(:property, :price_cents),
            price_sale_current_currency: params.dig(:property, :currency) || 'USD'
          )
        end

        def build_preview_asset
          property = params[:property] || {}

          OpenStruct.new(
            prop_type_key: property[:property_type],
            count_bedrooms: property[:bedrooms],
            count_bathrooms: property[:bathrooms],
            count_toilets: property[:toilets],
            count_garages: property[:garages],
            constructed_area: property[:constructed_area],
            plot_area: property[:plot_area],
            year_construction: property[:year_built],
            city: property[:city],
            region: property[:region],
            country: property[:country],
            features: OpenStruct.new(pluck: ->(key) { property[:features] || [] })
          )
        end
      end
    end
  end
end
```

## Site Admin Integration

### UI Components

```erb
<%# app/views/site_admin/props/_ai_description_generator.html.erb %>
<div class="ai-description-generator"
     data-controller="ai-description"
     data-ai-description-listing-id-value="<%= listing.id %>"
     data-ai-description-listing-type-value="<%= listing.class.name.demodulize.underscore %>"
     data-ai-description-locale-value="<%= I18n.locale %>">

  <div class="flex items-center justify-between mb-4">
    <h4 class="text-sm font-medium text-gray-700">AI Description Generator</h4>
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
      Beta
    </span>
  </div>

  <div class="space-y-4">
    <!-- Options -->
    <div class="grid grid-cols-2 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700">Tone</label>
        <select data-ai-description-target="tone" class="mt-1 input-field">
          <option value="professional">Professional</option>
          <option value="casual">Casual</option>
          <option value="luxury">Luxury</option>
          <option value="friendly">Friendly</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Word Count</label>
        <select data-ai-description-target="wordCount" class="mt-1 input-field">
          <option value="100">Short (~100 words)</option>
          <option value="150" selected>Medium (~150 words)</option>
          <option value="250">Long (~250 words)</option>
        </select>
      </div>
    </div>

    <!-- Generate Button -->
    <button type="button"
            data-action="click->ai-description#generate"
            data-ai-description-target="generateBtn"
            class="btn btn-secondary w-full">
      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"/>
      </svg>
      Generate with AI
    </button>

    <!-- Loading State -->
    <div data-ai-description-target="loading" class="hidden">
      <div class="flex items-center justify-center py-4">
        <svg class="animate-spin h-5 w-5 text-purple-600" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
        </svg>
        <span class="ml-2 text-sm text-gray-600">Generating description...</span>
      </div>
    </div>

    <!-- Preview -->
    <div data-ai-description-target="preview" class="hidden">
      <div class="bg-gray-50 rounded-lg p-4">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-medium text-gray-700">Generated Description</span>
          <div class="space-x-2">
            <button type="button"
                    data-action="click->ai-description#regenerate"
                    class="text-sm text-purple-600 hover:text-purple-800">
              Regenerate
            </button>
            <button type="button"
                    data-action="click->ai-description#apply"
                    class="text-sm text-green-600 hover:text-green-800 font-medium">
              Use This
            </button>
          </div>
        </div>
        <p data-ai-description-target="generatedText" class="text-sm text-gray-600"></p>
      </div>

      <!-- Compliance Warnings -->
      <div data-ai-description-target="warnings" class="hidden mt-3">
        <div class="bg-yellow-50 border-l-4 border-yellow-400 p-3">
          <div class="flex">
            <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
            </svg>
            <div class="ml-3">
              <p class="text-sm text-yellow-700 font-medium">Fair Housing Compliance Notice</p>
              <ul data-ai-description-target="warningsList" class="mt-1 text-sm text-yellow-600 list-disc list-inside">
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

### Stimulus Controller

```javascript
// app/javascript/controllers/ai_description_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tone", "wordCount", "generateBtn", "loading",
    "preview", "generatedText", "warnings", "warningsList"
  ]

  static values = {
    listingId: Number,
    listingType: String,
    locale: String
  }

  async generate() {
    this.showLoading()

    try {
      const response = await fetch(`/api_manage/v1/${this.localeValue}/ai/listing_descriptions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          listing_id: this.listingIdValue,
          listing_type: this.listingTypeValue,
          tone: this.toneTarget.value,
          word_count: this.wordCountTarget.value
        })
      })

      const data = await response.json()

      if (data.success) {
        this.showPreview(data.description, data.compliance_warnings)
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError('Failed to generate description. Please try again.')
    }
  }

  async apply() {
    const description = this.generatedTextTarget.textContent

    // Find the description textarea and update it
    const descriptionField = document.querySelector(`[name*="[description]"]`)
    if (descriptionField) {
      descriptionField.value = description
      descriptionField.dispatchEvent(new Event('change', { bubbles: true }))
    }

    this.hidePreview()

    // Show success toast
    this.showToast('Description applied successfully')
  }

  regenerate() {
    this.generate()
  }

  showLoading() {
    this.generateBtnTarget.disabled = true
    this.loadingTarget.classList.remove('hidden')
    this.previewTarget.classList.add('hidden')
  }

  showPreview(description, warnings) {
    this.loadingTarget.classList.add('hidden')
    this.generateBtnTarget.disabled = false
    this.previewTarget.classList.remove('hidden')
    this.generatedTextTarget.textContent = description

    if (warnings && warnings.length > 0) {
      this.warningsTarget.classList.remove('hidden')
      this.warningsListTarget.innerHTML = warnings
        .map(w => `<li>${w.matched_text}: ${w.suggestion}</li>`)
        .join('')
    } else {
      this.warningsTarget.classList.add('hidden')
    }
  }

  hidePreview() {
    this.previewTarget.classList.add('hidden')
  }

  showError(message) {
    this.loadingTarget.classList.add('hidden')
    this.generateBtnTarget.disabled = false
    alert(message) // TODO: Replace with toast notification
  }

  showToast(message) {
    // Implement toast notification
    console.log(message)
  }
}
```

## Multi-Language Support

### Batch Generation

```ruby
# app/services/ai/batch_description_generator.rb
module Ai
  class BatchDescriptionGenerator
    attr_reader :listing, :locales, :options

    def initialize(listing:, locales:, options: {})
      @listing = listing
      @locales = locales
      @options = options
    end

    def generate_all
      results = {}

      locales.each do |locale|
        generator = ListingDescriptionGenerator.new(
          listing: listing,
          locale: locale,
          options: options
        )

        results[locale] = generator.generate
      end

      results
    end

    # Async version using ActiveJob
    def generate_all_async
      locales.each do |locale|
        GenerateListingDescriptionJob.perform_later(
          listing_id: listing.id,
          listing_type: listing.class.name,
          locale: locale,
          options: options
        )
      end
    end
  end
end
```

```ruby
# app/jobs/generate_listing_description_job.rb
class GenerateListingDescriptionJob < ApplicationJob
  queue_as :ai_generation

  def perform(listing_id:, listing_type:, locale:, options: {})
    listing = listing_type.constantize.find(listing_id)

    generator = Ai::ListingDescriptionGenerator.new(
      listing: listing,
      locale: locale,
      options: options.symbolize_keys
    )

    request = generator.generate

    # Broadcast completion via ActionCable
    AiGenerationChannel.broadcast_to(
      listing,
      type: 'description_completed',
      locale: locale,
      request_id: request.id,
      description: request.output_data['description']
    )
  end
end
```

## Usage Tracking & Limits

### Subscription-Based Limits

```ruby
# app/models/concerns/ai_usage_limits.rb
module AiUsageLimits
  extend ActiveSupport::Concern

  included do
    def ai_generations_this_month
      ai_generation_requests
        .where('created_at >= ?', Time.current.beginning_of_month)
        .count
    end

    def ai_generation_limit
      case subscription&.plan&.key
      when 'free' then 5
      when 'starter' then 50
      when 'professional' then 500
      when 'enterprise' then Float::INFINITY
      else 5
      end
    end

    def can_generate_ai_content?
      ai_generations_this_month < ai_generation_limit
    end

    def ai_generations_remaining
      [ai_generation_limit - ai_generations_this_month, 0].max
    end
  end
end

# Add to Website model
class Pwb::Website < ApplicationRecord
  include AiUsageLimits
end
```

## Configuration

### Environment Variables

```ruby
# config/initializers/ai_config.rb
Rails.application.configure do
  config.ai = ActiveSupport::OrderedOptions.new

  # Provider API keys
  config.ai.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.ai.openai_api_key = ENV['OPENAI_API_KEY']

  # Default settings
  config.ai.default_provider = ENV.fetch('AI_DEFAULT_PROVIDER', 'anthropic')
  config.ai.default_model = ENV.fetch('AI_DEFAULT_MODEL', 'claude-sonnet-4-20250514')

  # Rate limiting
  config.ai.max_requests_per_minute = ENV.fetch('AI_RATE_LIMIT', 10).to_i

  # Feature flags
  config.ai.enabled = ENV.fetch('AI_FEATURES_ENABLED', 'true') == 'true'
  config.ai.compliance_check_enabled = ENV.fetch('AI_COMPLIANCE_CHECK', 'true') == 'true'
end
```

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1-2)
- [ ] Create database migrations
- [ ] Implement AI provider abstraction
- [ ] Build Anthropic provider integration
- [ ] Create ListingDescriptionGenerator service
- [ ] Implement Fair Housing compliance checker
- [ ] Add API endpoints

### Phase 2: Site Admin Integration (Week 3)
- [ ] Create AI description generator UI component
- [ ] Build Stimulus controller
- [ ] Integrate with property text editing tab
- [ ] Add usage tracking display

### Phase 3: Multi-Language & Polish (Week 4)
- [ ] Implement batch generation for multiple locales
- [ ] Add async generation with ActionCable updates
- [ ] Create writing rules management UI
- [ ] Add subscription-based usage limits

### Phase 4: Advanced Features (Future)
- [ ] OpenAI provider integration
- [ ] A/B testing for generated descriptions
- [ ] SEO title and meta description generation
- [ ] Bulk generation for all listings
