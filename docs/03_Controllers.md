# Controllers

This section provides a detailed overview of the controllers used in the PropertyWebBuilder application. Each controller is described with its purpose and a summary of its main actions.

---

### ApplicationController (`app/controllers/pwb/application_controller.rb`)

The `ApplicationController` is the base controller for the application. All other controllers inherit from it.

**Purpose:**

*   To provide common functionality for all controllers, such as setting the locale, theme, and navigation links.
*   To ensure that the `@current_agency` and `@current_website` instance variables are available in all controllers.

**Before Actions:**

*   `current_agency_and_website`: Sets the `@current_agency` and `@current_website` instance variables.
*   `nav_links`: Sets up the navigation links for the application.
*   `set_locale`: Sets the locale for the application based on the user's preferences or the `locale` parameter in the URL.
*   `set_theme_path`: Sets the theme for the application based on the website's configuration.
*   `footer_content`: Sets the content for the footer.

---

### WelcomeController (`app/controllers/pwb/welcome_controller.rb`)

The `WelcomeController` handles the home page of the website.

**Actions:**

*   `index`: This is the main action for the controller. It retrieves the content for the home page, as well as a list of featured properties for sale and for rent.

---

### PropsController (`app/controllers/pwb/props_controller.rb`)

The `PropsController` handles the display of individual properties.

**Actions:**

*   `show_for_rent`: This action displays the details of a property that is for rent. It sets the `@property_details` instance variable and renders the `show` template.
*   `show_for_sale`: This action displays the details of a property that is for sale. It also sets the `@property_details` instance variable and renders the `show` template.
*   `request_property_info_ajax`: This action handles the submission of the property inquiry form. It creates a new `Message` and a new `Contact`, and then sends an email to the agency.

---

### PagesController (`app/controllers/pwb/pages_controller.rb`)

The `PagesController` handles the display of custom pages.

**Actions:**

*   `show_page`: This action displays the content of a custom page. It retrieves the `Page` object based on the `page_slug` parameter, and then renders the `show` template.

---

### ContactUsController (`app/controllers/pwb/contact_us_controller.rb`)

The `ContactUsController` handles the contact us page and the submission of the contact form.

**Actions:**

*   `index`: This action displays the contact us page. It retrieves the content for the page and sets up the map markers for the agency's location.
*   `contact_us_ajax`: This action handles the submission of the contact form. It creates a new `Message` and a new `Contact`, and then sends an email to the agency.

---

### SearchController (`app/controllers/pwb/search_controller.rb`)

The `SearchController` handles property searches.

**Actions:**

*   `search_ajax_for_sale`: This action performs a search for properties for sale and returns the results as JavaScript.
*   `search_ajax_for_rent`: This action performs a search for properties for rent and returns the results as JavaScript.
*   `buy`: This action displays the search page for properties for sale.
*   `rent`: This action displays the search page for properties for rent.

---

### AdminPanelController (`app/controllers/pwb/admin_panel_controller.rb`)

The `AdminPanelController` is the main controller for the admin panel.

**Purpose:**

*   To provide a secure area for administrators to manage the website.
*   To render the main admin panel layout.

**Actions:**

*   `show`: This action renders the main admin panel layout. It also checks that the current user is an administrator.
*   `show_legacy_1`: This action renders a legacy version of the admin panel.

---

### AdminPanelVueController (`app/controllers/pwb/admin_panel_vue_controller.rb`)

The `AdminPanelVueController` is the controller for the Vue.js version of the admin panel.

**Purpose:**

*   To render the layout for the Vue.js admin panel.
*   To provide a secure area for administrators to manage the website.

**Actions:**

*   `show`: This action renders the layout for the Vue.js admin panel. It also checks that the current user is an administrator.

---

### ConfigController (`app/controllers/pwb/config_controller.rb`)

The `ConfigController` is used to display configuration information.

**Actions:**

*   `show`: This action renders the `show` template, which displays the main configuration page.
*   `show_client`: This action retrieves and displays client-specific configuration information from Firebase.

---

### CssController (`app/controllers/pwb/css_controller.rb`)

The `CssController` is used to render custom CSS for the website.

**Actions:**

*   `custom_css`: This action renders a stylesheet with client-configured variables.

---

### DeviseController (`app/controllers/pwb/devise_controller.rb`)

The `DeviseController` is the base controller for Devise, the authentication library used by the application.

**Purpose:**

*   To provide a place to customize the behavior of Devise.
*   To override the default Devise methods for signing in and signing out.

**Methods:**

*   `after_sign_out_path_for`: This method is called after a user signs out. It redirects the user to the home page.
*   `after_sign_in_path_for`: This method is called after a user signs in. It redirects the user to the admin panel.

---

### OmniauthController (`app/controllers/pwb/omniauth_controller.rb`)

The `OmniauthController` is used to handle OmniAuth callbacks.

**Purpose:**

*   To save the current locale in the session before redirecting to the OmniAuth provider.

**Actions:**

*   `localized`: This action saves the current locale in the session and then redirects to the OmniAuth provider.

---

### SquaresController (`app/controllers/pwb/squares_controller.rb`)

The `SquaresController` is used to display property information from Firebase.

**Actions:**

*   `show_prop`: This action retrieves and displays a single property from Firebase.
*   `show_client`: This action retrieves and displays all of a client's properties from Firebase.

---

### VuePublicController (`app/controllers/pwb/vue_public_controller.rb`)

The `VuePublicController` is used to render the public-facing Vue.js application.

**Actions:**

*   `show`: This action renders the layout for the public-facing Vue.js application.

---
