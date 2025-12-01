module PwbTenant
  class Agency < Pwb::Agency
    include PwbTenant::ScopedModel
  end
end
