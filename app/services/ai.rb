# frozen_string_literal: true

# AI Services module for PropertyWebBuilder
#
# This file serves as the namespace loader for all AI-related services.
# It ensures error classes are loaded since they're all defined in
# a single file (error.rb) rather than individual files.
#
module Ai
  # Explicitly require error classes since they're all in one file
  # and Rails autoloading expects one constant per file.
  require_relative 'ai/error'
end
