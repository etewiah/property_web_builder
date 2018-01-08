# A sample Guardfile
# More info at https://github.com/guard/guard#readme

## Uncomment and set this to only include directories you want to watch
# directories %w(app lib config test spec features) \
#  .select{|d| Dir.exists?(d) ? d : UI.warning("Directory #{d} does not exist")}

## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"

# guard :bundler do
#   require 'guard/bundler'
#   require 'guard/bundler/verify'
#   helper = Guard::Bundler::Verify.new

#   files = ['Gemfile']
#   files += Dir['*.gemspec'] if files.any? { |f| helper.uses_gemspec?(f) }

#   # Assume files are symlinked from somewhere
#   files.each { |file| watch(helper.real_path(file)) }
# end

# Note: The cmd option is now required due to the increasing number of ways
#       rspec may be run, below are examples of the most common uses.
#  * bundler: 'bundle exec rspec'
#  * bundler binstubs: 'bin/rspec'
#  * spring: 'bin/rspec' (This will use spring if running and you have
#                          installed the spring binstubs per the docs)
#  * zeus: 'zeus rspec' (requires the server to be started separately)
#  * 'just' rspec: 'rspec'

guard :rspec, cmd: "bundle exec rspec" do
  require "guard/rspec/dsl"
  dsl = Guard::RSpec::Dsl.new(self)

  # Feel free to open issues for suggestions and improvements

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper) { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)

  # Ruby files
  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)

  # Rails files
  rails = dsl.rails(view_extensions: %w(erb haml slim))
  dsl.watch_spec_files_for(rails.app_files)
  dsl.watch_spec_files_for(rails.views)

  watch(rails.controllers) do |m|
    [
      rspec.spec.call("routing/#{m[1]}_routing"),
      rspec.spec.call("controllers/#{m[1]}_controller"),
      rspec.spec.call("acceptance/#{m[1]}")
    ]
  end

  # Rails config changes
  watch(rails.spec_helper)     { rspec.spec_dir }
  watch(rails.routes)          { "#{rspec.spec_dir}/routing" }
  watch(rails.app_controller)  { "#{rspec.spec_dir}/controllers" }

  # Capybara features specs
  watch(rails.view_dirs)     { |m| rspec.spec.call("features/#{m[1]}") }
  watch(rails.layouts)       { |m| rspec.spec.call("features/#{m[1]}") }

  # Turnip features and steps
  watch(%r{^spec/acceptance/(.+)\.feature$})
  watch(%r{^spec/acceptance/steps/(.+)_steps\.rb$}) do |m|
    Dir[File.join("**/#{m[1]}.feature")][0] || "spec/acceptance"
  end
end

# guard 'zeus' do
#   require 'ostruct'

#   rspec = OpenStruct.new
#   rspec.spec_dir = 'spec'
#   rspec.spec = ->(m) { "#{rspec.spec_dir}/#{m}_spec.rb" }
#   rspec.spec_helper = "#{rspec.spec_dir}/spec_helper.rb"

#   # matchers
#   rspec.spec_files = /^#{rspec.spec_dir}\/.+_spec\.rb$/

#   # Ruby apps
#   ruby = OpenStruct.new
#   ruby.lib_files = /^(lib\/.+)\.rb$/

#   watch(rspec.spec_files)
#   watch(rspec.spec_helper) { rspec.spec_dir }
#   watch(ruby.lib_files) { |m| rspec.spec.call(m[1]) }

#   # Rails example
#   rails = OpenStruct.new
#   rails.app_files = /^app\/(.+)\.rb$/
#   rails.views_n_layouts = /^app\/(.+(?:\.erb|\.haml|\.slim))$/
#   rails.controllers = %r{^app/controllers/(.+)_controller\.rb$}

#   watch(rails.app_files) { |m| rspec.spec.call(m[1]) }
#   watch(rails.views_n_layouts) { |m| rspec.spec.call(m[1]) }
#   watch(rails.controllers) do |m|
#     [
#       rspec.spec.call("routing/#{m[1]}_routing"),
#       rspec.spec.call("controllers/#{m[1]}_controller"),
#       rspec.spec.call("acceptance/#{m[1]}")
#     ]
#   end

#   # TestUnit
#   # watch(%r|^test/(.*)_test\.rb$|)
#   # watch(%r|^lib/(.*)([^/]+)\.rb$|)     { |m| "test/#{m[1]}test_#{m[2]}.rb" }
#   # watch(%r|^test/test_helper\.rb$|)    { "test" }
#   # watch(%r|^app/controllers/(.*)\.rb$|) { |m| "test/functional/#{m[1]}_test.rb" }
#   # watch(%r|^app/models/(.*)\.rb$|)      { |m| "test/unit/#{m[1]}_test.rb" }
# end

guard :rubocop, all_on_start: true, cli: %w(-c .rubocop.yml) do
# rubocop app/controllers/pwb/api -c .rubocop.yml
# guard :rubocop, cli: %w(--format fuubar --format html -o ./tmp/rubocop_results.html), launchy: './tmp/rubocop_results.html' do
  # watch(%r{.+\.rb$})
  watch(%r|^app/(.*)\.rb$|)
  watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
end
