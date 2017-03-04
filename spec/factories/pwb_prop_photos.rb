# https://til.codes/testing-carrierwave-file-uploads-with-rspec-and-factorygirl/
FactoryGirl.define do
  factory :pwb_prop_photo, class: 'Pwb::PropPhoto' do
    path_to_file = Pwb::Engine.root.join("db/example_images/flat_balcony.jpg")
    image Rack::Test::UploadedFile.new(File.open(path_to_file))

    # File.join(Rails.root, '/spec/fixtures/myfiles/myfile.jpg')))
  end
end
