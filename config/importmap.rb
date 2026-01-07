# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/services", under: "services"

# Rails UJS for AJAX forms (replaces jquery_ujs without jQuery dependency)
pin "@rails/ujs", to: "https://ga.jspm.io/npm:@rails/ujs@7.1.3/app/assets/javascripts/rails-ujs.esm.js"

# Flowbite - UI components (Carousel, Dropdown)
# Using esm.sh for ES module compatibility with importmap
pin "flowbite", to: "https://esm.sh/flowbite@2.5.2/dist/flowbite.es.js"
