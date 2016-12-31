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

    describe "#localized_link_to" do
      context 'for devise controller' do
        it "returns correct link" do
          # helper.stub(:params).and_return({controller: "devise/sessions",locale: "en"})
          allow(helper).to receive(:params).and_return({"controller" => "devise/sessions","locale" => "en"}.with_indifferent_access)
          # before(:all) { helper.stub!(:params).and_return(id: 1) }
          # assign(:title, "My Title")
          result = helper.localized_link_to "",{"locale" => "en"}
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
  end
end
