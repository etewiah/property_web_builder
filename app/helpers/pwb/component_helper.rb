module Pwb
  module ComponentHelper
    def page_component(component_name, components_data)
      if components_data.include? component_name
       render :partial => "pwb/components/#{component_name}", :locals => {}
      end
    end

  end
end
