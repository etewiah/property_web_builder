require 'active_record'

module I18n
  module Backend
    # ActiveRecord model used to store actual translations to the database.
    #
    # This model expects a table like the following to be already set up in
    # your the database:
    #
    #   create_table :translations do |t|
    #     t.string :locale
    #     t.string :key
    #     t.text   :value
    #     t.text   :interpolations
    #     t.boolean :is_proc, :default => false
    #   end
    #
    # This model supports to named scopes :locale and :lookup. The :locale
    # scope simply adds a condition for a given locale:
    #
    #   I18n::Backend::ActiveRecord::Translation.locale(:en).all
    #   # => all translation records that belong to the :en locale
    #
    # The :lookup scope adds a condition for looking up all translations
    # that either start with the given keys (joined by an optionally given
    # separator or I18n.default_separator) or that exactly have this key.
    #
    #   # with translations present for :"foo.bar" and :"foo.baz"
    #   I18n::Backend::ActiveRecord::Translation.lookup(:foo)
    #   # => an array with both translation records :"foo.bar" and :"foo.baz"
    #
    #   I18n::Backend::ActiveRecord::Translation.lookup([:foo, :bar])
    #   I18n::Backend::ActiveRecord::Translation.lookup(:"foo.bar")
    #   # => an array with the translation record :"foo.bar"
    #
    # When the StoreProcs module was mixed into this model then Procs will
    # be stored to the database as Ruby code and evaluated when :value is
    # called.
    #
    #   Translation = I18n::Backend::ActiveRecord::Translation
    #   Translation.create \
    #     :locale => 'en'
    #     :key    => 'foo'
    #     :value  => lambda { |key, options| 'FOO' }
    #   Translation.find_by_locale_and_key('en', 'foo').value
    #   # => 'FOO'
    class ActiveRecord
      class Translation < ::ActiveRecord::Base
        TRUTHY_CHAR = "\001"
        FALSY_CHAR = "\002"

        self.table_name = 'translations'

        serialize :value
        serialize :interpolations, Array

        class << self
          def locale(locale)
            where(locale: locale.to_s)
          end

          def lookup(keys, *separator)
            column_name = connection.quote_column_name('key')
            keys = Array(keys).map!(&:to_s)

            unless separator.empty?
              warn "[DEPRECATION] Giving a separator to Translation.lookup is deprecated. " \
                   "You can change the internal separator by overwriting FLATTEN_SEPARATOR."
            end

            namespace = "#{keys.last}#{I18n::Backend::Flatten::FLATTEN_SEPARATOR}%"
            where("#{column_name} IN (?) OR #{column_name} LIKE ?", keys, namespace)
          end

          def available_locales
            Translation.distinct.pluck(:locale).map(&:to_sym)
          end
        end

        def interpolates?(key)
          interpolations.include?(key) if interpolations
        end

        def value
          value = read_attribute(:value)
          if is_proc
            Kernel.eval(value)
          elsif value == FALSY_CHAR
            false
          elsif value == TRUTHY_CHAR
            true
          else
            value
          end
        end

        def value=(value)
          if value === false
            value = FALSY_CHAR
          elsif value === true
            value = TRUTHY_CHAR
          end

          write_attribute(:value, value)
        end

        # alt names for key and value
        def i18n_key
          key
        end

        def i18n_value
          value
        end

        # https://quickleft.com/blog/keeping-your-json-response-lean-in-rails/
        def as_json(_options = {})
          super(only: [:id, :locale, :interpolations],
                methods: [:i18n_key, :i18n_value]
                )
        end
      end
    end
  end
end
