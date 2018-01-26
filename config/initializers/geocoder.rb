if Rails.env.test?
  Geocoder.configure(:lookup => :test)
  # Particular Look up
  Geocoder::Lookup::Test.add_stub(
    "New York, NY", [
      {
        'latitude'     => 40.7143528,
        'longitude'    => -74.0059731,
        'address'      => 'New York, NY, USA',
        'state'        => 'New York',
        'state_code'   => 'NY',
        'country'      => 'United States',
        'country_code' => 'US'
      }
    ]
  )
  #default stub
  Geocoder::Lookup::Test.set_default_stub(
    [
      {
        'latitude'     => 40.7143528,
        'longitude'    => -74.0059731,
        'address'      => 'New York, NY, USA',
        'state'        => 'New York',
        'state_code'   => 'NY',
        'country'      => 'United States',
        'country_code' => 'US'
      }
    ]
  )
else
  Geocoder.configure(
    :timeout      => 3,           # geocoding service timeout (secs)
    :lookup       => :google,     # name of geocoding service (symbol)
    :language     => :en,         # ISO-639 language code
    :units     => :mi,       # :km for kilometers or :mi for miles
    :distances => :linear    # :spherical or :linear
    # Geocoding options
    # timeout: 3,                 # geocoding service timeout (secs)
    # lookup: :google,            # name of geocoding service (symbol)
    # language: :en,              # ISO-639 language code
    # use_https: false,           # use HTTPS for lookup requests? (if supported)
    # http_proxy: nil,            # HTTP proxy server (user:pass@host:port)
    # https_proxy: nil,           # HTTPS proxy server (user:pass@host:port)
    # api_key: nil,               # API key for geocoding service
    # cache: nil,                 # cache object (must respond to #[], #[]=, and #keys)
    # cache_prefix: 'geocoder:',  # prefix (string) to use for all cache keys

    # Exceptions that should not be rescued by default
    # (if you want to implement custom error handling);
    # supports SocketError and Timeout::Error
    # always_raise: [],

    # Calculation options
    # units: :mi,                 # :km for kilometers or :mi for miles
    # distances: :linear          # :spherical or :linear
  )
end
