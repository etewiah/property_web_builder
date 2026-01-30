# frozen_string_literal: true

module ApiManage
  module V1
    module Ai
      # API endpoint for AI-powered social media post generation
      #
      # POST /api_manage/v1/:locale/ai/social_posts
      #   Generates a social post for a single platform
      #
      # POST /api_manage/v1/:locale/ai/social_posts/batch_generate
      #   Generates posts for multiple platforms at once
      #
      # GET /api_manage/v1/:locale/ai/social_posts
      #   Lists all social posts for the current website
      #
      class SocialPostsController < ::ApiManage::V1::BaseController
        before_action :find_property, only: [:create, :batch_generate]
        before_action :find_post, only: [:show, :update, :destroy, :duplicate, :schedule, :download_images]

        # GET /api_manage/v1/:locale/ai/social_posts
        def index
          posts = current_website.social_media_posts
                                .includes(:postable)
                                .order(created_at: :desc)

          posts = posts.for_platform(params[:platform]) if params[:platform].present?
          posts = posts.where(status: params[:status]) if params[:status].present?

          render json: {
            success: true,
            posts: posts.limit(50).map { |post| serialize_post(post) }
          }
        end

        # POST /api_manage/v1/:locale/ai/social_posts
        def create
          generator = ::Ai::SocialPostGenerator.new(
            property: @property,
            platform: params[:platform] || 'instagram',
            options: generation_options
          )

          result = generator.generate

          if result.success?
            render json: {
              success: true,
              post: serialize_post(result.post, include_images: true)
            }, status: :created
          else
            render json: {
              success: false,
              error: result.error
            }, status: :unprocessable_entity
          end
        rescue ::Ai::ConfigurationError => e
          render json: {
            success: false,
            error: "AI is not configured: #{e.message}"
          }, status: :service_unavailable
        rescue ::Ai::RateLimitError => e
          render json: {
            success: false,
            error: "Rate limit exceeded. Please try again later.",
            retry_after: e.retry_after
          }, status: :too_many_requests
        end

        # POST /api_manage/v1/:locale/ai/social_posts/batch_generate
        def batch_generate
          platforms = params[:platforms] || %w[instagram facebook linkedin]

          generator = ::Ai::SocialPostGenerator.new(
            property: @property,
            platform: platforms.first,
            options: generation_options
          )

          results = generator.generate_batch(platforms: platforms.map(&:to_sym))

          successful_posts = results.select(&:success?).map(&:post)
          failed_platforms = results.reject(&:success?).map { |r| { error: r.error } }

          render json: {
            success: failed_platforms.empty?,
            posts: successful_posts.map { |post| serialize_post(post, include_images: true) },
            errors: failed_platforms
          }, status: failed_platforms.empty? ? :created : :multi_status
        rescue ::Ai::ConfigurationError => e
          render json: {
            success: false,
            error: "AI is not configured: #{e.message}"
          }, status: :service_unavailable
        rescue ::Ai::RateLimitError => e
          render json: {
            success: false,
            error: "Rate limit exceeded. Please try again later.",
            retry_after: e.retry_after
          }, status: :too_many_requests
        end

        # GET /api_manage/v1/:locale/ai/social_posts/:id
        def show
          render json: {
            success: true,
            post: serialize_post(@post, include_images: true)
          }
        end

        # PATCH /api_manage/v1/:locale/ai/social_posts/:id
        def update
          if @post.update(post_params)
            render json: {
              success: true,
              post: serialize_post(@post)
            }
          else
            render json: {
              success: false,
              error: 'Update failed',
              errors: @post.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        # DELETE /api_manage/v1/:locale/ai/social_posts/:id
        def destroy
          @post.destroy!
          render json: {
            success: true,
            message: 'Post deleted'
          }
        end

        # POST /api_manage/v1/:locale/ai/social_posts/:id/duplicate
        def duplicate
          new_post = @post.dup
          new_post.platform = params[:target_platform] || @post.platform
          new_post.status = 'draft'
          new_post.ai_generation_request = nil
          new_post.save!

          render json: {
            success: true,
            post: serialize_post(new_post)
          }, status: :created
        end

        # PATCH /api_manage/v1/:locale/ai/social_posts/:id/schedule
        def schedule
          scheduled_time = Time.zone.parse(params[:scheduled_at]) rescue nil

          unless scheduled_time
            return render json: {
              success: false,
              error: 'Invalid scheduled_at time'
            }, status: :unprocessable_entity
          end

          if @post.schedule!(scheduled_time)
            render json: {
              success: true,
              post: serialize_post(@post)
            }
          else
            render json: {
              success: false,
              error: 'Scheduling failed',
              errors: @post.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        # GET /api_manage/v1/:locale/ai/social_posts/:id/download_images
        def download_images
          images = @post.selected_photos.filter_map do |photo_data|
            photo = Pwb::PropPhoto.find_by(id: photo_data['id'] || photo_data[:id])
            next unless photo

            {
              id: photo.id,
              url: photo.respond_to?(:optimized_image_url) ? photo.optimized_image_url : nil,
              platform: @post.platform,
              post_type: @post.post_type,
              suggested_crop: photo_data['suggested_crop'] || photo_data[:suggested_crop]
            }
          end

          render json: {
            success: true,
            images: images
          }
        end

        private

        def find_property
          @property = Pwb::RealtyAsset.where(website_id: current_website&.id).find(params[:property_id])
        end

        def find_post
          @post = current_website.social_media_posts.find(params[:id])
        end

        def generation_options
          {
            user: current_user,
            post_type: params[:post_type] || 'feed',
            category: params[:category] || 'just_listed',
            locale: params[:locale] || 'en'
          }
        end

        def post_params
          params.require(:post).permit(:caption, :hashtags, :status, :call_to_action, :link_url)
        end

        def current_user
          # TODO: Get current user from authentication
          nil
        end

        def serialize_post(post, include_images: false)
          data = {
            id: post.id,
            platform: post.platform,
            post_type: post.post_type,
            caption: post.caption,
            hashtags: post.hashtags,
            full_caption: post.full_caption,
            character_count: post.character_count,
            hashtag_count: post.hashtag_count,
            status: post.status,
            scheduled_at: post.scheduled_at&.iso8601,
            link_url: post.link_url,
            call_to_action: post.call_to_action,
            listing: serialize_listing(post.postable),
            created_at: post.created_at.iso8601,
            updated_at: post.updated_at.iso8601
          }

          if include_images && post.selected_photos.present?
            data[:images] = post.selected_photo_records.map do |photo|
              {
                id: photo.id,
                url: photo.respond_to?(:optimized_image_url) ? photo.optimized_image_url : nil
              }
            end
          end

          data
        end

        def serialize_listing(postable)
          return nil unless postable

          {
            id: postable.id,
            type: postable.class.name,
            title: postable.try(:title) || postable.try(:headline) || "Property ##{postable.id}"
          }
        end
      end
    end
  end
end
