# https://til.codes/testing-carrierwave-file-uploads-with-rspec-and-factorygirl/
FactoryGirl.define do
  factory :pwb_content_photo, class: 'Pwb::ContentPhoto' do
    path_to_file = Pwb::Engine.root.join("db/example_images/flat_balcony.jpg")
    # photo Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, '/spec/fixtures/myfiles/myfile.jpg')))
  end
end
