# frozen_string_literal: true

require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the ApplicationHelper. For example:
#
# describe ApplicationHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
module Pwb
  RSpec.describe ApplicationHelper, type: :helper do
    describe "#company_display_name" do
      let(:website) { instance_double(Pwb::Website) }
      let(:agency) { instance_double(Pwb::Agency) }

      before do
        helper.instance_variable_set(:@current_website, website)
        helper.instance_variable_set(:@current_agency, agency)
      end

      context "when agency display_name is present" do
        it "returns agency display_name (highest priority)" do
          allow(agency).to receive(:display_name).and_return("Agency Display Name")
          allow(agency).to receive(:company_name).and_return("Agency Company")
          allow(website).to receive(:company_display_name).and_return("Website Company")

          expect(helper.company_display_name).to eq("Agency Display Name")
        end
      end

      context "when agency display_name is blank but company_name is present" do
        it "returns agency company_name" do
          allow(agency).to receive(:display_name).and_return("")
          allow(agency).to receive(:company_name).and_return("Agency Company")
          allow(website).to receive(:company_display_name).and_return("Website Company")

          expect(helper.company_display_name).to eq("Agency Company")
        end
      end

      context "when agency fields are blank but website company_display_name is present" do
        it "returns website company_display_name (deprecated fallback)" do
          allow(agency).to receive(:display_name).and_return(nil)
          allow(agency).to receive(:company_name).and_return(nil)
          allow(website).to receive(:company_display_name).and_return("Website Company")

          expect(helper.company_display_name).to eq("Website Company")
        end
      end

      context "when all fields are blank" do
        it "returns the default value" do
          allow(agency).to receive(:display_name).and_return(nil)
          allow(agency).to receive(:company_name).and_return(nil)
          allow(website).to receive(:company_display_name).and_return(nil)

          expect(helper.company_display_name).to eq("Real Estate")
          expect(helper.company_display_name("My Default")).to eq("My Default")
        end
      end

      context "when agency is nil" do
        before do
          helper.instance_variable_set(:@current_agency, nil)
        end

        it "falls back to website company_display_name" do
          allow(website).to receive(:company_display_name).and_return("Website Company")

          expect(helper.company_display_name).to eq("Website Company")
        end
      end
    end

    describe "#company_legal_name" do
      let(:website) { instance_double(Pwb::Website) }
      let(:agency) { instance_double(Pwb::Agency) }

      before do
        helper.instance_variable_set(:@current_website, website)
        helper.instance_variable_set(:@current_agency, agency)
      end

      context "when agency company_name is present" do
        it "returns agency company_name (highest priority)" do
          allow(agency).to receive(:company_name).and_return("Agency Legal Name")
          allow(agency).to receive(:display_name).and_return("Agency Display")
          allow(website).to receive(:company_display_name).and_return("Website Company")

          expect(helper.company_legal_name).to eq("Agency Legal Name")
        end
      end

      context "when agency company_name is blank but display_name is present" do
        it "returns agency display_name" do
          allow(agency).to receive(:company_name).and_return("")
          allow(agency).to receive(:display_name).and_return("Agency Display")
          allow(website).to receive(:company_display_name).and_return("Website Company")

          expect(helper.company_legal_name).to eq("Agency Display")
        end
      end

      context "when agency fields are blank" do
        it "falls back to website company_display_name (deprecated)" do
          allow(agency).to receive(:company_name).and_return(nil)
          allow(agency).to receive(:display_name).and_return(nil)
          allow(website).to receive(:company_display_name).and_return("Website Company")

          expect(helper.company_legal_name).to eq("Website Company")
        end
      end
    end

    describe "#localized_link_to" do
      context 'for devise controller' do
        it "returns correct link" do
          # helper.stub(:params).and_return({controller: "devise/sessions",locale: "en"})
          allow(helper).to receive(:params).and_return({"controller" => "devise/sessions", "locale" => "en"}.with_indifferent_access)
          # before(:all) { helper.stub!(:params).and_return(id: 1) }
          # assign(:title, "My Title")
          result = helper.localized_link_to "", {"locale" => "en"}
          expect(result).to have_link '', href: '/en'
        end
      end
      # context 'for non devise controller' do
      #   it "returns correct link" do
      #     allow(helper).to receive(:params).and_return({"locale" => "en"})
      #     result = helper.localized_link_to "",{"locale" => "en"}
      #     expect(result).to have_link '', href: '/en'
      #   end
      # end
    end

    describe "#tailwind_inmo_input" do
      it "returns correct html" do
        # I18n.t is called directly, so we stub it at the I18n level
        allow(I18n).to receive(:t).with("placeHolders.name").and_return("Your Name")
        allow(I18n).to receive(:t).with(:name).and_return("Name")

        # Mock form object - the placeholder is passed to text_field
        f = double("form")
        allow(f).to receive(:text_field).and_return("<input type='text' name='name' placeholder='Your Name' />")

        result = helper.tailwind_inmo_input(f, :name, "name", "text", true)

        expect(result).to include("Name") # label
        expect(result).to include("text-red-500") # required indicator
        expect(result).to include("<input") # input element
      end
    end

    describe "#tailwind_inmo_textarea" do
      it "returns correct html" do
        # I18n.t is called directly, so we stub it at the I18n level
        allow(I18n).to receive(:t).with("placeHolders.message").and_return("Your Message")
        allow(I18n).to receive(:t).with(:message).and_return("Message")

        # Mock form object
        f = double("form")
        allow(f).to receive(:text_area).and_return("<textarea name='message' placeholder='Your Message'></textarea>")

        result = helper.tailwind_inmo_textarea(f, :message, "message", "text", false)

        expect(result).to include("Message") # label
        expect(result).not_to include("text-red-500") # not required
        expect(result).to include("<textarea") # textarea element
      end
    end

    describe "#format_bathroom_count" do
      it "returns empty string for nil" do
        expect(helper.format_bathroom_count(nil)).to eq("")
      end

      it "removes unnecessary decimal for whole numbers" do
        expect(helper.format_bathroom_count(2.0)).to eq("2")
        expect(helper.format_bathroom_count(1.0)).to eq("1")
        expect(helper.format_bathroom_count(3.0)).to eq("3")
      end

      it "preserves decimal for half values" do
        expect(helper.format_bathroom_count(1.5)).to eq("1.5")
        expect(helper.format_bathroom_count(2.5)).to eq("2.5")
      end

      it "handles integer input" do
        expect(helper.format_bathroom_count(2)).to eq("2")
        expect(helper.format_bathroom_count(0)).to eq("0")
      end

      it "preserves other decimal values" do
        expect(helper.format_bathroom_count(1.25)).to eq("1.25")
        expect(helper.format_bathroom_count(2.75)).to eq("2.75")
      end
    end

    describe "#format_bedroom_count" do
      it "returns empty string for nil" do
        expect(helper.format_bedroom_count(nil)).to eq("")
      end

      it "removes unnecessary decimal for whole numbers" do
        expect(helper.format_bedroom_count(3.0)).to eq("3")
        expect(helper.format_bedroom_count(5.0)).to eq("5")
      end

      it "preserves decimal for fractional values" do
        expect(helper.format_bedroom_count(2.5)).to eq("2.5")
      end

      it "handles integer input" do
        expect(helper.format_bedroom_count(4)).to eq("4")
        expect(helper.format_bedroom_count(0)).to eq("0")
      end
    end

    describe "#property_price" do
      let(:website) { instance_double(Pwb::Website, default_currency: 'EUR', available_currencies: []) }
      let(:property) { double("property") }

      before do
        helper.instance_variable_set(:@current_website, website)
        allow(helper).to receive(:current_website).and_return(website)
        allow(helper).to receive(:session).and_return({})
        allow(helper).to receive(:cookies).and_return({})
      end

      context "for sale properties" do
        let(:price) { Money.new(25000000, 'EUR') } # €250,000

        before do
          allow(property).to receive(:contextual_price).with("for_sale").and_return(price)
        end

        it "returns formatted price without /month suffix" do
          result = helper.property_price(property, "for_sale")
          expect(result).to include('€')
          expect(result).to include('250,000')
          expect(result).not_to include('/month')
        end
      end

      context "for rent properties" do
        let(:price) { Money.new(220000, 'EUR') } # €2,200

        before do
          allow(property).to receive(:contextual_price).with("for_rent").and_return(price)
        end

        it "appends /month suffix to rental price" do
          result = helper.property_price(property, "for_rent")
          expect(result).to include('€')
          expect(result).to include('2,200')
          expect(result).to include('/month')
        end

        it "handles string operation_type" do
          result = helper.property_price(property, "for_rent")
          expect(result).to include('/month')
        end

        it "handles symbol operation_type converted to string" do
          # The helper uses operation_type.to_s == "for_rent"
          allow(property).to receive(:contextual_price).with(:for_rent).and_return(price)
          result = helper.property_price(property, :for_rent)
          expect(result).to include('/month')
        end
      end

      context "with nil or zero price" do
        it "returns nil for nil price" do
          allow(property).to receive(:contextual_price).with("for_rent").and_return(nil)
          result = helper.property_price(property, "for_rent")
          expect(result).to be_nil
        end

        it "returns nil for zero price" do
          zero_price = Money.new(0, 'EUR')
          allow(property).to receive(:contextual_price).with("for_rent").and_return(zero_price)
          result = helper.property_price(property, "for_rent")
          expect(result).to be_nil
        end
      end

      context "with currency conversion" do
        let(:website_with_conversion) do
          instance_double(Pwb::Website,
            default_currency: 'EUR',
            available_currencies: ['USD'],
            subdomain: 'test'
          )
        end
        let(:price) { Money.new(150000, 'EUR') } # €1,500

        before do
          helper.instance_variable_set(:@current_website, website_with_conversion)
          allow(helper).to receive(:current_website).and_return(website_with_conversion)
          allow(helper).to receive(:session).and_return({ preferred_currency: 'USD' })
          allow(property).to receive(:contextual_price).with("for_rent").and_return(price)
          # Mock the conversion service to return converted price
          allow(Pwb::ExchangeRateService).to receive(:convert).and_return(Money.new(165000, 'USD'))
        end

        it "inserts /month before conversion span for rentals" do
          result = helper.property_price(property, "for_rent")
          expect(result).to include('/month')
          # The /month should come before the conversion span
          expect(result).to match(%r{/month.*<span})
        end
      end
    end

    describe "#localized_buy_path" do
      before do
        # Mock the route helper
        allow(helper).to receive(:buy_path).with(locale: :en).and_return('/en/buy')
        allow(helper).to receive(:buy_path).with(locale: :es).and_return('/es/buy')
      end

      it "returns path with current locale" do
        allow(I18n).to receive(:locale).and_return(:en)
        expect(helper.localized_buy_path).to eq('/en/buy')
      end

      it "returns path with Spanish locale" do
        allow(I18n).to receive(:locale).and_return(:es)
        expect(helper.localized_buy_path).to eq('/es/buy')
      end
    end

    describe "#localized_rent_path" do
      before do
        allow(helper).to receive(:rent_path).with(locale: :en).and_return('/en/rent')
        allow(helper).to receive(:rent_path).with(locale: :fr).and_return('/fr/rent')
      end

      it "returns path with current locale" do
        allow(I18n).to receive(:locale).and_return(:en)
        expect(helper.localized_rent_path).to eq('/en/rent')
      end

      it "returns path with French locale" do
        allow(I18n).to receive(:locale).and_return(:fr)
        expect(helper.localized_rent_path).to eq('/fr/rent')
      end
    end

    describe "#localized_contact_path" do
      before do
        allow(helper).to receive(:contact_us_path).with(locale: :en).and_return('/en/contact')
        allow(helper).to receive(:contact_us_path).with(locale: :de).and_return('/de/contact')
      end

      it "returns contact path with current locale" do
        allow(I18n).to receive(:locale).and_return(:en)
        expect(helper.localized_contact_path).to eq('/en/contact')
      end

      it "returns contact path with German locale" do
        allow(I18n).to receive(:locale).and_return(:de)
        expect(helper.localized_contact_path).to eq('/de/contact')
      end
    end

    describe "#localized_home_path" do
      before do
        allow(helper).to receive(:home_path).with(locale: :en).and_return('/en')
        allow(helper).to receive(:home_path).with(locale: :nl).and_return('/nl')
      end

      it "returns home path with current locale" do
        allow(I18n).to receive(:locale).and_return(:en)
        expect(helper.localized_home_path).to eq('/en')
      end

      it "returns home path with Dutch locale" do
        allow(I18n).to receive(:locale).and_return(:nl)
        expect(helper.localized_home_path).to eq('/nl')
      end
    end
  end
end
