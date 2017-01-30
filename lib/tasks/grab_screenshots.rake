# # bundle exec rake app:pwb:homepage
# # http://blog.appsignal.com/2015/07/21/automated-screenshots-using-capybara.html
# require 'capybara/poltergeist'
# require 'capybara/rails'

# namespace :pwb do
#   BROWSER_WIDTH  = 1600
#   BROWSER_HEIGHT = 1200

#   Capybara.register_driver :poltergeist do |app|
#     Capybara::Poltergeist::Driver.new(app, {js_errors: false})
#   end

#   Capybara.default_driver = :poltergeist
#   include Capybara::DSL

#   def take_screenshot(path, name, convert_options={})
#     # Wait for JS to load data and so on
#     sleep 2
#     # retinafy_screen

#     t_file = tmp_file(path, name)
#     s_file = screenshot_file(path, name)
#     page.save_screenshot(t_file)
#     # byebug
#     # convert(
#     #   t_file,
#     #   s_file,
#     #   convert_options
#     # )
#     # optimize(s_file)
#   end

#   def retinafy_screen
#     # Zoom content to get retina screenshot
#     page.driver.execute_script('
#      body = document.getElementsByTagName("body")[0];
#      body.style["transform-origin"] = "top left";
#      body.style["transform"] = "scale(2)";
#   ')
#   end

#   def tmp_file(path, name)
#     Rails.root.join("tmp/#{path || 'root'}_#{name}.png")
#   end

#   def screenshot_file(path, name)
#     if path
#       Rails.root.join("uploads/#{path}/#{name}.png")
#     else
#       Rails.root.join("uploads/#{name}.png")
#     end
#   end

#   def url(path)
#     # "https://appsignal.com#{path}"
#     # "http://localhost:127.0.0.1:3000#{path}"
#     "https://propertywebbuilder.herokuapp.com#{path}"
#   end

#   def crop_arg(width, height, x=0, y=0)
#     "#{retina_size(width)}x#{retina_size(height)}+#{retina_size(x)}+#{retina_size(y)}"
#   end

#   def retina_size(size)
#     size * 2
#   end

#   def convert(from_file, to_file, args)
#     args_s = args.map do |key, value|
#       "-#{key} #{value}"
#     end.join(' ')
#     `convert #{from_file} #{args_s} #{to_file}`
#   end

#   def optimize(file)
#     `pngquant --force --output #{file} #{file}`
#   end

#   task :homepage do
#     visit url('/')
#     take_screenshot nil, 'intro', :crop => crop_arg(BROWSER_WIDTH, 650)
#   end


# end
