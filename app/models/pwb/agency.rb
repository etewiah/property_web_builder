module Pwb
  class Agency < ApplicationRecord
    before_create :confirm_singularity
    # has_many :users

    # foreign_key of primary_address_id is col here on agency
    # belongs_to :primary_address, :class_name => "MasterAddress", :foreign_key => 'primary_address_id'
    # belongs_to :secondary_address, :class_name => "MasterAddress", :foreign_key => 'secondary_address_id'

    # def show_contact_map
    #   return self.primary_address.present?
    # end

    def views_folder
      views_folder = "/pwb/themes/standard"
      # if self.site_template.present? && self.site_template.views_folder
      #   views_folder = self.site_template.views_folder
      # end
      return views_folder
    end


    private

    def confirm_singularity
      raise Exception.new("There can be only one.") if Agency.count > 0
    end
  end
end
