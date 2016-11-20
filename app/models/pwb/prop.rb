module Pwb
  class Prop < ApplicationRecord
    translates :title, :description
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar]

    scope :for_rent, -> () { where('for_rent_short_term OR for_rent_long_term') }
    # couldn't do above if for_rent_short_term was a flatshihtzu boolean
    scope :for_sale, -> () { where for_sale: true }
    scope :visible, -> () { where visible: true }

  end
end
