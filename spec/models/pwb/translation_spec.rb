require 'rails_helper'

module I18n::Backend
  RSpec.describe ActiveRecord::Translation, type: :model do
    # pending "add some examples to (or delete) #{__FILE__}"
    let(:translation) { FactoryGirl.create(:pwb_translation) }
    it 'has a valid factory' do
      expect(translation).to be_valid
    end
  end
end
