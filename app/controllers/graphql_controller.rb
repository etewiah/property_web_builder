# DEPRECATED: This GraphQL API is deprecated as of December 2024.
# New integrations should use the REST API at /api/v1/ or /api_public/v1/
# See app/graphql/DEPRECATED.md for migration guidance.
#
class GraphqlController < Pwb::ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  protect_from_forgery with: :null_session

  include SubdomainTenant
  include LocalhostDefaultWebsite

  # Override the before_action from SubdomainTenant to use our custom method name
  skip_before_action :current_agency_and_website
  skip_before_action :check_unseeded_website
  skip_before_action :check_locked_website
  skip_before_action :nav_links
  skip_before_action :set_locale
  skip_before_action :set_theme_path
  skip_before_action :footer_content
  skip_before_action :set_current_website_from_request
  skip_around_action :connect_to_tenant_shard
  before_action :set_current_website
  before_action :require_current_website!
  around_action :connect_to_graphql_tenant_shard

  def execute
    # Log deprecation warning (using Rails.logger as ActiveSupport::Deprecation.warn is private in Rails 8)
    Rails.logger.warn(
      "[DEPRECATED] GraphQL API is deprecated. Please migrate to REST API at /api_public/v1/. " \
      "See app/graphql/DEPRECATED.md for migration guidance."
    )

    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      # Query context goes here, for example:
      # current_user: current_user,
      session: session,
      current_user: current_user,
      request_url: request.referer,
      request_host: request.host,
      request_ip: request.ip,
      request_user_agent: request.user_agent,
    }
    result = StandalonePwbSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  def connect_to_graphql_tenant_shard
    set_current_website if Pwb::Current.website.blank?

    shard = Pwb::Current.website&.database_shard || :default
    PwbTenant::ApplicationRecord.connected_to(shard: shard, role: :writing) do
      yield
    end
  ensure
    ActsAsTenant.current_tenant = nil
  end

  def set_current_website
    Pwb::Current.website = website_from_slug_header || Pwb::Website.find_by_host(request.host.to_s.downcase) || localhost_default_website
    ActsAsTenant.current_tenant = Pwb::Current.website
  end

  def require_current_website!
    return if Pwb::Current.website.present?

    render json: {
      errors: [{ message: 'Website context required. Provide X-Website-Slug or use a valid tenant host.' }],
      data: {}
    }, status: :bad_request
  end

  # gets current user from token stored in the session
  def current_user
    return nil
    # https://www.howtographql.com/graphql-ruby/4-authentication/
    # TODO: implement this
    # return unless session[:token]
    # crypt = ActiveSupport::MessageEncryptor.new(Rails.application.credentials.secret_key_base.byteslice(0..31))
    # token = crypt.decrypt_and_verify session[:token]
    # user_id = token.gsub("user-id:", "").to_i
    # User.find user_id
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: 500
  end

  def website_from_slug_header
    slug = request.headers["X-Website-Slug"]
    return nil if slug.blank?

    Pwb::Website.find_by(slug: slug) || Pwb::Website.find_by_subdomain(slug)
  end
end
