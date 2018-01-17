module Pwb
	class Authorization < ActiveRecord::Base
	  belongs_to :user
	end
end