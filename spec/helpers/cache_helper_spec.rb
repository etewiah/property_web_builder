# frozen_string_literal: true

require "rails_helper"

RSpec.describe CacheHelper, type: :helper do
  let(:website) { create(:website) }

  # Helper to reset memoized values
  def reset_memoization!
    helper.instance_variable_set(:@_edit_mode, nil)
    helper.instance_variable_set(:@_compiling_for_lock, nil)
    helper.instance_variable_set(:@compiling_for_lock, nil)
    helper.instance_variable_set(:@edit_mode, nil)
  end

  before do
    reset_memoization!
    helper.instance_variable_set(:@current_website, website)
    allow(Pwb::Current).to receive(:website).and_return(website)
    allow(helper).to receive(:params).and_return({})
  end

  describe "#cache_key_for" do
    it "generates a tenant-scoped cache key" do
      key = helper.cache_key_for("test", "parts")
      expect(key).to include("w#{website.id}")
      expect(key).to include("l#{I18n.locale}")
      expect(key).to include("test")
      expect(key).to include("parts")
    end

    it "includes locale in cache key" do
      I18n.with_locale(:es) do
        key = helper.cache_key_for("test")
        expect(key).to include("les")
      end
    end
  end

  describe "#edit_mode?" do
    context "when params[:edit_mode] is 'true'" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({ edit_mode: "true" })
      end

      it "returns true" do
        expect(helper.edit_mode?).to be true
      end
    end

    context "when params[:edit_mode] is not present" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({})
      end

      it "returns false" do
        expect(helper.edit_mode?).to be false
      end
    end

    context "when @edit_mode instance variable is set" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({})
        helper.instance_variable_set(:@edit_mode, true)
      end

      it "returns true" do
        expect(helper.edit_mode?).to be true
      end
    end
  end

  describe "#compiling_for_lock?" do
    context "when @compiling_for_lock is not set" do
      before do
        reset_memoization!
      end

      it "returns false" do
        expect(helper.compiling_for_lock?).to be false
      end
    end

    context "when @compiling_for_lock is true" do
      before do
        reset_memoization!
        helper.instance_variable_set(:@compiling_for_lock, true)
      end

      it "returns true" do
        expect(helper.compiling_for_lock?).to be true
      end
    end
  end

  describe "#cacheable?" do
    context "when not in edit mode and not compiling" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({})
      end

      it "returns true" do
        expect(helper.cacheable?).to be true
      end
    end

    context "when in edit mode" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({ edit_mode: "true" })
      end

      it "returns false" do
        expect(helper.cacheable?).to be false
      end
    end

    context "when compiling for lock" do
      before do
        reset_memoization!
        helper.instance_variable_set(:@compiling_for_lock, true)
        allow(helper).to receive(:params).and_return({})
      end

      it "returns false" do
        expect(helper.cacheable?).to be false
      end
    end
  end

  describe "#page_cache_key" do
    it "returns nil for nil page" do
      expect(helper.page_cache_key(nil)).to be_nil
    end

    it "generates a cache key for pages" do
      page = website.pages.create!(slug: "test-page", visible: true)
      key = helper.page_cache_key(page)
      expect(key).to include("page")
      expect(key).to include(page.slug)
    end
  end

  describe "#page_part_cache_key" do
    it "returns nil for nil page part" do
      expect(helper.page_part_cache_key(nil)).to be_nil
    end

    it "generates a cache key for page parts" do
      page_part = website.page_parts.create!(page_part_key: "test/part")
      key = helper.page_part_cache_key(page_part)
      expect(key).to include("page_part")
      expect(key).to include("test/part")
    end
  end

  describe "#property_cache_key" do
    it "returns nil for nil property" do
      expect(helper.property_cache_key(nil)).to be_nil
    end
  end

  describe "#cache_unless_editing" do
    context "when cacheable" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({})
      end

      it "calls cache with the key" do
        expect(helper).to receive(:cache).with("test_key", {})
        helper.cache_unless_editing("test_key") { "content" }
      end
    end

    context "when not cacheable (edit mode)" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({ edit_mode: "true" })
      end

      it "does not call cache" do
        expect(helper).not_to receive(:cache)
        expect(helper).to receive(:capture).and_return("content")
        helper.cache_unless_editing("test_key") { "content" }
      end
    end

    context "when key is nil" do
      before do
        reset_memoization!
        allow(helper).to receive(:params).and_return({})
      end

      it "does not call cache" do
        expect(helper).not_to receive(:cache)
        expect(helper).to receive(:capture).and_return("content")
        helper.cache_unless_editing(nil) { "content" }
      end
    end
  end
end
