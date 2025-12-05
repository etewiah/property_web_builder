module PwbTenant
  # Scoped Prop model for multi-tenant isolation
  class Prop < Pwb::Prop
    include PwbTenant::ScopedModel
  end
end
