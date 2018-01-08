require 'i18n/backend/active_record'
# I18n.backend = I18n::Backend::ActiveRecord.new
Translation  = I18n::Backend::ActiveRecord::Translation

# if Translation.table_exists?
# in the context of an engine, above returns false
# even when the table exists
if ActiveRecord::Base.connection.data_source_exists? 'translations'
  I18n.backend = I18n::Backend::ActiveRecord.new

  I18n::Backend::ActiveRecord.send(:include, I18n::Backend::Memoize)
  I18n::Backend::ActiveRecord.send(:include, I18n::Backend::Flatten)
  I18n::Backend::Simple.send(:include, I18n::Backend::Memoize)
  I18n::Backend::Simple.send(:include, I18n::Backend::Pluralization)

  I18n.backend = I18n::Backend::Chain.new(I18n::Backend::Simple.new, I18n.backend)
end




# https://blog.codeship.com/the-json-api-spec/
# https://github.com/rails-api/active_model_serializers/issues/1027
# might need to define custom mime type at some point as per above
# api_mime_types = %W(
#   application/vnd.api+json
#   text/x-json
#   application/json
# )
# Mime::Type.register 'application/vnd.api+json', :json, api_mime_types