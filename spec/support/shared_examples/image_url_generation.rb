# frozen_string_literal: true

# Shared examples for image URL generation patterns.
# These ensure consistent URL generation across models that handle images.

RSpec.shared_examples 'generates direct CDN URLs' do
  let(:cdn_url) { 'https://cdn.example.com/test-image.jpg' }
  let(:variant_url) { 'https://cdn.example.com/test-image-variant.jpg' }

  it 'uses ActiveStorage url method for attached images' do
    # This verifies that the model calls image.url instead of rails_blob_url
    expect(attached_image).to receive(:url).and_return(cdn_url)
    result = subject.send(url_method)
    expect(result).to eq(cdn_url)
  end
end

RSpec.shared_examples 'supports external image URLs' do
  it 'returns external URL directly when external? is true' do
    allow(subject).to receive(:external?).and_return(true)
    allow(subject).to receive(:external_url).and_return('https://external.example.com/image.jpg')

    result = subject.send(url_method)
    expect(result).to eq('https://external.example.com/image.jpg')
  end
end

RSpec.shared_examples 'handles missing images gracefully' do
  it 'returns nil or empty string when no image is attached' do
    result = subject.send(url_method)
    expect(result).to satisfy { |v| v.nil? || v == '' }
  end
end
