FactoryBot.define do
  factory :pwb_content, class: 'Pwb::Content' do
    key 'MyString'
    tag 'MyString'
    raw 'MyText'
    trait :main_content do
      raw_en "<h2>Sell Your Property with Us</h2>"
    end
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
