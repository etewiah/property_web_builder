module PwbTenant
  class PagePart < Pwb::PagePart
    include PwbTenant::ScopedModel
  end
end
