require 'carrierwave/test/matchers'

module Pwb
  describe ContentPhotoUploader do
    include CarrierWave::Test::Matchers

    # let(:content_photo) { double('content_photo') }
    Rails.application.secrets.cloudinary_url = nil
    let(:content_photo) { FactoryBot.create(:pwb_content_photo) }

    let(:uploader) { ContentPhotoUploader.new(content_photo, :avatar) }

    before do
      ContentPhotoUploader.enable_processing = true

      # ContentPhotoUploader will use file upload depending on value of File.open(path_to_file)
      path_to_file = Pwb::Engine.root.join("db/example_images/flat_balcony.jpg")
      # photo.image = Pwb::Engine.root.join(photo_file).open
      File.open(path_to_file) { |f| uploader.store!(f) }
    end

    after do
      ContentPhotoUploader.enable_processing = false
      uploader.remove!
    end

    it 'has a valid factory' do
      expect(content_photo).to be_valid
    end

    it 'uses File storage' do
      expect(uploader._storage).to eq(CarrierWave::Storage::File)
    end
    # context 'the thumb version' do
    #   it "scales down a landscape image to be exactly 64 by 64 pixels" do
    #     expect(uploader.thumb).to have_dimensions(64, 64)
    #   end
    # end

    # context 'the small version' do
    #   it "scales down a landscape image to fit within 200 by 200 pixels" do
    #     expect(uploader.small).to be_no_larger_than(200, 200)
    #   end
    # end

    # it "makes the image readable only to the owner and not executable" do
    #   expect(uploader).to have_permissions(0600)
    # end

    # it "has the correct format" do
    #   expect(uploader).to be_format('png')
    # end
  end
end
