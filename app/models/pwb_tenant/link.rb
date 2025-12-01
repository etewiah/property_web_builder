module PwbTenant
  class Link < Pwb::Link
    include PwbTenant::ScopedModel
  end
end
