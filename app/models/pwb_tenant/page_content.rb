module PwbTenant
  class PageContent < Pwb::PageContent
    include PwbTenant::ScopedModel
  end
end
