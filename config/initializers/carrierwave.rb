CarrierWave.configure do |config|
  aws_access_key_id = Rails.application.secrets.aws_access_key_id || "dummy"
  aws_secret_access_key = Rails.application.secrets.aws_secret_access_key || "dummy"
  # defaulting to dummy above ensures app will start
  # even though uploading will not work
  config.fog_provider = 'fog/aws'                        # required
  config.fog_credentials = {
    provider:              'AWS',                        # required
    aws_access_key_id:     aws_access_key_id,                        # required
    aws_secret_access_key: aws_secret_access_key,                        # required
    region:                'eu-west-1',                  # optional, defaults to 'us-east-1'
    # host:                  's3.example.com',             # optional, defaults to nil
    # endpoint:              'https://s3.example.com:8080' # optional, defaults to nil
  }
  config.fog_directory  = 'pwb'                          # required
  # config.fog_public     = false                                        # optional, defaults to true
  config.fog_attributes = { 'Cache-Control' => "max-age=#{365.day.to_i}" } # optional, defaults to {}
end
