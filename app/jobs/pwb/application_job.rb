module Pwb
  # Base class for Pwb-namespaced jobs
  # Inherits retry/discard behavior from root ApplicationJob
  class ApplicationJob < ::ApplicationJob
  end
end
