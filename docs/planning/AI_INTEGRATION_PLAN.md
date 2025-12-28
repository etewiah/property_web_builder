# AI Integration Plan for PropertyWebBuilder

**Date**: 2025-12-27
**Recommended Gem**: [ruby_llm](https://github.com/crmne/ruby_llm)
**Status**: Planning Phase

---

## Executive Summary

This document outlines a phased approach to adding AI-powered features to PropertyWebBuilder using the ruby_llm gem. Features are prioritized by user value, implementation complexity, and cost efficiency.

---

## Recommended AI Library

### Why ruby_llm?

| Criteria | ruby_llm | Raw API Clients |
|----------|----------|-----------------|
| Multi-provider support | 500+ models (OpenAI, Claude, Gemini, etc.) | One gem per provider |
| Rails integration | Built-in `acts_as_chat` | Manual implementation |
| Streaming support | Yes | Varies |
| Multimodal (images) | Yes | Varies |
| Provider switching | One-line change | Significant refactor |
| Tool/function calling | Yes | Manual |

### Installation

```ruby
# Gemfile
gem 'ruby_llm'

# For Rails integration with chat persistence
gem 'ruby_llm-rails'
```

---

## Phase 1: Foundation (Week 1-2)

### 1.1 Core Infrastructure

**Goal**: Set up AI infrastructure without user-facing features.

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # Default to cost-effective model
  config.default_model = 'gpt-4o-mini'
end
```

**Tasks**:
- [ ] Add ruby_llm to Gemfile
- [ ] Create initializer with provider configuration
- [ ] Add API keys to credentials/environment
- [ ] Create `Pwb::AiService` base service class
- [ ] Add `ai_enabled` feature flag to Website model
- [ ] Create background job infrastructure for AI calls

### 1.2 Database Schema

```ruby
# Migration: Add AI metadata columns
class AddAiMetadataToListings < ActiveRecord::Migration[8.0]
  def change
    # Store AI-generated content and metadata
    add_column :pwb_sale_listings, :ai_metadata, :jsonb, default: {}
    add_column :pwb_rental_listings, :ai_metadata, :jsonb, default: {}
    add_column :pwb_realty_assets, :ai_metadata, :jsonb, default: {}

    # Track AI generation status
    add_column :pwb_sale_listings, :ai_description_generated_at, :datetime
    add_column :pwb_rental_listings, :ai_description_generated_at, :datetime

    # Index for querying AI status
    add_index :pwb_sale_listings, :ai_description_generated_at
    add_index :pwb_rental_listings, :ai_description_generated_at
  end
end
```

### 1.3 Base Service Class

```ruby
# app/services/pwb/ai_service.rb
module Pwb
  class AiService
    class AiDisabledError < StandardError; end
    class RateLimitError < StandardError; end

    def initialize(website)
      @website = website
      validate_ai_enabled!
    end

    protected

    def chat(prompt, model: nil, temperature: 0.7)
      RubyLLM.chat(
        model: model || default_model,
        messages: [{ role: 'user', content: prompt }],
        temperature: temperature
      )
    end

    def default_model
      @website.ai_config&.dig('model') || 'gpt-4o-mini'
    end

    private

    def validate_ai_enabled!
      unless @website.ai_enabled?
        raise AiDisabledError, "AI features not enabled for this website"
      end
    end
  end
end
```

---

## Phase 2: Property Description Generation (Week 3-4)

### 2.1 Feature Overview

**User Story**: As an agent, I want AI to generate property descriptions so I can save time and ensure consistent quality.

**Trigger Points**:
- Manual "Generate Description" button in admin
- Auto-suggest when creating new listing (optional)
- Batch generation for imported properties

### 2.2 Implementation

```ruby
# app/services/pwb/ai/description_generator.rb
module Pwb
  module Ai
    class DescriptionGenerator < AiService
      SYSTEM_PROMPT = <<~PROMPT
        You are a professional real estate copywriter. Generate compelling,
        accurate property descriptions based on the provided details.

        Guidelines:
        - Be factual and avoid exaggeration
        - Highlight key features and benefits
        - Use appropriate tone for the property type
        - Include location benefits when known
        - Aim for 150-250 words
        - Do not invent features not provided
      PROMPT

      def generate(listing)
        property = listing.realty_asset

        prompt = build_prompt(listing, property)

        response = RubyLLM.chat do |chat|
          chat.with_model(default_model)
          chat.with_temperature(0.7)
          chat.system(SYSTEM_PROMPT)
          chat.user(prompt)
        end

        {
          description: response.content,
          model_used: response.model,
          tokens_used: response.usage.total_tokens,
          generated_at: Time.current
        }
      end

      def generate_multilingual(listing, locales: [:en, :es, :fr])
        locales.each_with_object({}) do |locale, results|
          results[locale] = generate_for_locale(listing, locale)
        end
      end

      private

      def build_prompt(listing, property)
        <<~PROMPT
          Generate a property description for:

          Property Type: #{property.property_type_key}
          Transaction: #{listing.is_a?(SaleListing) ? 'For Sale' : 'For Rent'}
          Price: #{listing.formatted_price}

          Details:
          - Bedrooms: #{property.count_bedrooms || 'Not specified'}
          - Bathrooms: #{property.count_bathrooms || 'Not specified'}
          - Floor Area: #{property.floor_area_m2 ? "#{property.floor_area_m2} m²" : 'Not specified'}
          - Plot Size: #{property.plot_area_m2 ? "#{property.plot_area_m2} m²" : 'Not specified'}
          - Year Built: #{property.year_construction || 'Not specified'}

          Location:
          - City: #{property.city}
          - Region: #{property.region}
          - Country: #{property.country}

          Features:
          #{property.features.map(&:name).join(', ')}

          Additional Notes:
          #{listing.agent_notes}
        PROMPT
      end
    end
  end
end
```

### 2.3 Admin UI Integration

```erb
<!-- app/views/tenant_admin/listings/_description_generator.html.erb -->
<div class="ai-description-generator" data-controller="ai-description">
  <div class="flex items-center justify-between mb-4">
    <h3 class="text-lg font-semibold">Property Description</h3>
    <button
      type="button"
      class="btn btn-secondary"
      data-action="click->ai-description#generate"
      data-ai-description-listing-id="<%= listing.id %>"
    >
      <i class="fa fa-magic"></i>
      Generate with AI
    </button>
  </div>

  <div data-ai-description-target="loading" class="hidden">
    <div class="animate-pulse">Generating description...</div>
  </div>

  <div data-ai-description-target="preview" class="hidden">
    <div class="bg-blue-50 p-4 rounded-lg mb-4">
      <p class="text-sm text-blue-800 mb-2">AI-Generated Preview:</p>
      <div data-ai-description-target="content" class="prose"></div>
    </div>
    <div class="flex gap-2">
      <button data-action="click->ai-description#accept" class="btn btn-primary">
        Use This Description
      </button>
      <button data-action="click->ai-description#regenerate" class="btn btn-secondary">
        Try Again
      </button>
      <button data-action="click->ai-description#dismiss" class="btn btn-ghost">
        Cancel
      </button>
    </div>
  </div>

  <%= form.text_area :description,
      class: "w-full h-48",
      data: { ai_description_target: "textarea" } %>
</div>
```

### 2.4 Background Job

```ruby
# app/jobs/pwb/ai/generate_description_job.rb
module Pwb
  module Ai
    class GenerateDescriptionJob < ApplicationJob
      queue_as :ai_generation

      retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 3
      discard_on Pwb::AiService::AiDisabledError

      def perform(listing_id, listing_type:)
        listing = find_listing(listing_id, listing_type)
        return unless listing

        ActsAsTenant.with_tenant(listing.website) do
          generator = DescriptionGenerator.new(listing.website)
          result = generator.generate(listing)

          listing.update!(
            ai_metadata: listing.ai_metadata.merge(
              last_generation: result
            ),
            ai_description_generated_at: result[:generated_at]
          )

          # Broadcast update to admin UI
          Turbo::StreamsChannel.broadcast_update_to(
            "listing_#{listing_id}",
            target: "ai_description_preview",
            partial: "tenant_admin/listings/ai_preview",
            locals: { result: result }
          )
        end
      end

      private

      def find_listing(id, type)
        case type.to_s
        when 'sale' then Pwb::SaleListing.find_by(id: id)
        when 'rental' then Pwb::RentalListing.find_by(id: id)
        end
      end
    end
  end
end
```

---

## Phase 3: Image Analysis (Week 5-6)

### 3.1 Feature Overview

**User Story**: As an agent, I want AI to analyze property photos and suggest descriptions, tags, and identify room types.

**Capabilities**:
- Auto-generate alt text for accessibility
- Identify room type (kitchen, bedroom, bathroom, etc.)
- Detect key features (pool, garden, view, etc.)
- Suggest photo order based on importance
- Flag low-quality images

### 3.2 Implementation

```ruby
# app/services/pwb/ai/image_analyzer.rb
module Pwb
  module Ai
    class ImageAnalyzer < AiService
      ANALYSIS_PROMPT = <<~PROMPT
        Analyze this real estate property photo and provide:

        1. room_type: The type of room/space shown (bedroom, kitchen, bathroom,
           living_room, exterior, garden, pool, garage, balcony, view, other)
        2. description: A brief, professional description (1-2 sentences) suitable
           for alt text and photo captions
        3. features: Array of notable features visible (e.g., "hardwood floors",
           "natural light", "modern appliances", "ocean view")
        4. quality_score: 1-10 rating of photo quality for listing purposes
        5. suggested_order: 1-10 importance for listing display (1 = hero image)

        Respond in JSON format only.
      PROMPT

      def analyze(photo)
        image_url = photo.image_url(:large)

        response = RubyLLM.chat do |chat|
          chat.with_model('gpt-4o') # Vision-capable model
          chat.user do |msg|
            msg.text(ANALYSIS_PROMPT)
            msg.image(image_url)
          end
        end

        parse_analysis(response.content)
      end

      def batch_analyze(photos)
        photos.map do |photo|
          {
            photo_id: photo.id,
            analysis: analyze(photo)
          }
        rescue => e
          { photo_id: photo.id, error: e.message }
        end
      end

      private

      def parse_analysis(content)
        JSON.parse(content).symbolize_keys
      rescue JSON::ParserError
        { error: 'Failed to parse AI response', raw: content }
      end
    end
  end
end
```

### 3.3 Auto Alt-Text Generation

```ruby
# app/models/pwb/prop_photo.rb
class Pwb::PropPhoto < ApplicationRecord
  after_create_commit :generate_alt_text_async, if: :ai_enabled?

  def generate_alt_text_async
    Pwb::Ai::AnalyzePhotoJob.perform_later(id)
  end

  def ai_enabled?
    website&.ai_enabled? && website&.ai_config&.dig('auto_alt_text')
  end
end
```

---

## Phase 4: SEO Optimization (Week 7-8)

### 4.1 Feature Overview

**User Story**: As a website owner, I want AI to optimize my property listings for search engines.

**Capabilities**:
- Generate SEO-optimized titles
- Create meta descriptions
- Suggest keywords
- Analyze competitor listings (optional)

### 4.2 Implementation

```ruby
# app/services/pwb/ai/seo_optimizer.rb
module Pwb
  module Ai
    class SeoOptimizer < AiService
      def optimize_listing(listing)
        property = listing.realty_asset

        prompt = <<~PROMPT
          Optimize this property listing for search engines:

          Current Title: #{listing.title}
          Property Type: #{property.property_type_key}
          Location: #{property.city}, #{property.region}, #{property.country}
          Price: #{listing.formatted_price}
          Key Features: #{property.features.map(&:name).join(', ')}

          Provide:
          1. seo_title: Optimized title (max 60 chars)
          2. meta_description: Compelling description (max 155 chars)
          3. keywords: 5-10 relevant keywords
          4. url_slug: SEO-friendly URL slug
          5. schema_data: Key data points for rich snippets

          Respond in JSON format.
        PROMPT

        response = chat(prompt, temperature: 0.5)
        JSON.parse(response.content).symbolize_keys
      end

      def bulk_optimize(listings)
        listings.find_each do |listing|
          result = optimize_listing(listing)
          listing.update!(
            ai_metadata: listing.ai_metadata.merge(seo: result)
          )
        end
      end
    end
  end
end
```

---

## Phase 5: Smart Enquiry Processing (Week 9-10)

### 5.1 Feature Overview

**User Story**: As an agent, I want AI to analyze enquiries, categorize them, and suggest responses.

**Capabilities**:
- Categorize enquiry type (viewing request, price inquiry, general question)
- Extract key information (preferred dates, budget, requirements)
- Detect urgency level
- Suggest personalized response templates
- Flag spam/suspicious messages

### 5.2 Implementation

```ruby
# app/services/pwb/ai/enquiry_processor.rb
module Pwb
  module Ai
    class EnquiryProcessor < AiService
      CATEGORIES = %w[
        viewing_request
        price_negotiation
        property_question
        availability_check
        general_inquiry
        spam
      ].freeze

      def analyze(message)
        prompt = <<~PROMPT
          Analyze this property enquiry:

          Subject: #{message.title}
          Message: #{message.content}
          Property: #{message.realty_asset&.contextual_title}

          Provide:
          1. category: One of #{CATEGORIES.join(', ')}
          2. urgency: low, medium, high
          3. key_info: Extracted details (dates, budget, requirements)
          4. sentiment: positive, neutral, negative
          5. spam_score: 0-100 likelihood of spam
          6. suggested_response: A professional response template
          7. follow_up_actions: Recommended next steps

          Respond in JSON format.
        PROMPT

        response = chat(prompt, temperature: 0.3)
        parse_and_store(message, response.content)
      end

      def auto_respond?(message, analysis)
        return false if analysis[:spam_score] > 50
        return false if analysis[:urgency] == 'high'

        website.ai_config&.dig('auto_respond_enabled') &&
          SAFE_AUTO_RESPOND_CATEGORIES.include?(analysis[:category])
      end

      private

      SAFE_AUTO_RESPOND_CATEGORIES = %w[
        general_inquiry
        availability_check
      ].freeze

      def parse_and_store(message, content)
        analysis = JSON.parse(content).symbolize_keys

        message.update!(
          ai_metadata: analysis,
          category: analysis[:category],
          urgency: analysis[:urgency]
        )

        analysis
      end
    end
  end
end
```

### 5.3 Admin Notification Enhancement

```ruby
# app/jobs/pwb/ai/process_enquiry_job.rb
module Pwb
  module Ai
    class ProcessEnquiryJob < ApplicationJob
      queue_as :ai_processing

      def perform(message_id)
        message = Pwb::Message.find(message_id)

        ActsAsTenant.with_tenant(message.website) do
          processor = EnquiryProcessor.new(message.website)
          analysis = processor.analyze(message)

          if analysis[:spam_score] > 80
            message.update!(status: :spam)
            return
          end

          if analysis[:urgency] == 'high'
            # Send immediate notification
            Pwb::EnquiryMailer.urgent_enquiry(message).deliver_later
          end

          if processor.auto_respond?(message, analysis)
            # Queue auto-response
            Pwb::Ai::SendAutoResponseJob.perform_later(
              message.id,
              analysis[:suggested_response]
            )
          end
        end
      end
    end
  end
end
```

---

## Phase 6: Content & Translation Assistant (Week 11-12)

### 6.1 Feature Overview

**User Story**: As a website admin, I want AI to help create and translate page content.

**Capabilities**:
- Generate page content from prompts
- Translate content between languages
- Improve existing content
- Suggest content structure

### 6.2 Implementation

```ruby
# app/services/pwb/ai/content_assistant.rb
module Pwb
  module Ai
    class ContentAssistant < AiService
      def generate_page_content(topic:, style:, length: :medium)
        prompt = <<~PROMPT
          Generate real estate website content for a page about: #{topic}

          Style: #{style} (professional, friendly, luxury, modern)
          Length: #{length} (short: 100 words, medium: 250 words, long: 500 words)

          Format the response as HTML with appropriate headings and paragraphs.
          Include a compelling headline and call-to-action.
        PROMPT

        response = chat(prompt, temperature: 0.7)
        { html: response.content, tokens: response.usage.total_tokens }
      end

      def translate_content(content, from:, to:)
        prompt = <<~PROMPT
          Translate this real estate content from #{from} to #{to}.
          Maintain the professional tone and real estate terminology.
          Preserve all HTML formatting.

          Content:
          #{content}
        PROMPT

        response = chat(prompt, temperature: 0.3)
        response.content
      end

      def improve_content(content, goals: [])
        goals_text = goals.any? ? goals.join(', ') : 'clarity, engagement, professionalism'

        prompt = <<~PROMPT
          Improve this real estate content focusing on: #{goals_text}

          Original:
          #{content}

          Provide:
          1. improved_content: The enhanced version
          2. changes_made: List of improvements
          3. suggestions: Additional recommendations

          Respond in JSON format.
        PROMPT

        response = chat(prompt, temperature: 0.5)
        JSON.parse(response.content).symbolize_keys
      end
    end
  end
end
```

---

## Phase 7: Conversational AI Agent (Week 13-16)

### 7.1 Feature Overview

**User Story**: As a website visitor, I want to chat with an AI assistant to find properties and get answers.

**Capabilities**:
- Answer property questions
- Search and filter properties via conversation
- Schedule viewings
- Collect lead information
- Hand off to human agent when needed

### 7.2 Implementation with ruby_llm-rails

```ruby
# Migration for chat persistence
class CreateAiChats < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_ai_chats do |t|
      t.references :website, foreign_key: { to_table: :pwb_websites }
      t.references :contact, foreign_key: { to_table: :pwb_contacts }, null: true
      t.string :session_id, null: false
      t.string :status, default: 'active'
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    create_table :pwb_ai_messages do |t|
      t.references :chat, foreign_key: { to_table: :pwb_ai_chats }
      t.string :role, null: false # user, assistant, system, tool
      t.text :content
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :pwb_ai_chats, :session_id
  end
end
```

```ruby
# app/models/pwb/ai_chat.rb
class Pwb::AiChat < ApplicationRecord
  include RubyLLM::ActsAsChat

  belongs_to :website
  belongs_to :contact, optional: true
  has_many :messages, class_name: 'Pwb::AiMessage', foreign_key: :chat_id

  acts_as_chat
end

# app/models/pwb/ai_message.rb
class Pwb::AiMessage < ApplicationRecord
  include RubyLLM::ActsAsMessage

  belongs_to :chat, class_name: 'Pwb::AiChat'

  acts_as_message
end
```

### 7.3 Chat Tools (Function Calling)

```ruby
# app/services/pwb/ai/chat_tools/property_search.rb
module Pwb
  module Ai
    module ChatTools
      class PropertySearch
        include RubyLLM::Tool

        description "Search for properties based on criteria"

        parameter :property_type, type: :string,
          description: "Type of property (apartment, house, villa, etc.)"
        parameter :transaction_type, type: :string, enum: %w[sale rent],
          description: "Whether to buy or rent"
        parameter :min_price, type: :number,
          description: "Minimum price in local currency"
        parameter :max_price, type: :number,
          description: "Maximum price in local currency"
        parameter :bedrooms, type: :integer,
          description: "Minimum number of bedrooms"
        parameter :location, type: :string,
          description: "City, region, or neighborhood"

        def execute(property_type: nil, transaction_type: 'sale',
                    min_price: nil, max_price: nil, bedrooms: nil, location: nil)
          scope = Pwb::ListedProperty.all

          scope = scope.where(property_type_key: property_type) if property_type
          scope = scope.for_sale if transaction_type == 'sale'
          scope = scope.for_rent if transaction_type == 'rent'
          scope = scope.where('price_cents >= ?', min_price * 100) if min_price
          scope = scope.where('price_cents <= ?', max_price * 100) if max_price
          scope = scope.where('count_bedrooms >= ?', bedrooms) if bedrooms
          scope = scope.where('city ILIKE ?', "%#{location}%") if location

          properties = scope.limit(5)

          if properties.any?
            format_results(properties)
          else
            "No properties found matching your criteria. Would you like to adjust your search?"
          end
        end

        private

        def format_results(properties)
          results = properties.map do |p|
            "- #{p.title}: #{p.formatted_price}, #{p.count_bedrooms} bed, #{p.city}"
          end

          "Found #{properties.size} properties:\n#{results.join("\n")}"
        end
      end
    end
  end
end
```

### 7.4 Chat Controller

```ruby
# app/controllers/pwb/ai_chat_controller.rb
module Pwb
  class AiChatController < ApplicationController
    def create
      @chat = find_or_create_chat

      user_message = params[:message]
      @chat.messages.create!(role: 'user', content: user_message)

      # Process with AI
      response = @chat.ask(user_message, tools: available_tools)

      render json: {
        message: response.content,
        chat_id: @chat.id
      }
    end

    private

    def find_or_create_chat
      Pwb::AiChat.find_or_create_by!(
        website: current_website,
        session_id: session.id.to_s
      ) do |chat|
        chat.messages.build(
          role: 'system',
          content: system_prompt
        )
      end
    end

    def available_tools
      [
        Pwb::Ai::ChatTools::PropertySearch.new,
        Pwb::Ai::ChatTools::ScheduleViewing.new,
        Pwb::Ai::ChatTools::ContactAgent.new
      ]
    end

    def system_prompt
      <<~PROMPT
        You are a helpful real estate assistant for #{current_website.company_name}.
        Help visitors find properties, answer questions, and schedule viewings.
        Be professional, friendly, and knowledgeable about the local market.

        Available properties are in: #{current_website.primary_region}
        Languages supported: #{current_website.supported_locales.join(', ')}
      PROMPT
    end
  end
end
```

---

## Configuration & Feature Flags

### Website AI Configuration

```ruby
# Add to Pwb::Website
class Pwb::Website < ApplicationRecord
  store_accessor :ai_config,
    :ai_enabled,
    :ai_provider,
    :ai_model,
    :auto_descriptions,
    :auto_alt_text,
    :auto_seo,
    :enquiry_processing,
    :chatbot_enabled,
    :auto_respond_enabled,
    :monthly_token_limit

  def ai_enabled?
    ai_enabled == true && ai_api_key.present?
  end

  def ai_tokens_remaining
    monthly_token_limit.to_i - ai_tokens_used_this_month
  end
end
```

### Admin Settings UI

```erb
<!-- app/views/site_admin/website/settings/_ai_tab.html.erb -->
<div class="space-y-6">
  <h2 class="text-xl font-bold">AI Features</h2>

  <div class="bg-yellow-50 p-4 rounded-lg">
    <p class="text-sm text-yellow-800">
      AI features use external APIs (OpenAI, Anthropic) which incur costs.
      Monitor your usage in the dashboard.
    </p>
  </div>

  <div class="grid grid-cols-2 gap-6">
    <!-- Master Toggle -->
    <div class="col-span-2">
      <%= form.check_box :ai_enabled, class: "toggle" %>
      <%= form.label :ai_enabled, "Enable AI Features" %>
    </div>

    <!-- Provider Selection -->
    <div>
      <%= form.label :ai_provider, "AI Provider" %>
      <%= form.select :ai_provider,
          [['OpenAI', 'openai'], ['Anthropic Claude', 'anthropic'], ['Google Gemini', 'gemini']],
          {}, class: "select" %>
    </div>

    <!-- Model Selection -->
    <div>
      <%= form.label :ai_model, "Model" %>
      <%= form.select :ai_model,
          [['GPT-4o Mini (Fast/Cheap)', 'gpt-4o-mini'],
           ['GPT-4o (Best Quality)', 'gpt-4o'],
           ['Claude Sonnet', 'claude-sonnet-4-20250514']],
          {}, class: "select" %>
    </div>

    <!-- Feature Toggles -->
    <div class="col-span-2 grid grid-cols-3 gap-4">
      <label class="flex items-center gap-2">
        <%= form.check_box :auto_descriptions %>
        Auto-generate descriptions
      </label>

      <label class="flex items-center gap-2">
        <%= form.check_box :auto_alt_text %>
        Auto-generate image alt text
      </label>

      <label class="flex items-center gap-2">
        <%= form.check_box :auto_seo %>
        SEO optimization
      </label>

      <label class="flex items-center gap-2">
        <%= form.check_box :enquiry_processing %>
        Smart enquiry processing
      </label>

      <label class="flex items-center gap-2">
        <%= form.check_box :chatbot_enabled %>
        Website chatbot
      </label>

      <label class="flex items-center gap-2">
        <%= form.check_box :auto_respond_enabled %>
        Auto-respond to enquiries
      </label>
    </div>

    <!-- Usage Limit -->
    <div>
      <%= form.label :monthly_token_limit, "Monthly Token Limit" %>
      <%= form.number_field :monthly_token_limit, class: "input",
          placeholder: "100000" %>
      <p class="text-sm text-gray-500">Current usage: <%= @website.ai_tokens_used_this_month %></p>
    </div>
  </div>
</div>
```

---

## Cost Management

### Token Tracking

```ruby
# app/services/pwb/ai/usage_tracker.rb
module Pwb
  module Ai
    class UsageTracker
      def self.track(website, tokens:, model:, feature:)
        Pwb::AiUsageLog.create!(
          website: website,
          tokens_used: tokens,
          model: model,
          feature: feature,
          cost_cents: calculate_cost(tokens, model),
          created_at: Time.current
        )

        # Update monthly counter
        website.increment!(:ai_tokens_this_month, tokens)
      end

      def self.calculate_cost(tokens, model)
        # Approximate costs per 1M tokens (as of 2025)
        rates = {
          'gpt-4o-mini' => 0.15,
          'gpt-4o' => 2.50,
          'claude-sonnet-4-20250514' => 3.00
        }

        rate = rates[model] || 1.0
        ((tokens / 1_000_000.0) * rate * 100).round # cents
      end
    end
  end
end
```

### Rate Limiting

```ruby
# app/services/pwb/ai_service.rb (enhanced)
class AiService
  before_action :check_rate_limit

  private

  def check_rate_limit
    if @website.ai_tokens_remaining <= 0
      raise RateLimitError, "Monthly AI token limit exceeded"
    end
  end
end
```

---

## Implementation Timeline

| Phase | Feature | Duration | Priority | Effort |
|-------|---------|----------|----------|--------|
| 1 | Foundation & Infrastructure | 2 weeks | Critical | Medium |
| 2 | Property Descriptions | 2 weeks | High | Medium |
| 3 | Image Analysis | 2 weeks | High | Medium |
| 4 | SEO Optimization | 2 weeks | Medium | Low |
| 5 | Enquiry Processing | 2 weeks | Medium | Medium |
| 6 | Content Assistant | 2 weeks | Low | Medium |
| 7 | Conversational Agent | 4 weeks | Low | High |

**Total Estimated Duration**: 16 weeks (4 months)

---

## Success Metrics

### User Value Metrics
- Time saved on description writing (target: 80% reduction)
- Enquiry response time (target: < 5 minutes for auto-responses)
- SEO ranking improvements (track over 3-6 months)
- Visitor engagement with chatbot (sessions, leads generated)

### Technical Metrics
- API response times (target: < 3 seconds)
- Token usage efficiency
- Error rates by feature
- Cost per feature per website

### Business Metrics
- Feature adoption rate by websites
- Revenue from AI tier subscriptions
- Customer satisfaction scores
- Churn reduction

---

## Security Considerations

1. **API Key Storage**: Use Rails credentials, never expose in client
2. **Content Filtering**: Validate AI outputs before display
3. **Rate Limiting**: Prevent abuse with per-website limits
4. **Audit Logging**: Track all AI operations
5. **Data Privacy**: Don't send PII to AI providers unless necessary
6. **Output Sanitization**: Escape HTML in AI-generated content

---

## Next Steps

1. **Immediate**: Add ruby_llm to Gemfile, create initializer
2. **Week 1**: Implement Phase 1 foundation
3. **Week 3**: Launch description generator as beta feature
4. **Week 5**: Add image analysis
5. **Month 2**: Roll out remaining features based on feedback
6. **Month 3+**: Conversational agent development

---

## Alternative Frameworks Analysis

### DSPy (https://dspy.ai/)

**What it is:** A declarative Python framework for building modular AI software from Stanford NLP. Uses "signatures" and "modules" instead of prompt strings, with automatic optimization.

**Key Features:**
- Modular programming with signatures (input/output specs) and modules
- Automatic prompt optimization via optimizers (BootstrapRS, MIPROv2, etc.)
- Supports 500+ LLM providers
- Good for complex multi-stage pipelines (RAG, agent chains)

**Pros:**
- Best-in-class for complex AI pipelines
- Automatic prompt tuning based on examples
- Testable, modular code
- Active research community

**Cons:**
- **Python-only** (PWB is Ruby/Rails) - requires separate microservice
- Overkill for simple use cases like description generation
- Adds architectural complexity
- Learning curve for team

**When to Consider DSPy:**
- Building complex RAG systems (e.g., property Q&A with document retrieval)
- Need automatic optimization across many tenants/use cases
- Building AI-first features requiring multi-stage pipelines
- Have Python expertise on team

**Recommendation:** Start with `ruby_llm` for native Rails integration. Consider DSPy only for Phase 7 (Conversational Agent) if complex reasoning chains are needed. Could deploy as a separate Python microservice that PWB calls via HTTP API.

**Example DSPy Use Case for PWB:**
```python
# Python microservice for complex property matching
import dspy

class PropertyMatcher(dspy.Signature):
    """Match properties to buyer requirements with reasoning."""
    requirements = dspy.InputField(desc="Buyer requirements in natural language")
    properties = dspy.InputField(desc="Available property listings as JSON")
    matches = dspy.OutputField(desc="Top 5 matching properties with reasoning")

class PropertyMatchingAgent(dspy.Module):
    def __init__(self):
        super().__init__()
        self.matcher = dspy.ChainOfThought(PropertyMatcher)

    def forward(self, requirements, properties):
        return self.matcher(requirements=requirements, properties=properties)
```

### Framework Comparison Summary

| Criteria | ruby_llm | DSPy | Direct API |
|----------|----------|------|------------|
| Language | Ruby | Python | Any |
| Rails Integration | Native | Microservice | Manual |
| Complexity | Low | High | Low |
| Multi-provider | 500+ models | 500+ models | Per-provider |
| Auto-optimization | No | Yes | No |
| Best for | Simple-medium features | Complex pipelines | Quick prototypes |
| Learning Curve | Low | Medium-High | Low |

### Recommended Approach

1. **Phases 1-6**: Use `ruby_llm` for native Rails integration
2. **Phase 7 (Chat Agent)**: Evaluate if DSPy complexity is needed
3. **Future**: Consider DSPy microservice for:
   - Complex property matching algorithms
   - Multi-step reasoning chains
   - A/B testing different prompting strategies

---

## References

- [ruby_llm Documentation](https://github.com/crmne/ruby_llm)
- [DSPy Documentation](https://dspy.ai/)
- [DSPy GitHub](https://github.com/stanfordnlp/dspy)
- [OpenAI API Pricing](https://openai.com/pricing)
- [Anthropic API Pricing](https://www.anthropic.com/pricing)
- [Rails Background Jobs](https://guides.rubyonrails.org/active_job_basics.html)

---

*Last updated: December 2024*
