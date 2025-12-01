module PwbTenant
  class Content < Pwb::Content
    include PwbTenant::ScopedModel
  end
end
