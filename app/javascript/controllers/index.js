// Import and register all Stimulus controllers from the controllers directory
// Controller files should be named like: hello_controller.js

import { application } from "./application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
