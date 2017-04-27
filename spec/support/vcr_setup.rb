VCR.configure do |vc|
  #the directory where your cassettes will be saved
  vc.cassette_library_dir = 'spec/fixtures/vcr'

  # https://relishapp.com/vcr/vcr/v/3-0-3/docs/configuration/ignore-request
  vc.ignore_localhost = true

  vc.allow_http_connections_when_no_cassette = true
  # your HTTP request service.
  vc.hook_into :webmock
end
