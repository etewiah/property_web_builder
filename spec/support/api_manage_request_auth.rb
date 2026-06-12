# frozen_string_literal: true

# ApiManage::V1 endpoints require an authenticated user with access to the
# current website (see ApiManage::V1::BaseController#require_user!).
#
# This helper wraps the standard request-spec HTTP verbs (get/post/patch/put/
# delete) to automatically send the `X-User-Email` header for the
# `manage_api_user` defined in each spec, so existing request specs don't need
# to thread auth headers through every call.
module ApiManageRequestAuthHelpers
  %i[get post patch put delete].each do |verb|
    define_method(verb) do |path, **kwargs|
      if respond_to?(:manage_api_user, true)
        kwargs[:headers] = (kwargs[:headers] || {}).merge('X-User-Email' => manage_api_user.email)
      end
      super(path, **kwargs)
    end
  end
end

RSpec.configure do |config|
  config.include ApiManageRequestAuthHelpers, file_path: %r{spec/requests/api_manage}
end
