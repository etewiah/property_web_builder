# Social Media Content Generator

## Overview

Generate ready-to-post social media content from property listings. This feature creates platform-specific posts (Instagram, Facebook, LinkedIn, X/Twitter) with optimized captions, hashtags, and image selections.

## Value Proposition

- **Time Savings**: Create weeks of social content in minutes
- **Platform Optimization**: Automatically format for each platform's requirements
- **Consistent Branding**: Maintain brand voice across all social channels
- **Hashtag Research**: AI-suggested relevant hashtags for reach
- **Image Selection**: Intelligent photo selection for maximum engagement

## Supported Platforms

| Platform | Caption Limit | Hashtags | Image Specs | Post Types |
|----------|---------------|----------|-------------|------------|
| Instagram | 2,200 chars | 30 max | 1080x1080, 1080x1350 | Feed, Story, Reel caption |
| Facebook | 63,206 chars | Unlimited | 1200x630 | Post, Story |
| LinkedIn | 3,000 chars | 5 recommended | 1200x627 | Post, Article |
| X/Twitter | 280 chars | 2-3 recommended | 1200x675 | Tweet, Thread |
| TikTok | 2,200 chars | 5-8 recommended | 1080x1920 | Video caption |

## Data Model

### Database Schema

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_social_media_posts.rb
class CreateSocialMediaPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_social_media_posts do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :ai_generation_request, foreign_key: { to_table: :pwb_ai_generation_requests }

      # Source listing
      t.references :postable, polymorphic: true  # SaleListing, RentalListing

      # Platform and format
      t.string :platform, null: false  # instagram, facebook, linkedin, twitter, tiktok
      t.string :post_type, null: false  # feed, story, reel, thread, article

      # Generated content
      t.text :caption, null: false
      t.text :hashtags
      t.jsonb :selected_photos, default: []  # Array of photo IDs with crop info
      t.string :call_to_action
      t.string :link_url

      # Scheduling
      t.datetime :scheduled_at
      t.string :status, default: 'draft'  # draft, scheduled, published, failed

      # Engagement tracking (for future analytics)
      t.integer :likes_count, default: 0
      t.integer :comments_count, default: 0
      t.integer :shares_count, default: 0
      t.integer :reach_count, default: 0

      t.timestamps
    end

    add_index :pwb_social_media_posts, [:website_id, :platform]
    add_index :pwb_social_media_posts, [:postable_type, :postable_id]
    add_index :pwb_social_media_posts, :status
    add_index :pwb_social_media_posts, :scheduled_at
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_social_media_templates.rb
class CreateSocialMediaTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_social_media_templates do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      t.string :name, null: false
      t.string :platform, null: false
      t.string :post_type, null: false
      t.string :category  # just_listed, price_drop, open_house, sold, market_update

      t.text :caption_template, null: false  # With placeholders like {{property_type}}, {{price}}
      t.text :hashtag_template
      t.jsonb :image_preferences, default: {}  # preferred aspect ratio, filters, etc.

      t.boolean :active, default: true
      t.boolean :is_default, default: false

      t.timestamps
    end

    add_index :pwb_social_media_templates, [:website_id, :platform, :category]
  end
end
```

### Model Definitions

```ruby
# app/models/pwb/social_media_post.rb
module Pwb
  class SocialMediaPost < ApplicationRecord
    belongs_to :website
    belongs_to :ai_generation_request, optional: true
    belongs_to :postable, polymorphic: true

    enum :platform, {
      instagram: 'instagram',
      facebook: 'facebook',
      linkedin: 'linkedin',
      twitter: 'twitter',
      tiktok: 'tiktok'
    }

    enum :post_type, {
      feed: 'feed',
      story: 'story',
      reel: 'reel',
      thread: 'thread',
      article: 'article'
    }

    enum :status, {
      draft: 'draft',
      scheduled: 'scheduled',
      published: 'published',
      failed: 'failed'
    }

    validates :platform, :post_type, :caption, presence: true
    validate :caption_length_for_platform

    scope :for_platform, ->(platform) { where(platform: platform) }
    scope :upcoming, -> { scheduled.where('scheduled_at > ?', Time.current).order(:scheduled_at) }

    # Platform-specific limits
    CAPTION_LIMITS = {
      instagram: 2200,
      facebook: 63206,
      linkedin: 3000,
      twitter: 280,
      tiktok: 2200
    }.freeze

    HASHTAG_LIMITS = {
      instagram: 30,
      facebook: nil,
      linkedin: 5,
      twitter: 3,
      tiktok: 8
    }.freeze

    def caption_length_for_platform
      limit = CAPTION_LIMITS[platform.to_sym]
      if limit && caption.to_s.length > limit
        errors.add(:caption, "exceeds #{limit} character limit for #{platform}")
      end
    end

    def full_caption
      [caption, hashtags].compact.join("\n\n")
    end

    def selected_photo_records
      return [] if selected_photos.blank?

      photo_ids = selected_photos.map { |p| p['id'] }
      Pwb::PropPhoto.where(id: photo_ids).index_by(&:id).values_at(*photo_ids).compact
    end
  end
end
```

```ruby
# app/models/pwb/social_media_template.rb
module Pwb
  class SocialMediaTemplate < ApplicationRecord
    belongs_to :website

    enum :platform, {
      instagram: 'instagram',
      facebook: 'facebook',
      linkedin: 'linkedin',
      twitter: 'twitter',
      tiktok: 'tiktok'
    }

    enum :category, {
      just_listed: 'just_listed',
      price_drop: 'price_drop',
      open_house: 'open_house',
      sold: 'sold',
      market_update: 'market_update',
      general: 'general'
    }

    validates :name, :platform, :post_type, :caption_template, presence: true

    scope :active, -> { where(active: true) }
    scope :for_platform, ->(platform) { where(platform: platform) }
    scope :default_templates, -> { where(is_default: true) }

    # Render template with listing data
    def render(listing)
      data = TemplateDataBuilder.new(listing).build
      rendered_caption = Liquid::Template.parse(caption_template).render(data)
      rendered_hashtags = hashtag_template.present? ?
        Liquid::Template.parse(hashtag_template).render(data) : nil

      {
        caption: rendered_caption,
        hashtags: rendered_hashtags
      }
    end
  end
end
```

## Service Layer

### Social Post Generator

```ruby
# app/services/ai/social_post_generator.rb
module Ai
  class SocialPostGenerator
    attr_reader :listing, :platform, :options

    PLATFORM_CONFIGS = {
      instagram: {
        tone: 'engaging and visual',
        emoji_level: :high,
        hashtag_count: 15,
        include_cta: true,
        cta_style: 'link in bio'
      },
      facebook: {
        tone: 'informative and friendly',
        emoji_level: :medium,
        hashtag_count: 5,
        include_cta: true,
        cta_style: 'direct link'
      },
      linkedin: {
        tone: 'professional',
        emoji_level: :low,
        hashtag_count: 5,
        include_cta: true,
        cta_style: 'professional inquiry'
      },
      twitter: {
        tone: 'concise and punchy',
        emoji_level: :medium,
        hashtag_count: 2,
        include_cta: true,
        cta_style: 'link'
      },
      tiktok: {
        tone: 'trendy and fun',
        emoji_level: :high,
        hashtag_count: 6,
        include_cta: true,
        cta_style: 'link in bio'
      }
    }.freeze

    def initialize(listing:, platform:, options: {})
      @listing = listing
      @platform = platform.to_sym
      @options = options.with_defaults(
        post_type: 'feed',
        category: 'just_listed',
        locale: 'en'
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

        parsed = parse_response(result[:content])

        post = create_social_post(parsed, request)

        request.update!(
          status: :completed,
          output_data: parsed,
          input_tokens: result[:usage][:input_tokens],
          output_tokens: result[:usage][:output_tokens],
          cost_cents: result[:usage][:cost_cents]
        )

        post
      rescue StandardError => e
        request.update!(status: :failed, error_message: e.message)
        raise
      end
    end

    def generate_batch(platforms: [:instagram, :facebook, :linkedin])
      platforms.map do |platform|
        generator = self.class.new(
          listing: listing,
          platform: platform,
          options: options
        )
        generator.generate
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
        request_type: :social_post,
        ai_provider: 'anthropic',
        ai_model: options[:model] || 'claude-sonnet-4-20250514',
        locale: options[:locale],
        input_data: {
          platform: platform,
          property: property_attributes,
          config: platform_config
        },
        options: options.except(:user, :model)
      )
    end

    def property_attributes
      asset = listing.realty_asset

      {
        property_type: asset.prop_type_key,
        bedrooms: asset.count_bedrooms,
        bathrooms: asset.count_bathrooms,
        price: format_price(listing),
        city: asset.city,
        region: asset.region,
        features: asset.features.pluck(:feature_key).first(5),
        photo_count: asset.prop_photos.count,
        listing_url: listing_url
      }
    end

    def format_price(listing)
      if listing.is_a?(Pwb::SaleListing)
        Money.new(listing.price_sale_current_cents, listing.price_sale_current_currency).format
      else
        "#{Money.new(listing.price_rental_monthly_current_cents, listing.price_rental_monthly_current_currency).format}/mo"
      end
    end

    def listing_url
      # Generate the public listing URL
      "#{listing.website.primary_url}/properties/#{listing.realty_asset.slug}"
    end

    def platform_config
      PLATFORM_CONFIGS[platform]
    end

    def build_prompt
      <<~PROMPT
        Create a #{platform} #{options[:post_type]} post for this real estate listing:

        ## Property Details
        - Type: #{property_attributes[:property_type]}
        - Bedrooms: #{property_attributes[:bedrooms]}
        - Bathrooms: #{property_attributes[:bathrooms]}
        - Price: #{property_attributes[:price]}
        - Location: #{property_attributes[:city]}, #{property_attributes[:region]}
        - Key Features: #{property_attributes[:features].join(', ')}

        ## Post Category: #{options[:category].to_s.titleize}

        ## Platform Requirements
        - Platform: #{platform.to_s.titleize}
        - Tone: #{platform_config[:tone]}
        - Emoji usage: #{platform_config[:emoji_level]}
        - Include #{platform_config[:hashtag_count]} relevant hashtags
        - Call-to-action style: #{platform_config[:cta_style]}

        #{category_specific_instructions}

        Respond in this JSON format:
        {
          "caption": "The main post caption",
          "hashtags": "#hashtag1 #hashtag2 ...",
          "suggested_photos": ["exterior", "living_room", "kitchen"],
          "best_posting_time": "suggestion for optimal posting time"
        }
      PROMPT
    end

    def category_specific_instructions
      case options[:category].to_sym
      when :just_listed
        "Focus on excitement about the new listing. Highlight unique features."
      when :price_drop
        "Emphasize the value and urgency. Mention the price reduction."
      when :open_house
        "Create urgency for the event. Include date/time placeholder."
      when :sold
        "Celebrate the sale. Build credibility and encourage other sellers."
      when :market_update
        "Provide market insights. Position as local expert."
      else
        "Create engaging content that drives inquiries."
      end
    end

    def system_prompt
      <<~SYSTEM
        You are an expert social media manager specializing in real estate marketing.
        You create engaging, platform-optimized content that drives leads and engagement.

        Guidelines:
        - Write authentic, non-salesy content
        - Use platform-specific best practices
        - Include relevant local hashtags
        - Create curiosity that drives clicks
        - Follow Fair Housing guidelines (no discriminatory language)
        - Make content shareable and engaging

        For #{platform}:
        #{platform_specific_guidelines}
      SYSTEM
    end

    def platform_specific_guidelines
      case platform
      when :instagram
        "- Use line breaks for readability\n- Front-load the hook\n- Mix popular and niche hashtags\n- Include emoji strategically"
      when :facebook
        "- Can be slightly longer form\n- Ask questions to drive comments\n- Tag location when possible"
      when :linkedin
        "- Professional tone\n- Focus on market expertise\n- Minimal hashtags\n- No excessive emoji"
      when :twitter
        "- Be concise and punchy\n- Leave room for retweets\n- Use 1-2 relevant hashtags"
      when :tiktok
        "- Trendy, casual language\n- Hook in first line\n- Trending hashtags when relevant"
      end
    end

    def parse_response(content)
      # Extract JSON from response
      json_match = content.match(/\{[\s\S]*\}/)
      return default_response unless json_match

      JSON.parse(json_match[0]).symbolize_keys
    rescue JSON::ParserError
      default_response
    end

    def default_response
      {
        caption: content,
        hashtags: '',
        suggested_photos: [],
        best_posting_time: nil
      }
    end

    def create_social_post(parsed, request)
      Pwb::SocialMediaPost.create!(
        website: listing.website,
        ai_generation_request: request,
        postable: listing,
        platform: platform,
        post_type: options[:post_type],
        caption: parsed[:caption],
        hashtags: parsed[:hashtags],
        selected_photos: select_photos(parsed[:suggested_photos]),
        link_url: listing_url,
        status: :draft
      )
    end

    def select_photos(suggestions)
      photos = listing.realty_asset.prop_photos.ordered.limit(10)
      return [] if photos.empty?

      # For now, just use the first few photos
      # Future: AI-based photo selection based on suggestions
      photos.first(4).map do |photo|
        {
          id: photo.id,
          url: photo.optimized_image_url,
          suggested_crop: aspect_ratio_for_platform
        }
      end
    end

    def aspect_ratio_for_platform
      case platform
      when :instagram
        options[:post_type] == 'story' ? '9:16' : '1:1'
      when :facebook
        '1.91:1'
      when :linkedin
        '1.91:1'
      when :twitter
        '16:9'
      when :tiktok
        '9:16'
      end
    end
  end
end
```

### Image Optimizer for Social

```ruby
# app/services/ai/social_image_optimizer.rb
module Ai
  class SocialImageOptimizer
    PLATFORM_SPECS = {
      instagram: {
        feed: { width: 1080, height: 1080, format: 'jpg' },
        story: { width: 1080, height: 1920, format: 'jpg' },
        reel: { width: 1080, height: 1920, format: 'jpg' }
      },
      facebook: {
        feed: { width: 1200, height: 630, format: 'jpg' },
        story: { width: 1080, height: 1920, format: 'jpg' }
      },
      linkedin: {
        feed: { width: 1200, height: 627, format: 'jpg' }
      },
      twitter: {
        feed: { width: 1200, height: 675, format: 'jpg' }
      },
      tiktok: {
        feed: { width: 1080, height: 1920, format: 'jpg' }
      }
    }.freeze

    attr_reader :photo, :platform, :post_type

    def initialize(photo:, platform:, post_type: 'feed')
      @photo = photo
      @platform = platform.to_sym
      @post_type = post_type.to_sym
    end

    def optimize
      spec = PLATFORM_SPECS.dig(platform, post_type) || PLATFORM_SPECS[:instagram][:feed]

      if photo.image.attached?
        photo.image.variant(
          resize_to_fill: [spec[:width], spec[:height]],
          format: spec[:format],
          saver: { quality: 85 }
        ).processed
      elsif photo.external?
        # For external images, return with resize parameters for CDN
        "#{photo.external_url}?w=#{spec[:width]}&h=#{spec[:height]}&fit=crop"
      end
    end

    def optimized_url
      variant = optimize
      return variant if variant.is_a?(String)

      variant.url
    rescue StandardError => e
      Rails.logger.warn "Failed to optimize image: #{e.message}"
      photo.optimized_image_url
    end
  end
end
```

## API Endpoints

```ruby
# config/routes.rb (add to api_manage namespace)
namespace :api_manage do
  namespace :v1 do
    scope "/:locale" do
      namespace :ai do
        resources :social_posts, only: [:index, :create, :show, :update, :destroy] do
          collection do
            post :batch_generate  # Generate for multiple platforms
            post :preview         # Preview without saving
          end
          member do
            post :duplicate       # Copy to another platform
            patch :schedule       # Schedule for posting
            get :download_images  # Get optimized images for download
          end
        end

        resources :social_templates, only: [:index, :create, :update, :destroy]
      end
    end
  end
end
```

```ruby
# app/controllers/api_manage/v1/ai/social_posts_controller.rb
module ApiManage
  module V1
    module Ai
      class SocialPostsController < BaseController
        before_action :find_listing, only: [:create, :batch_generate, :preview]
        before_action :find_post, only: [:show, :update, :destroy, :duplicate, :schedule, :download_images]

        # GET /api_manage/v1/:locale/ai/social_posts
        def index
          posts = current_website.social_media_posts
                                 .includes(:postable)
                                 .order(created_at: :desc)

          posts = posts.for_platform(params[:platform]) if params[:platform].present?
          posts = posts.where(status: params[:status]) if params[:status].present?

          render json: {
            posts: posts.limit(50).map { |post| serialize_post(post) }
          }
        end

        # POST /api_manage/v1/:locale/ai/social_posts
        def create
          generator = ::Ai::SocialPostGenerator.new(
            listing: @listing,
            platform: params[:platform],
            options: generation_options
          )

          post = generator.generate

          render json: {
            success: true,
            post: serialize_post(post)
          }, status: :created
        end

        # POST /api_manage/v1/:locale/ai/social_posts/batch_generate
        def batch_generate
          platforms = params[:platforms] || ['instagram', 'facebook', 'linkedin']

          generator = ::Ai::SocialPostGenerator.new(
            listing: @listing,
            platform: platforms.first, # Will be overridden
            options: generation_options
          )

          posts = generator.generate_batch(platforms: platforms.map(&:to_sym))

          render json: {
            success: true,
            posts: posts.map { |post| serialize_post(post) }
          }, status: :created
        end

        # POST /api_manage/v1/:locale/ai/social_posts/preview
        def preview
          generator = ::Ai::SocialPostGenerator.new(
            listing: @listing,
            platform: params[:platform],
            options: generation_options.merge(preview: true)
          )

          # Generate but don't save
          result = generator.send(:provider).generate(
            prompt: generator.send(:build_prompt),
            system_prompt: generator.send(:system_prompt)
          )

          parsed = generator.send(:parse_response, result[:content])

          render json: {
            success: true,
            preview: {
              caption: parsed[:caption],
              hashtags: parsed[:hashtags],
              suggested_photos: parsed[:suggested_photos]
            }
          }
        end

        # GET /api_manage/v1/:locale/ai/social_posts/:id
        def show
          render json: { post: serialize_post(@post, include_images: true) }
        end

        # PATCH /api_manage/v1/:locale/ai/social_posts/:id
        def update
          if @post.update(post_params)
            render json: { success: true, post: serialize_post(@post) }
          else
            render json: { error: 'Update failed', errors: @post.errors.full_messages },
                   status: :unprocessable_entity
          end
        end

        # DELETE /api_manage/v1/:locale/ai/social_posts/:id
        def destroy
          @post.destroy!
          render json: { success: true, message: 'Post deleted' }
        end

        # POST /api_manage/v1/:locale/ai/social_posts/:id/duplicate
        def duplicate
          new_post = @post.dup
          new_post.platform = params[:target_platform] || @post.platform
          new_post.status = :draft
          new_post.save!

          render json: { success: true, post: serialize_post(new_post) }
        end

        # PATCH /api_manage/v1/:locale/ai/social_posts/:id/schedule
        def schedule
          if @post.update(scheduled_at: params[:scheduled_at], status: :scheduled)
            render json: { success: true, post: serialize_post(@post) }
          else
            render json: { error: 'Scheduling failed', errors: @post.errors.full_messages },
                   status: :unprocessable_entity
          end
        end

        # GET /api_manage/v1/:locale/ai/social_posts/:id/download_images
        def download_images
          images = @post.selected_photos.map do |photo_data|
            photo = Pwb::PropPhoto.find_by(id: photo_data['id'])
            next unless photo

            optimizer = ::Ai::SocialImageOptimizer.new(
              photo: photo,
              platform: @post.platform,
              post_type: @post.post_type
            )

            {
              id: photo.id,
              optimized_url: optimizer.optimized_url,
              dimensions: optimizer.class::PLATFORM_SPECS.dig(@post.platform.to_sym, @post.post_type.to_sym)
            }
          end.compact

          render json: { images: images }
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

        def find_post
          @post = current_website.social_media_posts.find(params[:id])
        end

        def generation_options
          {
            user: current_user,
            post_type: params[:post_type] || 'feed',
            category: params[:category] || 'just_listed',
            locale: params[:locale]
          }
        end

        def post_params
          params.require(:post).permit(:caption, :hashtags, :status, :scheduled_at, selected_photos: [:id, :crop])
        end

        def serialize_post(post, include_images: false)
          data = {
            id: post.id,
            platform: post.platform,
            post_type: post.post_type,
            caption: post.caption,
            hashtags: post.hashtags,
            full_caption: post.full_caption,
            status: post.status,
            scheduled_at: post.scheduled_at&.iso8601,
            listing: {
              id: post.postable_id,
              type: post.postable_type,
              title: post.postable.title
            },
            created_at: post.created_at.iso8601
          }

          if include_images
            data[:images] = post.selected_photo_records.map do |photo|
              {
                id: photo.id,
                url: photo.optimized_image_url,
                thumbnail_url: photo.image.attached? ?
                  photo.image.variant(resize_to_limit: [200, 200]).processed.url : photo.external_url
              }
            end
          end

          data
        end
      end
    end
  end
end
```

## Site Admin Integration

### Social Media Dashboard

```erb
<%# app/views/site_admin/props/_social_media_generator.html.erb %>
<div class="social-media-generator"
     data-controller="social-media"
     data-social-media-listing-id-value="<%= listing.id %>"
     data-social-media-listing-type-value="<%= listing.class.name.demodulize.underscore %>">

  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-lg font-medium text-gray-900">Social Media Content</h3>
      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
        AI Powered
      </span>
    </div>

    <!-- Platform Selection -->
    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-2">Platforms</label>
      <div class="flex flex-wrap gap-2">
        <% %w[instagram facebook linkedin twitter].each do |platform| %>
          <label class="inline-flex items-center">
            <input type="checkbox"
                   data-social-media-target="platform"
                   value="<%= platform %>"
                   class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                   <%= platform == 'instagram' || platform == 'facebook' ? 'checked' : '' %>>
            <span class="ml-2 text-sm text-gray-700"><%= platform.titleize %></span>
          </label>
        <% end %>
      </div>
    </div>

    <!-- Post Category -->
    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-2">Post Type</label>
      <select data-social-media-target="category" class="input-field">
        <option value="just_listed">Just Listed</option>
        <option value="price_drop">Price Drop</option>
        <option value="open_house">Open House</option>
        <option value="general">General Promotion</option>
      </select>
    </div>

    <!-- Generate Button -->
    <button type="button"
            data-action="click->social-media#generate"
            data-social-media-target="generateBtn"
            class="btn btn-primary w-full mb-6">
      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"/>
      </svg>
      Generate Social Posts
    </button>

    <!-- Loading State -->
    <div data-social-media-target="loading" class="hidden">
      <div class="flex items-center justify-center py-8">
        <svg class="animate-spin h-8 w-8 text-blue-600" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
        </svg>
        <span class="ml-3 text-gray-600">Generating posts for selected platforms...</span>
      </div>
    </div>

    <!-- Generated Posts -->
    <div data-social-media-target="results" class="hidden space-y-4">
      <!-- Posts will be inserted here -->
    </div>
  </div>
</div>

<!-- Post Card Template -->
<template data-social-media-target="postTemplate">
  <div class="border rounded-lg p-4 post-card" data-platform="">
    <div class="flex items-center justify-between mb-3">
      <div class="flex items-center">
        <span class="platform-icon w-6 h-6 mr-2"></span>
        <span class="font-medium platform-name"></span>
      </div>
      <div class="flex space-x-2">
        <button class="text-sm text-gray-500 hover:text-gray-700 copy-btn" title="Copy to clipboard">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/>
          </svg>
        </button>
        <button class="text-sm text-gray-500 hover:text-gray-700 edit-btn" title="Edit">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
          </svg>
        </button>
      </div>
    </div>

    <div class="caption-text text-sm text-gray-700 whitespace-pre-wrap mb-3"></div>

    <div class="hashtags-text text-sm text-blue-600 mb-3"></div>

    <div class="flex items-center justify-between text-xs text-gray-500">
      <span class="char-count"></span>
      <button class="text-blue-600 hover:text-blue-800 download-images-btn">
        Download Images
      </button>
    </div>
  </div>
</template>
```

### Stimulus Controller

```javascript
// app/javascript/controllers/social_media_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "platform", "category", "generateBtn", "loading",
    "results", "postTemplate"
  ]

  static values = {
    listingId: Number,
    listingType: String
  }

  async generate() {
    const platforms = this.platformTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)

    if (platforms.length === 0) {
      alert('Please select at least one platform')
      return
    }

    this.showLoading()

    try {
      const response = await fetch('/api_manage/v1/en/ai/social_posts/batch_generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          listing_id: this.listingIdValue,
          listing_type: this.listingTypeValue,
          platforms: platforms,
          category: this.categoryTarget.value
        })
      })

      const data = await response.json()

      if (data.success) {
        this.displayResults(data.posts)
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError('Failed to generate posts. Please try again.')
    }
  }

  showLoading() {
    this.generateBtnTarget.disabled = true
    this.loadingTarget.classList.remove('hidden')
    this.resultsTarget.classList.add('hidden')
  }

  displayResults(posts) {
    this.loadingTarget.classList.add('hidden')
    this.generateBtnTarget.disabled = false
    this.resultsTarget.classList.remove('hidden')
    this.resultsTarget.innerHTML = ''

    posts.forEach(post => {
      const card = this.postTemplateTarget.content.cloneNode(true)

      card.querySelector('.post-card').dataset.platform = post.platform
      card.querySelector('.post-card').dataset.postId = post.id
      card.querySelector('.platform-name').textContent = this.platformLabel(post.platform)
      card.querySelector('.caption-text').textContent = post.caption
      card.querySelector('.hashtags-text').textContent = post.hashtags
      card.querySelector('.char-count').textContent = `${post.full_caption.length} characters`

      // Add platform icon
      card.querySelector('.platform-icon').innerHTML = this.platformIcon(post.platform)

      // Add event listeners
      card.querySelector('.copy-btn').addEventListener('click', () => this.copyToClipboard(post))
      card.querySelector('.edit-btn').addEventListener('click', () => this.editPost(post))
      card.querySelector('.download-images-btn').addEventListener('click', () => this.downloadImages(post))

      this.resultsTarget.appendChild(card)
    })
  }

  platformLabel(platform) {
    return {
      instagram: 'Instagram',
      facebook: 'Facebook',
      linkedin: 'LinkedIn',
      twitter: 'X (Twitter)',
      tiktok: 'TikTok'
    }[platform] || platform
  }

  platformIcon(platform) {
    const icons = {
      instagram: '<svg class="w-6 h-6 text-pink-600" fill="currentColor" viewBox="0 0 24 24">...</svg>',
      facebook: '<svg class="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 24 24">...</svg>',
      linkedin: '<svg class="w-6 h-6 text-blue-700" fill="currentColor" viewBox="0 0 24 24">...</svg>',
      twitter: '<svg class="w-6 h-6 text-gray-800" fill="currentColor" viewBox="0 0 24 24">...</svg>'
    }
    return icons[platform] || ''
  }

  async copyToClipboard(post) {
    const text = `${post.caption}\n\n${post.hashtags}`
    await navigator.clipboard.writeText(text)
    this.showToast('Copied to clipboard!')
  }

  editPost(post) {
    // Open edit modal or navigate to edit page
    window.location.href = `/site_admin/social_posts/${post.id}/edit`
  }

  async downloadImages(post) {
    const response = await fetch(`/api_manage/v1/en/ai/social_posts/${post.id}/download_images`)
    const data = await response.json()

    // Trigger downloads for each image
    data.images.forEach((img, index) => {
      const link = document.createElement('a')
      link.href = img.optimized_url
      link.download = `${post.platform}_image_${index + 1}.jpg`
      link.click()
    })
  }

  showError(message) {
    this.loadingTarget.classList.add('hidden')
    this.generateBtnTarget.disabled = false
    alert(message)
  }

  showToast(message) {
    // Implement toast notification
    console.log(message)
  }
}
```

## Export Formats

### Downloadable Content Package

```ruby
# app/services/social_content_exporter.rb
class SocialContentExporter
  attr_reader :posts

  def initialize(posts)
    @posts = posts
  end

  # Export as ZIP with images and captions
  def export_zip
    require 'zip'

    Tempfile.new(['social_content', '.zip']).tap do |zipfile|
      Zip::File.open(zipfile.path, Zip::File::CREATE) do |zip|
        posts.each do |post|
          # Add caption file
          zip.get_output_stream("#{post.platform}/caption.txt") do |f|
            f.write(post.full_caption)
          end

          # Add images
          post.selected_photo_records.each_with_index do |photo, i|
            optimizer = Ai::SocialImageOptimizer.new(
              photo: photo,
              platform: post.platform,
              post_type: post.post_type
            )

            # Download and add optimized image
            image_data = URI.open(optimizer.optimized_url).read
            zip.get_output_stream("#{post.platform}/image_#{i + 1}.jpg") do |f|
              f.write(image_data)
            end
          end
        end

        # Add README
        zip.get_output_stream("README.txt") do |f|
          f.write(readme_content)
        end
      end
    end
  end

  # Export as CSV for scheduling tools
  def export_csv
    CSV.generate do |csv|
      csv << ['Platform', 'Caption', 'Hashtags', 'Image URLs', 'Scheduled Time']

      posts.each do |post|
        image_urls = post.selected_photo_records.map(&:optimized_image_url).join('; ')
        csv << [post.platform, post.caption, post.hashtags, image_urls, post.scheduled_at]
      end
    end
  end

  private

  def readme_content
    <<~README
      Social Media Content Package
      Generated by PropertyWebBuilder

      Contents:
      - Each platform folder contains optimized images and caption text
      - Images are sized for optimal display on each platform

      Usage:
      1. Open the platform folder
      2. Copy the caption from caption.txt
      3. Upload the images to your post

      For scheduling tools, use the included CSV file.
    README
  end
end
```

## Implementation Phases

### Phase 1: Core Generation (Week 1-2)
- [ ] Create database migrations
- [ ] Build SocialPostGenerator service
- [ ] Implement platform-specific prompts
- [ ] Add API endpoints for generation
- [ ] Basic UI in site_admin

### Phase 2: Image Handling (Week 3)
- [ ] Implement SocialImageOptimizer
- [ ] Add image selection UI
- [ ] Build download/export functionality
- [ ] Platform-specific image cropping

### Phase 3: Templates & Polish (Week 4)
- [ ] Create template system
- [ ] Add template management UI
- [ ] Implement batch generation
- [ ] Add copy/edit/regenerate flows

### Phase 4: Future Enhancements
- [ ] Direct posting via platform APIs (Meta, LinkedIn)
- [ ] Scheduling calendar view
- [ ] Analytics integration
- [ ] A/B testing for captions
- [ ] Video/Reel caption generation
