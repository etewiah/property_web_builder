FactoryGirl.define do
  factory :pwb_content, class: 'Pwb::Content' do
    key 'MyString'
    tag 'MyString'
    raw 'MyText'
    # trait :completed do
    #   # complete true
    #   completed_at { Time.now }
    # end

    # trait :not_completed do
    #   # complete false
    #   completed_at nil
    # end
  end
end
