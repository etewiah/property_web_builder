module PwbTenant
  class Prop < Pwb::Prop
    include PwbTenant::ScopedModel
  end
end
