module RequestSpecHelpers

  # https://github.com/plataformatec/devise/wiki/How-To:-sign-in-and-out-a-user-in-Request-type-specs-(specs-tagged-with-type:-:request)
  include Warden::Test::Helpers

  # def self.included(base)
  #   base.before(:each) { Warden.test_mode! }
  #   base.after(:each) { Warden.test_reset! }
  # end

  # def sign_in(resource)
  #   login_as(resource, scope: warden_scope(resource))
  # end

  # def sign_out(resource)
  #   logout(warden_scope(resource))
  # end

  # https://makandracards.com/makandra/37161-rspec-devise-how-to-sign-in-users-in-request-specs
  def sign_in(resource_or_scope, resource = nil)
    resource ||= resource_or_scope
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    login_as(resource, scope: scope)
  end

  def sign_out(resource_or_scope)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    logout(scope)
  end

  def response_body_as_json
    JSON.parse(response.body)
  end

  private

  def warden_scope(resource)
    resource.class.name.underscore.to_sym
  end

end
