# frozen_string_literal: true

# Preview for skeleton loader components
# @label Skeleton Loader
class Atoms::SkeletonPreview < Lookbook::Preview
  include PreviewHelper

  # Default skeleton loader
  # @label Default
  def default
    render partial: "shared/skeleton"
  end

  # Property card skeleton
  # @label Property Card
  # @notes
  #   Used when loading property listings. Shows placeholder for
  #   image, title, price, and stats.
  def property_card
    render partial: "shared/skeleton", locals: { type: :property_card }
  end

  # List skeleton
  # @label List Items
  # @notes
  #   Multiple skeleton rows for list loading states.
  def list
    render partial: "shared/skeleton", locals: { type: :list, count: 5 }
  end
end
