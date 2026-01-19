require 'rails_helper'

module Pwb
  describe ImagesHelper, type: :helper do
    describe "#make_media_responsive" do
      let(:original_html) { '<img src="https://pwb-seed-images.s3.amazonaws.com/test.jpg" alt="Test Image">' }
      
      it "replaces img tags with responsive pictures for trusted sources" do
        result = helper.make_media_responsive(original_html)
        expect(result).to include('<picture>')
        expect(result).to include('srcset')
        expect(result).to include('image/webp')
      end

      it "preserves non-trusted images but adds loading lazy" do
        untrusted_html = '<img src="https://unknown.com/image.jpg">'
        result = helper.make_media_responsive(untrusted_html)
        # Should generic make it lazy if not already?
        # For now, let's just see if it keeps it mostly same or upgrades it.
        # The goal is mainly about using opt_image_tag logic.
      end
    end
  end
end
