module PwbTenant
  class Page < Pwb::Page
    include PwbTenant::ScopedModel
  end
end
