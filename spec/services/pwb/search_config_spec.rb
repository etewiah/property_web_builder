# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::SearchConfig do
  let(:website) { create(:website) }

  describe "default configuration" do
    subject(:config) { described_class.new(website) }

    describe "price configuration" do
      it "provides default sale price presets" do
        expect(config.price_presets).to be_present
        # First element is "No min" for min presets
        expect(config.price_presets.first).to eq("No min")
        # Numeric values follow (starting at 200k to match typical market ranges)
        expect(config.price_presets[1]).to eq(200_000)
      end

      it "provides separate min and max presets" do
        expect(config.price_min_presets.first).to eq("No min")
        expect(config.price_max_presets.last).to eq("No max")
      end

      it "defaults to dropdown_with_manual input type" do
        expect(config.price_input_type).to eq("dropdown_with_manual")
      end

      it "returns nil for default min/max price" do
        expect(config.default_min_price).to be_nil
        expect(config.default_max_price).to be_nil
      end

      it "provides reasonable min/max bounds" do
        expect(config.min_price).to eq(0)
        expect(config.max_price).to eq(10_000_000)
      end
    end

    describe "bedroom/bathroom configuration" do
      it "provides default bedroom options" do
        expect(config.bedroom_options).to eq(["Any", 1, 2, 3, 4, 5, "6+"])
      end

      it "provides default bathroom options" do
        expect(config.bathroom_options).to eq(["Any", 1, 2, 3, 4, "5+"])
      end

      it "does not show max filters by default" do
        expect(config.show_max_bedrooms?).to be false
        expect(config.show_max_bathrooms?).to be false
      end
    end

    describe "area configuration" do
      it "provides default area presets" do
        expect(config.area_presets).to be_present
        expect(config.area_presets).to include(100, 200, 500)
      end

      it "defaults to sqm unit" do
        expect(config.area_unit).to eq("sqm")
      end

      it "defaults to dropdown_with_manual input type" do
        expect(config.area_input_type).to eq("dropdown_with_manual")
      end
    end

    describe "filter ordering" do
      it "returns enabled filters in position order" do
        filters = config.enabled_filters
        positions = filters.map { |_, cfg| cfg[:position] }
        expect(positions).to eq(positions.sort)
      end

      it "includes expected default filters" do
        filter_keys = config.enabled_filters.map(&:first)
        expect(filter_keys).to include(:reference, :price, :bedrooms, :bathrooms, :area)
      end

      it "excludes features by default" do
        filter_keys = config.enabled_filters.map(&:first)
        expect(filter_keys).not_to include(:features)
      end
    end

    describe "display settings" do
      it "defaults to not showing map" do
        expect(config.show_map?).to be false
      end

      it "defaults to newest sort" do
        expect(config.default_sort).to eq("newest")
      end

      it "provides default results per page options" do
        expect(config.results_per_page_options).to eq([12, 24, 48])
      end

      it "defaults to 24 results per page" do
        expect(config.default_results_per_page).to eq(24)
      end

      it "shows active filters by default" do
        expect(config.show_active_filters?).to be true
      end

      it "shows save search by default" do
        expect(config.show_save_search?).to be true
      end

      it "shows favorites by default" do
        expect(config.show_favorites?).to be true
      end

      it "defaults to grid card layout" do
        expect(config.card_layout).to eq("grid")
      end
    end

    describe "listing types" do
      it "enables sale by default" do
        expect(config.listing_type_enabled?(:sale)).to be true
      end

      it "enables rental by default" do
        expect(config.listing_type_enabled?(:rental)).to be true
      end

      it "defaults to sale listing type" do
        expect(config.listing_type).to eq(:sale)
        expect(config.default_listing_type).to eq(:sale)
      end

      it "returns enabled listing types" do
        expect(config.enabled_listing_types).to contain_exactly(:sale, :rental)
      end
    end
  end

  describe "listing type-specific configuration" do
    context "with sale listing type" do
      subject(:config) { described_class.new(website, listing_type: :sale) }

      it "returns sale price presets" do
        expect(config.listing_type).to eq(:sale)
        # First element is "No min", followed by numeric values (starting at 200k)
        expect(config.price_presets.first).to eq("No min")
        expect(config.price_presets[1]).to eq(200_000)
      end
    end

    context "with rental listing type" do
      subject(:config) { described_class.new(website, listing_type: :rental) }

      it "returns rental price presets" do
        expect(config.listing_type).to eq(:rental)
        # First element is "No min", followed by numeric values < 1000
        expect(config.price_presets.first).to eq("No min")
        expect(config.price_presets[1]).to be < 1000
      end

      it "returns lower max price for rentals" do
        expect(config.max_price).to eq(20_000)
      end
    end

    context "with listing type aliases" do
      it "normalizes for_sale to sale" do
        config = described_class.new(website, listing_type: "for_sale")
        expect(config.listing_type).to eq(:sale)
      end

      it "normalizes buy to sale" do
        config = described_class.new(website, listing_type: :buy)
        expect(config.listing_type).to eq(:sale)
      end

      it "normalizes for_rent to rental" do
        config = described_class.new(website, listing_type: "for_rent")
        expect(config.listing_type).to eq(:rental)
      end

      it "normalizes rent to rental" do
        config = described_class.new(website, listing_type: :rent)
        expect(config.listing_type).to eq(:rental)
      end
    end
  end

  describe "custom configuration" do
    context "with custom price presets" do
      before do
        website.update!(search_config: {
          "filters" => {
            "price" => {
              "enabled" => true,
              "input_type" => "dropdown",
              "sale" => {
                "presets" => [100_000, 250_000, 500_000]
              }
            }
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "uses custom price presets" do
        expect(config.price_presets).to eq([100_000, 250_000, 500_000])
      end

      it "uses custom input type" do
        expect(config.price_input_type).to eq("dropdown")
      end
    end

    context "with disabled filters" do
      before do
        website.update!(search_config: {
          "filters" => {
            "bedrooms" => { "enabled" => false },
            "bathrooms" => { "enabled" => false }
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "respects disabled filters" do
        filter_keys = config.enabled_filters.map(&:first)
        expect(filter_keys).not_to include(:bedrooms, :bathrooms)
      end

      it "returns false for filter_enabled?" do
        expect(config.filter_enabled?(:bedrooms)).to be false
        expect(config.filter_enabled?(:bathrooms)).to be false
      end
    end

    context "with custom display settings" do
      before do
        website.update!(search_config: {
          "display" => {
            "show_results_map" => true,
            "default_sort" => "price_asc",
            "default_results_per_page" => 48,
            "show_active_filters" => false
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "uses custom display settings" do
        expect(config.show_map?).to be true
        expect(config.default_sort).to eq("price_asc")
        expect(config.default_results_per_page).to eq(48)
        expect(config.show_active_filters?).to be false
      end
    end

    context "with custom listing types" do
      before do
        website.update!(search_config: {
          "listing_types" => {
            "sale" => { "enabled" => true, "is_default" => false },
            "rental" => { "enabled" => true, "is_default" => true }
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "uses custom default listing type" do
        expect(config.default_listing_type).to eq(:rental)
      end
    end

    context "with partial configuration" do
      before do
        website.update!(search_config: {
          "filters" => {
            "price" => {
              "input_type" => "manual"
            }
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "merges with defaults for unspecified values" do
        # Custom value applied
        expect(config.price_input_type).to eq("manual")
        # Default values preserved
        expect(config.price_presets).to be_present
        expect(config.bedroom_options).to eq(["Any", 1, 2, 3, 4, 5, "6+"])
      end
    end

    context "with custom filter positions" do
      before do
        website.update!(search_config: {
          "filters" => {
            "price" => { "position" => 5 },
            "bedrooms" => { "position" => 1 },
            "reference" => { "position" => 0 }
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "orders filters by custom position" do
        filter_keys = config.enabled_filters.map(&:first)
        price_index = filter_keys.index(:price)
        bedrooms_index = filter_keys.index(:bedrooms)
        expect(bedrooms_index).to be < price_index
      end
    end

    context "with default min/max values" do
      before do
        website.update!(search_config: {
          "filters" => {
            "price" => {
              "sale" => {
                "default_min" => 100_000,
                "default_max" => 500_000
              }
            },
            "bedrooms" => {
              "default_min" => 2
            },
            "area" => {
              "default_min" => 50,
              "default_max" => 200
            }
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "returns configured default values" do
        expect(config.default_min_price).to eq(100_000)
        expect(config.default_max_price).to eq(500_000)
        expect(config.default_min_bedrooms).to eq(2)
        expect(config.default_min_area).to eq(50)
        expect(config.default_max_area).to eq(200)
      end
    end

    context "with custom bedroom/bathroom options" do
      before do
        website.update!(search_config: {
          "filters" => {
            "bedrooms" => {
              "options" => ["Any", 1, 2, 3, "4+"],
              "show_max_filter" => true
            },
            "bathrooms" => {
              "options" => ["Any", 1, 2, "3+"]
            }
          }
        })
      end

      subject(:config) { described_class.new(website) }

      it "uses custom bedroom options" do
        expect(config.bedroom_options).to eq(["Any", 1, 2, 3, "4+"])
      end

      it "uses custom bathroom options" do
        expect(config.bathroom_options).to eq(["Any", 1, 2, "3+"])
      end

      it "shows max bedroom filter when configured" do
        expect(config.show_max_bedrooms?).to be true
      end
    end
  end

  describe "#filter" do
    subject(:config) { described_class.new(website) }

    it "returns filter configuration by name" do
      price_filter = config.filter(:price)
      expect(price_filter).to be_a(Hash)
      expect(price_filter[:enabled]).to be true
    end

    it "returns nil for unknown filter" do
      expect(config.filter(:unknown)).to be_nil
    end

    it "accepts string filter names" do
      expect(config.filter("price")).to eq(config.filter(:price))
    end
  end

  describe "#filter_enabled?" do
    subject(:config) { described_class.new(website) }

    it "returns true for enabled filters" do
      expect(config.filter_enabled?(:price)).to be true
      expect(config.filter_enabled?(:bedrooms)).to be true
    end

    it "returns false for disabled filters" do
      expect(config.filter_enabled?(:features)).to be false
    end

    it "returns false for unknown filters" do
      expect(config.filter_enabled?(:unknown)).to be false
    end
  end

  describe "#filter_options_for_view" do
    subject(:options) { described_class.new(website).filter_options_for_view }

    it "returns complete options hash for views" do
      expect(options).to include(
        :filters,
        :price,
        :price_presets,
        :price_input_type,
        :default_min_price,
        :default_max_price,
        :bedroom_options,
        :bathroom_options,
        :area_presets,
        :area_unit,
        :listing_types,
        :sort_options,
        :display
      )
    end

    it "includes enabled filters as hash" do
      expect(options[:filters]).to be_a(Hash)
      expect(options[:filters].keys).to include(:price, :bedrooms)
    end
  end

  describe "#sort_options_for_view" do
    subject(:sort_options) { described_class.new(website).sort_options_for_view }

    it "returns array of value/label hashes" do
      expect(sort_options).to be_an(Array)
      expect(sort_options.first).to have_key(:value)
      expect(sort_options.first).to have_key(:label)
    end

    it "includes all default sort options" do
      values = sort_options.map { |o| o[:value] }
      expect(values).to include("price_asc", "price_desc", "newest", "updated")
    end
  end

  describe "#listing_types_for_view" do
    subject(:listing_types) { described_class.new(website).listing_types_for_view }

    it "returns array of value/label/is_default hashes" do
      expect(listing_types).to be_an(Array)
      expect(listing_types.first).to have_key(:value)
      expect(listing_types.first).to have_key(:label)
      expect(listing_types.first).to have_key(:is_default)
    end

    it "includes sale and rental" do
      values = listing_types.map { |t| t[:value] }
      expect(values).to contain_exactly("sale", "rental")
    end

    it "marks one type as default" do
      defaults = listing_types.select { |t| t[:is_default] }
      expect(defaults.count).to eq(1)
    end
  end

  describe "#bedroom_options_for_view" do
    subject(:options) { described_class.new(website).bedroom_options_for_view }

    it "returns array of value/label hashes" do
      expect(options).to be_an(Array)
      options.each do |opt|
        expect(opt).to have_key(:value)
        expect(opt).to have_key(:label)
      end
    end

    it "uses empty string for Any value" do
      any_option = options.find { |o| o[:label] =~ /any/i }
      expect(any_option[:value]).to eq("")
    end
  end

  describe "#bathroom_options_for_view" do
    subject(:options) { described_class.new(website).bathroom_options_for_view }

    it "returns array of value/label hashes" do
      expect(options).to be_an(Array)
      options.each do |opt|
        expect(opt).to have_key(:value)
        expect(opt).to have_key(:label)
      end
    end
  end

  describe "Website model integration" do
    describe "#search_configuration" do
      it "returns a SearchConfig instance" do
        expect(website.search_configuration).to be_a(described_class)
      end

      it "memoizes the result" do
        expect(website.search_configuration).to be(website.search_configuration)
      end
    end

    describe "#search_configuration_for" do
      it "returns a SearchConfig for specified listing type" do
        config = website.search_configuration_for(:rental)
        expect(config).to be_a(described_class)
        expect(config.listing_type).to eq(:rental)
      end

      it "does not memoize (returns new instance)" do
        config1 = website.search_configuration_for(:sale)
        config2 = website.search_configuration_for(:sale)
        expect(config1).not_to be(config2)
      end
    end

    describe "#update_search_config" do
      it "updates specific config keys" do
        website.update_search_config(
          filters: { price: { input_type: "dropdown" } }
        )
        website.reload
        expect(website.search_config.dig("filters", "price", "input_type")).to eq("dropdown")
      end

      it "preserves existing config" do
        website.update!(search_config: {
          "filters" => { "bedrooms" => { "enabled" => false } }
        })
        website.update_search_config(
          filters: { price: { input_type: "dropdown" } }
        )
        website.reload
        expect(website.search_config.dig("filters", "bedrooms", "enabled")).to be false
        expect(website.search_config.dig("filters", "price", "input_type")).to eq("dropdown")
      end

      it "deep merges nested values" do
        website.update!(search_config: {
          "filters" => {
            "price" => {
              "sale" => { "presets" => [100_000] }
            }
          }
        })
        website.update_search_config(
          filters: { price: { input_type: "manual" } }
        )
        website.reload
        # Original nested value preserved
        expect(website.search_config.dig("filters", "price", "sale", "presets")).to eq([100_000])
        # New value added
        expect(website.search_config.dig("filters", "price", "input_type")).to eq("manual")
      end
    end

    describe "#reset_search_config" do
      it "resets config to empty hash" do
        website.update!(search_config: { "filters" => { "price" => { "enabled" => false } } })
        website.reset_search_config
        website.reload
        expect(website.search_config).to eq({})
      end

      it "causes SearchConfig to use defaults" do
        website.update!(search_config: {
          "filters" => { "price" => { "sale" => { "presets" => [999] } } }
        })
        website.reset_search_config
        website.reload
        config = described_class.new(website)
        expect(config.price_presets).not_to eq([999])
      end
    end
  end
end
