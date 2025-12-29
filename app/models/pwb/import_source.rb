# frozen_string_literal: true

# DEPRECATED: This file contains legacy RETS import source definitions.
# The RETS gem has been removed from the project (Dec 2024).
# MLS/RETS integration was experimental and never fully implemented.
# See docs/claude_thoughts/DEPRECATED_FEATURES.md for details.
#
# This file is kept for reference but the data is no longer functional.

module Pwb
  # https://github.com/zilkey/active_hash
  # @deprecated RETS sources are no longer functional - rets gem removed Dec 2024
  class ImportSource < ActiveHash::Base
    # DEPRECATED: These RETS sources are non-functional.
    # The rets gem has been removed from the project.
    self.data = [
      # DEPRECATED - RETS source (non-functional)
      {
        id: 1,
        source_type: "rets",  # DEPRECATED
        unique_name: "mris",
        import_mapper_name: "mls_mris",
        details: {
          login_url: "http://ptest.mris.com:6103/ptest/login",
          username: "MRISTEST",
          password: "",
          version: "RETS/1.7.2",
          agent: "RETSMD/1.0",
        },
        default_property_class: "ALL",
        displayName: "MRIS",
      },
      # DEPRECATED - RETS source (non-functional)
      {
        id: 2,
        source_type: "rets",  # DEPRECATED
        unique_name: "interealty",
        import_mapper_name: "mls_interealty",
        details: {
          login_url: "http://agdb.rets.interealty.com/Login.asmx/Login",
          username: "ACTRISBETA1",
          password: "",
          version: "RETS/1.5",
          agent: "ACTRISIDX/1.0",
        },
        default_property_class: "PROPERTY",
        displayName: "InterRealty",
      },
      # OData source removed - ruby_odata gem no longer supported
    ]

    # set_root_path "#{Rails.root}/config/client_setups"
    # # set_filename "client_setups"
    # use_multiple_files
    # set_filenames "default", "us"
  end
end
