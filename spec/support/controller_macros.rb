module ControllerMacros
  # def login_admin
  #   before(:each) do
  #     @request.env["devise.mapping"] = Devise.mappings[:admin]
  #     sign_in FactoryBot.create(:admin) # Using factory girl as an example
  #   end
  # end

  def login_non_admin_user
    before(:each) do
      @request.env["devise.mapping"] = ::Devise.mappings[:user]
      @test_website = Pwb::Website.first || FactoryBot.create(:pwb_website)
      user = FactoryBot.create(:pwb_user, email: 'non_admin@pwb.com', password: '123456', admin: false, website: @test_website)
      # user.confirm! # or set a confirmed_at inside the factory. Only necessary if you are using the "confirmable" module
      sign_in user, scope: :user
    end
  end

  def login_admin_user
    before(:each) do
      @request.env["devise.mapping"] = ::Devise.mappings[:user]
      @test_website = Pwb::Website.first || FactoryBot.create(:pwb_website)
      # Use :admin trait to properly create user with membership
      user = FactoryBot.create(:pwb_user, :admin, email: 'admin@pwb.com', password: '123456', website: @test_website)
      # user.confirm! # or set a confirmed_at inside the factory. Only necessary if you are using the "confirmable" module
      # Ensure the controller can find the correct website
      allow(Pwb::Current).to receive(:website).and_return(@test_website)
      sign_in user, scope: :user
    end
  end
end
