FactoryGirl.define do
  factory :pwb_authorization, class: Pwb::Authorization do
    user nil
    provider "MyString"
    uid "MyString"
  end
end