# https://til.codes/testing-carrierwave-file-uploads-with-rspec-and-factorygirl/
FactoryBot.define do
  factory :pwb_prop_photo, class: "Pwb::PropPhoto" do
    Rails.application.secrets.cloudinary_url = nil

    # Nov 2017 - getting this error:
    # ArgumentError: Missing `original_filename` for IO
    # from 2 lines below
    # path_to_file = Rails.root.join("db/example_images/flat_balcony.jpg")
    # image Rack::Test::UploadedFile.new(File.open(path_to_file))

    # seems to be to do with:
    # https://github.com/rack-test/rack-test/pull/209
    # https://github.com/rack-test/rack-test/issues/207

    # File.join(Rails.root, '/spec/fixtures/myfiles/myfile.jpg')))
  end
end
