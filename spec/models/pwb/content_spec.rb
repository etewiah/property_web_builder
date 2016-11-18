# require 'rails_helper'
require 'spec_helper'


module Pwb
  RSpec.describe Content, type: :model do
    # pending "add some examples to (or delete) #{__FILE__}"
    let(:content) { FactoryGirl.create(:pwb_content) }
      # create(:alchemy_element, name: 'headline', create_contents_after_create: true) }

    it "has a valid factory" do
      expect(content).to be_valid
    end

    # it "is invalid without a key" do
    #   ::FactoryGirl.build(:pwb_content, key: nil).should_not be_valid
    # end

  end
end
