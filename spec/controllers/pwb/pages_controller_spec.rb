require "rails_helper"

module Pwb
  RSpec.describe PagesController, type: :controller do
    routes { Rails.application.routes }

    before(:all) do
      @page = Pwb::Page.find_by_slug "home"
      unless @page.present?
        @page = FactoryBot.create(:pwb_page, slug: "home")
      end
      # TODO: - figure out how to do below with FactoryBot
      # @page.set_fragment_html "test", "en", "<h2>Sell Your Property with Us</h2>"
    end

    # This should return the minimal set of attributes required to create a valid
    # Welcome. As you add validations to Welcome, be sure to
    # adjust the attributes here as well.

    # let(:carousel_content_attributes) do
    #   {
    #     'tag' => 'landing-carousel'
    #   }
    # end

    let(:invalid_attributes) do
      skip("Add a hash of attributes invalid for your model")
    end

    # This should return the minimal set of values that should be in the session
    # in order to pass any filters (e.g. authentication) defined in
    # WelcomesController. Be sure to keep this updated too.
    let(:valid_session) { {} }

    describe "GET #show_page" do
      it "renders correct template" do
        # welcome = Content.create! carousel_content_attributes
        expect(get("show_page", params: {
                                  page_slug: "anything",
                                })).to render_template("pwb/pages/show")
      end
    end

    describe "GET #about-us" do
      it "renders correct template" do
        expect(get("show_page", params: {
                                  page_slug: "about-us",
                                })).to render_template("pwb/pages/show")
      end
    end

    after(:all) do
      @page.destroy
    end
  end
end
