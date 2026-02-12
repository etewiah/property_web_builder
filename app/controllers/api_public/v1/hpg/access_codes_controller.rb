# frozen_string_literal: true

module ApiPublic
  module V1
    module Hpg
      class AccessCodesController < BaseController
        # POST /api_public/v1/hpg/access_codes/check
        def check
          disable_cache!

          code = params[:code].to_s.strip
          valid = current_website.access_codes.valid.exists?(code: code)

          render json: { valid: valid, code: code }
        end
      end
    end
  end
end
