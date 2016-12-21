module Pwb
  class Theme < ActiveHash::Base
    include ActiveHash::Associations
    has_one :agency, :foreign_key => "site_template_id", :class_name => "Pwb::Agency"

    self.data = [
      {:id => 1, :name => "default"},
      {:id => 2, :name => "chic"}
    ]
  end
end
