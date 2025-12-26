# frozen_string_literal: true

# Helper methods for skeleton loading UI
#
# These helpers make it easy to add skeleton loading states to your views.
# They work with the skeleton Stimulus controller for smooth transitions.
#
# @example Basic usage with Stimulus controller
#   <%= skeleton_loader do |loader| %>
#     <%= loader.placeholder do %>
#       <%= skeleton_property_cards(3) %>
#     <% end %>
#     <%= loader.content do %>
#       <%= render @properties %>
#     <% end %>
#   <% end %>
#
# @example With Turbo Frame
#   <%= skeleton_loader(turbo_frame: true) do |loader| %>
#     ...
#   <% end %>
#
module SkeletonHelper
  # Renders a skeleton loading container with Stimulus controller
  #
  # @param delay [Integer] Auto-reveal after delay (milliseconds), 0 to disable
  # @param animate [Boolean] Whether to animate transitions
  # @param turbo_frame [Boolean] Whether to listen for Turbo frame load events
  # @yield [loader] Block that receives a loader object with placeholder and content methods
  def skeleton_loader(delay: 0, animate: true, turbo_frame: false, &block)
    loader = SkeletonLoaderBuilder.new(self)
    content = capture(loader, &block)

    data_attrs = {
      controller: "skeleton",
      skeleton_delay_value: delay,
      skeleton_animate_value: animate
    }

    if turbo_frame
      data_attrs[:action] = "turbo:frame-load->skeleton#loaded"
    end

    tag.div(content, data: data_attrs)
  end

  # Renders property card skeletons
  #
  # @param count [Integer] Number of skeleton cards to render
  # @param aspect [String] Aspect ratio class for image area
  def skeleton_property_cards(count = 1, aspect: "aspect-video")
    render partial: "shared/skeleton", locals: { type: :property_card, count: count, aspect: aspect }
  end

  # Renders text line skeletons
  #
  # @param lines [Integer] Number of text lines
  def skeleton_text(lines = 3)
    render partial: "shared/skeleton", locals: { type: :text, lines: lines }
  end

  # Renders image placeholder skeleton
  #
  # @param aspect [String] Aspect ratio class
  def skeleton_image(aspect: "aspect-video")
    render partial: "shared/skeleton", locals: { type: :image, aspect: aspect }
  end

  # Renders stat card skeletons (for dashboards)
  #
  # @param count [Integer] Number of stat cards
  def skeleton_stat_cards(count = 4)
    render partial: "shared/skeleton", locals: { type: :stat_card, count: count }
  end

  # Renders table row skeletons
  #
  # @param count [Integer] Number of table rows
  def skeleton_table_rows(count = 5)
    render partial: "shared/skeleton", locals: { type: :table_row, count: count }
  end

  # Renders list item skeletons
  #
  # @param count [Integer] Number of list items
  def skeleton_list_items(count = 5)
    render partial: "shared/skeleton", locals: { type: :list_item, count: count }
  end

  # Renders search result skeletons
  #
  # @param count [Integer] Number of search results
  def skeleton_search_results(count = 3)
    render partial: "shared/skeleton", locals: { type: :search_result, count: count }
  end

  # Renders media grid item skeletons
  #
  # @param count [Integer] Number of media items
  def skeleton_media_grid(count = 6)
    render partial: "shared/skeleton", locals: { type: :media_grid, count: count }
  end

  # Builder class for skeleton_loader helper
  class SkeletonLoaderBuilder
    def initialize(view_context)
      @view_context = view_context
    end

    # Renders the placeholder/skeleton content
    def placeholder(&block)
      content = @view_context.capture(&block)
      @view_context.tag.div(content, data: { skeleton_target: "placeholder" })
    end

    # Renders the actual content (initially hidden)
    def content(&block)
      content = @view_context.capture(&block)
      @view_context.tag.div(content, data: { skeleton_target: "content" }, class: "hidden")
    end
  end
end
