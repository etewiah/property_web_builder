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
  end
end
