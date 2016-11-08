module Pwb
  class Content < ApplicationRecord
    translates :raw, :fallbacks_for_empty_translations => true
    globalize_accessors :locales => [:en, :ca, :es, :fr, :ar]

  end
end
