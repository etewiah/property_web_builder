# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::FieldSchemaBuilder do
  describe "FIELD_TYPES" do
    it "defines expected field types" do
      expect(described_class::FIELD_TYPES.keys).to include(
        :text, :textarea, :html, :number, :currency, :email, :phone, :url,
        :image, :select, :checkbox, :boolean, :icon, :color, :date,
        :faq_array, :feature_list
      )
    end

    it "has component for each field type" do
      described_class::FIELD_TYPES.each do |type, config|
        expect(config).to have_key(:component),
          "Field type #{type} missing :component"
      end
    end

    it "has description for each field type" do
      described_class::FIELD_TYPES.each do |type, config|
        expect(config).to have_key(:description),
          "Field type #{type} missing :description"
      end
    end
  end

  describe ".infer_type" do
    context "special array types" do
      it "infers faq_array for faq_items" do
        expect(described_class.infer_type("faq_items")).to eq(:faq_array)
      end

      it "infers feature_list for fields ending with _features" do
        expect(described_class.infer_type("plan_1_features")).to eq(:feature_list)
      end

      it "infers feature_list for fields ending with _amenities" do
        expect(described_class.infer_type("property_amenities")).to eq(:feature_list)
      end
    end

    context "image fields" do
      it "infers image for fields ending with _image" do
        expect(described_class.infer_type("background_image")).to eq(:image)
        expect(described_class.infer_type("member_1_image")).to eq(:image)
      end

      it "infers image for fields ending with _photo" do
        expect(described_class.infer_type("profile_photo")).to eq(:image)
      end

      it "infers image for fields starting with image_" do
        expect(described_class.infer_type("image_1")).to eq(:image)
      end

      it "infers image for fields ending with _avatar" do
        expect(described_class.infer_type("user_avatar")).to eq(:image)
      end

      it "infers image for fields ending with _logo" do
        expect(described_class.infer_type("company_logo")).to eq(:image)
      end

      it "infers image for fields ending with _thumbnail" do
        expect(described_class.infer_type("video_thumbnail")).to eq(:image)
      end
    end

    context "HTML fields" do
      it "infers html for fields ending with _html" do
        expect(described_class.infer_type("content_html")).to eq(:html)
        expect(described_class.infer_type("footer_html")).to eq(:html)
      end
    end

    context "email fields" do
      it "infers email for fields ending with _email" do
        expect(described_class.infer_type("member_1_email")).to eq(:email)
        expect(described_class.infer_type("contact_email")).to eq(:email)
      end

      it "infers email for field named email" do
        expect(described_class.infer_type("email")).to eq(:email)
      end
    end

    context "phone fields" do
      it "infers phone for fields ending with _phone" do
        expect(described_class.infer_type("contact_phone")).to eq(:phone)
        expect(described_class.infer_type("member_1_phone")).to eq(:phone)
      end

      it "infers phone for fields ending with _tel" do
        expect(described_class.infer_type("office_tel")).to eq(:phone)
      end

      it "infers phone for fields ending with _mobile" do
        expect(described_class.infer_type("agent_mobile")).to eq(:phone)
      end

      it "infers phone for field named phone" do
        expect(described_class.infer_type("phone")).to eq(:phone)
      end
    end

    context "currency fields" do
      it "infers currency for fields ending with _price" do
        expect(described_class.infer_type("plan_1_price")).to eq(:currency)
        expect(described_class.infer_type("monthly_price")).to eq(:currency)
      end

      it "infers currency for fields ending with _cost" do
        expect(described_class.infer_type("total_cost")).to eq(:currency)
      end

      it "infers currency for fields ending with _amount" do
        expect(described_class.infer_type("deposit_amount")).to eq(:currency)
      end

      it "infers currency for fields ending with _fee" do
        expect(described_class.infer_type("service_fee")).to eq(:currency)
      end
    end

    context "number fields" do
      it "infers number for fields ending with _value" do
        expect(described_class.infer_type("stat_1_value")).to eq(:number)
      end

      it "infers number for fields ending with _count" do
        expect(described_class.infer_type("property_count")).to eq(:number)
      end

      it "infers number for fields ending with _quantity" do
        expect(described_class.infer_type("item_quantity")).to eq(:number)
      end

      it "infers number for fields ending with _columns" do
        expect(described_class.infer_type("grid_columns")).to eq(:number)
      end

      it "infers number for fields ending with _year" do
        expect(described_class.infer_type("built_year")).to eq(:number)
      end
    end

    context "URL fields" do
      it "infers url for fields ending with _url" do
        expect(described_class.infer_type("website_url")).to eq(:url)
      end

      it "infers url for fields ending with _link" do
        expect(described_class.infer_type("cta_link")).to eq(:url)
        expect(described_class.infer_type("button_link")).to eq(:url)
      end

      it "infers url for fields ending with _href" do
        expect(described_class.infer_type("nav_href")).to eq(:url)
      end

      it "infers url for fields ending with _website" do
        expect(described_class.infer_type("company_website")).to eq(:url)
      end
    end

    context "social link fields" do
      it "infers social_link for social platform names" do
        expect(described_class.infer_type("facebook")).to eq(:social_link)
        expect(described_class.infer_type("twitter")).to eq(:social_link)
        expect(described_class.infer_type("instagram")).to eq(:social_link)
        expect(described_class.infer_type("linkedin")).to eq(:social_link)
        expect(described_class.infer_type("youtube")).to eq(:social_link)
      end
    end

    context "color fields" do
      it "infers color for fields ending with _color" do
        expect(described_class.infer_type("card_1_color")).to eq(:color)
        expect(described_class.infer_type("text_color")).to eq(:color)
        expect(described_class.infer_type("accent_color")).to eq(:color)
      end

      it "infers color for fields ending with _colour" do
        expect(described_class.infer_type("primary_colour")).to eq(:color)
      end
    end

    context "icon fields" do
      it "infers icon for fields ending with _icon" do
        expect(described_class.infer_type("feature_1_icon")).to eq(:icon)
        expect(described_class.infer_type("card_icon")).to eq(:icon)
      end
    end

    context "select fields" do
      it "infers select for fields ending with _style" do
        expect(described_class.infer_type("button_style")).to eq(:select)
        expect(described_class.infer_type("bg_style")).to eq(:select)
      end

      it "infers select for fields ending with _layout" do
        expect(described_class.infer_type("grid_layout")).to eq(:select)
      end

      it "infers select for fields ending with _position" do
        expect(described_class.infer_type("text_position")).to eq(:select)
        expect(described_class.infer_type("content_position")).to eq(:select)
      end

      it "infers select for field named style" do
        expect(described_class.infer_type("style")).to eq(:select)
      end

      it "infers select for fields ending with _alignment" do
        expect(described_class.infer_type("text_alignment")).to eq(:select)
      end
    end

    context "boolean fields" do
      it "infers boolean for fields starting with is_" do
        expect(described_class.infer_type("is_featured")).to eq(:boolean)
        expect(described_class.infer_type("is_active")).to eq(:boolean)
      end

      it "infers boolean for fields starting with has_" do
        expect(described_class.infer_type("has_parking")).to eq(:boolean)
      end

      it "infers boolean for fields starting with show_" do
        expect(described_class.infer_type("show_header")).to eq(:boolean)
        expect(described_class.infer_type("show_in_nav")).to eq(:boolean)
      end

      it "infers boolean for fields ending with _enabled" do
        expect(described_class.infer_type("feature_enabled")).to eq(:boolean)
      end

      it "infers boolean for fields ending with _visible" do
        expect(described_class.infer_type("section_visible")).to eq(:boolean)
      end
    end

    context "date fields" do
      it "infers date for fields ending with _date" do
        expect(described_class.infer_type("start_date")).to eq(:date)
        expect(described_class.infer_type("end_date")).to eq(:date)
      end
    end

    context "textarea fields" do
      it "infers textarea for fields ending with _description" do
        expect(described_class.infer_type("feature_1_description")).to eq(:textarea)
      end

      it "infers textarea for fields ending with _content" do
        expect(described_class.infer_type("main_content")).to eq(:textarea)
      end

      it "infers textarea for fields ending with _body" do
        expect(described_class.infer_type("article_body")).to eq(:textarea)
      end

      it "infers textarea for fields ending with _bio" do
        expect(described_class.infer_type("member_1_bio")).to eq(:textarea)
      end

      it "infers textarea for fields ending with _summary" do
        expect(described_class.infer_type("page_summary")).to eq(:textarea)
      end

      it "infers textarea for fields ending with _text" do
        expect(described_class.infer_type("testimonial_1_text")).to eq(:textarea)
      end

      it "infers textarea for fields ending with _caption" do
        expect(described_class.infer_type("video_caption")).to eq(:textarea)
        expect(described_class.infer_type("gallery_caption")).to eq(:textarea)
      end

      it "infers textarea for field named description" do
        expect(described_class.infer_type("description")).to eq(:textarea)
      end

      it "infers textarea for fields ending with _quote" do
        expect(described_class.infer_type("testimonial_quote")).to eq(:textarea)
      end
    end

    context "map embed fields" do
      it "infers map_embed for fields ending with _map" do
        expect(described_class.infer_type("location_map")).to eq(:map_embed)
      end

      it "infers map_embed for field named map_embed" do
        expect(described_class.infer_type("map_embed")).to eq(:map_embed)
      end
    end

    context "default fallback" do
      it "infers text for unrecognized field names" do
        expect(described_class.infer_type("title")).to eq(:text)
        expect(described_class.infer_type("pretitle")).to eq(:text)
        expect(described_class.infer_type("label")).to eq(:text)
        expect(described_class.infer_type("name")).to eq(:text)
        expect(described_class.infer_type("random_field")).to eq(:text)
      end

      it "infers textarea for fields ending with _text (not text type)" do
        # Note: fields ending with _text are inferred as textarea, not text
        expect(described_class.infer_type("cta_text")).to eq(:textarea)
        expect(described_class.infer_type("button_text")).to eq(:textarea)
      end
    end
  end

  describe ".build_field_definition" do
    context "with minimal config" do
      it "builds definition with inferred type" do
        result = described_class.build_field_definition(:title, {})

        expect(result[:name]).to eq("title")
        expect(result[:type]).to eq("text")
        expect(result[:label]).to eq("Title")
        expect(result[:component]).to eq("TextInput")
      end

      it "infers correct type from field name" do
        result = described_class.build_field_definition(:background_image, {})

        expect(result[:type]).to eq("image")
        expect(result[:component]).to eq("ImageInlinePicker")
      end
    end

    context "with explicit type" do
      it "uses explicit type over inferred" do
        result = described_class.build_field_definition(:my_field, { type: :html })

        expect(result[:type]).to eq("html")
        expect(result[:component]).to eq("WysiwygEditor")
      end
    end

    context "with full config" do
      let(:config) do
        {
          type: :text,
          label: "Page Title",
          hint: "The main title for this page",
          placeholder: "Enter title...",
          required: true,
          max_length: 80,
          group: :titles,
          paired_with: :subtitle,
          order: 1
        }
      end

      it "includes all provided fields" do
        result = described_class.build_field_definition(:title, config)

        expect(result[:name]).to eq("title")
        expect(result[:type]).to eq("text")
        expect(result[:label]).to eq("Page Title")
        expect(result[:hint]).to eq("The main title for this page")
        expect(result[:placeholder]).to eq("Enter title...")
        expect(result[:required]).to be true
        expect(result[:group]).to eq(:titles)
        expect(result[:paired_with]).to eq(:subtitle)
        expect(result[:order]).to eq(1)
      end

      it "includes validation from config" do
        result = described_class.build_field_definition(:title, config)

        expect(result[:validation]).to include(max_length: 80)
      end
    end

    context "with content guidance" do
      it "includes explicit content guidance" do
        config = {
          content_guidance: {
            recommended_length: "40-60 characters",
            seo_tip: "Include primary keyword"
          }
        }

        result = described_class.build_field_definition(:title, config)

        expect(result[:content_guidance]).to include(
          recommended_length: "40-60 characters",
          seo_tip: "Include primary keyword"
        )
      end

      it "adds preset guidance for title fields" do
        result = described_class.build_field_definition(:section_title, {})

        expect(result[:content_guidance]).to include(:recommended_length)
        expect(result[:content_guidance]).to include(:seo_tip)
      end

      it "adds preset guidance for description fields" do
        result = described_class.build_field_definition(:meta_description, {})

        expect(result[:content_guidance]).to include(:recommended_length)
      end

      it "adds guidance for image fields" do
        result = described_class.build_field_definition(:background_image, {})

        expect(result[:content_guidance]).to include(:best_practice)
      end
    end

    context "with select type" do
      it "includes choices in options" do
        config = {
          type: :select,
          choices: [
            { value: "light", label: "Light" },
            { value: "dark", label: "Dark" }
          ]
        }

        result = described_class.build_field_definition(:style, config)

        expect(result[:options][:choices]).to eq(config[:choices])
      end
    end

    context "with image type" do
      it "includes default image options" do
        result = described_class.build_field_definition(:photo, { type: :image })

        expect(result[:options]).to include(:accept)
        expect(result[:options]).to include(:max_size_mb)
      end

      it "allows overriding image options" do
        config = {
          type: :image,
          aspect_ratio: "16:9",
          recommended_size: "1920x1080"
        }

        result = described_class.build_field_definition(:hero_image, config)

        expect(result[:options][:aspect_ratio]).to eq("16:9")
        expect(result[:options][:recommended_size]).to eq("1920x1080")
      end
    end

    context "with faq_array type" do
      it "includes item schema" do
        result = described_class.build_field_definition(:faq_items, { type: :faq_array })

        expect(result[:item_schema]).to be_present
        expect(result[:item_schema]).to have_key(:question)
        expect(result[:item_schema]).to have_key(:answer)
      end
    end

    context "with array type and custom item schema" do
      it "builds item schema from config" do
        config = {
          type: :array,
          item_schema: {
            name: { type: :text, label: "Name", required: true },
            role: { type: :text, label: "Role" }
          }
        }

        result = described_class.build_field_definition(:members, config)

        expect(result[:item_schema]).to be_present
        expect(result[:item_schema][:name][:type]).to eq("text")
        expect(result[:item_schema][:role][:type]).to eq("text")
      end
    end

    context "with default values" do
      it "includes default in options" do
        config = { type: :select, default: "primary" }

        result = described_class.build_field_definition(:style, config)

        expect(result[:options][:default]).to eq("primary")
      end
    end
  end

  describe ".build_for_page_part" do
    context "with modern hash-based fields" do
      it "builds schema for heroes/hero_centered" do
        result = described_class.build_for_page_part("heroes/hero_centered")

        expect(result).to have_key(:fields)
        expect(result).to have_key(:groups)
        expect(result[:fields]).to be_an(Array)
        expect(result[:groups]).to be_an(Array)
      end

      it "includes field groups" do
        result = described_class.build_for_page_part("heroes/hero_centered")

        group_keys = result[:groups].map { |g| g[:key] }
        expect(group_keys).to include("titles", "cta", "media")
      end

      it "includes proper field metadata" do
        result = described_class.build_for_page_part("heroes/hero_centered")

        title_field = result[:fields].find { |f| f[:name] == "title" }
        expect(title_field[:type]).to eq("text")
        expect(title_field[:required]).to be true
        expect(title_field[:hint]).to be_present
        expect(title_field[:content_guidance]).to be_present
      end
    end

    context "with legacy array-based fields" do
      it "builds schema for legacy page parts" do
        # heroes/hero_split still uses array format
        result = described_class.build_for_page_part("heroes/hero_split")

        expect(result).to have_key(:fields)
        expect(result).to have_key(:groups)
        expect(result[:fields]).to be_an(Array)
        expect(result[:groups]).to eq([])
      end

      it "infers types for legacy fields" do
        result = described_class.build_for_page_part("heroes/hero_split")

        image_field = result[:fields].find { |f| f[:name] == "image" }
        expect(image_field[:type]).to eq("image")
      end
    end

    context "with unknown page part" do
      it "returns nil for nonexistent page part" do
        result = described_class.build_for_page_part("nonexistent/part")

        expect(result).to be_nil
      end
    end
  end

  describe "CONTENT_GUIDANCE_PRESETS" do
    it "has preset for title" do
      expect(described_class::CONTENT_GUIDANCE_PRESETS[:title]).to include(:recommended_length)
    end

    it "has preset for description" do
      expect(described_class::CONTENT_GUIDANCE_PRESETS[:description]).to include(:recommended_length)
    end

    it "has preset for cta_button" do
      expect(described_class::CONTENT_GUIDANCE_PRESETS[:cta_button]).to include(:best_practice)
    end

    it "has preset for image" do
      expect(described_class::CONTENT_GUIDANCE_PRESETS[:image]).to include(:best_practice)
    end
  end

  describe "field type defaults" do
    it "has max_length validation for text type" do
      type_config = described_class::FIELD_TYPES[:text]
      expect(type_config[:default_validation][:max_length]).to eq(255)
    end

    it "has max_length validation for textarea type" do
      type_config = described_class::FIELD_TYPES[:textarea]
      expect(type_config[:default_validation][:max_length]).to eq(5000)
    end

    it "has toolbar options for html type" do
      type_config = described_class::FIELD_TYPES[:html]
      expect(type_config[:default_options][:toolbar]).to include("bold", "italic", "link")
    end

    it "has pattern validation for email type" do
      type_config = described_class::FIELD_TYPES[:email]
      expect(type_config[:default_validation][:pattern]).to be_present
    end

    it "has pattern validation for url type" do
      type_config = described_class::FIELD_TYPES[:url]
      expect(type_config[:default_validation][:pattern]).to be_present
    end

    it "has accept options for image type" do
      type_config = described_class::FIELD_TYPES[:image]
      expect(type_config[:default_options][:accept]).to include("image/jpeg", "image/png")
    end

    it "has item_schema for faq_array type" do
      type_config = described_class::FIELD_TYPES[:faq_array]
      expect(type_config[:item_schema]).to have_key(:question)
      expect(type_config[:item_schema]).to have_key(:answer)
    end
  end
end
