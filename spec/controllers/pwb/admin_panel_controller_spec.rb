require 'rails_helper'

module Pwb
  RSpec.describe AdminPanelController, type: :controller do
    routes { Pwb::Engine.routes }

    describe 'GET #show' do
      it 'renders correct template' do
        expect(get(:show)).to render_template('pwb/admin_panel/show')
      end
    end

  end
end
