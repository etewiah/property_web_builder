class GraphqlController < Pwb::ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  protect_from_forgery with: :null_session

  before_action :set_current_website

  def execute
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

  def set_current_website
    slug = request.headers["X-Website-Slug"]
    if slug.present?
      Pwb::Current.website = Pwb::Website.find_by(slug: slug)
    end

    # Fallback to default if not found or not provided
    Pwb::Current.website ||= Pwb::Website.unique_instance
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
end
