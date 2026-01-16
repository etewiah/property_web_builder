# frozen_string_literal: true

# Preview for currency selector component
# @label Currency Selector
class Molecules::CurrencySelectorPreview < Lookbook::Preview
  include PreviewHelper

  # Default currency selector
  # @label Default
  def default
    render partial: "shared/currency_selector"
  end

  # Currency selector with different palettes
  # @label With Theme
  # @param palette select { choices: [default, ocean, sunset, forest] }
  def with_theme(palette: :default)
    with_palette(palette) do
      render partial: "shared/currency_selector"
    end
  end
end
