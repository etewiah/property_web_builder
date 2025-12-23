// Entry point for the application's JavaScript
// This file is loaded via importmap in the application layout

// Rails UJS for AJAX forms (replaces jquery_ujs)
import Rails from "@rails/ujs"
Rails.start()

import "controllers"
