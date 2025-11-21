# Data Models

This section provides a detailed overview of the data models used in the PropertyWebBuilder application. Each model is described with its purpose, attributes, associations, and validations.

---

### Agency (`app/models/pwb/agency.rb`)

The `Agency` model is a singleton model that represents the real estate agency itself. It stores the agency's primary contact information, branding details, and other global settings.

**Purpose:**

*   To provide a central location for storing agency-specific information.
*   To ensure that there is only one agency record in the database.

**Attributes:**

*   `display_name` (string): The public-facing name of the agency.
*   `company_name` (string): The legal name of the agency.
*   `phone_number_primary` (string): The primary contact phone number.
*   `phone_number_mobile` (string): The mobile phone number.
*   `phone_number_other` (string): An alternative phone number.
*   `email_primary` (string): The primary email address for the agency.
*   `email_for_property_contact_form` (string): The email address that receives inquiries from property contact forms.
*   `email_for_general_contact_form` (string): The email address that receives inquiries from the general contact form.

**Associations:**

*   `belongs_to :primary_address, class_name: "Address"`: The agency's primary physical address.
*   `belongs_to :secondary_address, class_name: "Address"`: An optional secondary address.

**Key Methods:**

*   `self.unique_instance`: A class method that returns the single instance of the `Agency` model. If no instance exists, it creates one.

**Callbacks:**

*   `before_create :confirm_singularity`: A callback that prevents the creation of more than one `Agency` record.

---

### Address (`app/models/pwb/address.rb`)

The `Address` model stores physical addresses.

**Purpose:**

*   To store and manage physical addresses for various entities, such as the agency and properties.

**Associations:**

*   `has_one :agency, foreign_key: "primary_address_id"`:  A primary address for the agency.
*   `has_one :agency_as_secondary, foreign_key: "secondary_address_id"`: A secondary address for the agency.

---

### Prop (`app/models/pwb/prop.rb`)

The `Prop` model is the central model for representing a property listing.

**Purpose:**

*   To store all the information about a property, including its title, description, price, location, and features.
*   To handle internationalization, geolocation, and multi-currency pricing.

**Key Features:**

*   **Internationalization:** The `title` and `description` attributes are translatable using the `globalize` gem.
*   **Geolocation:** The model is geocoded using the `geocoder` gem, which automatically populates the location attributes based on the address.
*   **Price Monetization:** The model uses the `money-rails` gem to handle multi-currency pricing.

**Attributes:**

*   `title` (string): The title of the property listing (translatable).
*   `description` (text): A detailed description of the property (translatable).
*   `price_sale_current_cents` (integer): The current sale price in cents.
*   `price_rental_monthly_current_cents` (integer): The current monthly rental price in cents.
*   `currency` (string): The currency of the prices.
*   `latitude` (float): The latitude of the property.
*   `longitude` (float): The longitude of the property.
*   `street_address` (string): The street address.
*   `city` (string): The city.
*   `postal_code` (string): The postal code.
*   `province` (string): The province or state.
*   `country` (string): The country.
*   And many more...

**Associations:**

*   `has_many :prop_photos`: A property can have many photos.
*   `has_many :features`: A property can have many features.

**Scopes:**

The `Prop` model has a number of scopes that can be used to filter and search for properties. Some of the key scopes include:

*   `for_rent`: Returns all properties that are available for rent.
*   `for_sale`: Returns all properties that are available for sale.
*   `visible`: Returns all properties that are marked as visible.
*   `in_zone`, `in_locality`: Returns properties in a specific zone or locality.
*   `property_type`, `property_state`: Returns properties of a specific type or state.
*   Price and feature-based scopes for filtering.

---

### User (`app/models/pwb/user.rb`)

The `User` model represents a user of the application.

**Purpose:**

*   To handle user authentication and authorization.
*   To store user information, such as email and password.

**Key Features:**

*   **Devise Integration:** The model is integrated with the `devise` gem to provide a full range of authentication features, including registration, password recovery, and session management.
*   **Omniauth:** The model is also integrated with `omniauth` to allow users to sign in with their Facebook account.

**Associations:**

*   `has_many :authorizations`: A user can have many authorizations, which are used to link the user's account to third-party providers like Facebook.

**Key Methods:**

*   `self.find_for_oauth`: A class method that finds or creates a user based on the information provided by an OAuth provider.
*   `create_authorization`: An instance method that creates a new authorization for the user.

---

### Website (`app/models/pwb/website.rb`)

The `Website` model is a singleton model that represents the website itself.

**Purpose:**

*   To store global website configuration and settings, such as the theme, default language, currency, and social media links.
*   To manage the website's content, including pages, page parts, and links.

**Attributes:**

*   `theme_name` (string): The name of the active theme.
*   `default_area_unit` (enum): The default unit for property area (sqmt or sqft).
*   `default_client_locale` (string): The default language for the website.
*   `available_currencies` (array): A list of available currencies.
*   `default_currency` (string): The default currency for the website.
*   `supported_locales` (array): A list of supported languages.
*   `social_media` (json): A JSON object containing social media links.
*   `raw_css` (text): Custom CSS that can be added to the website.
*   `analytics_id` (string): The Google Analytics ID.

**Associations:**

*   `has_many :page_contents`
*   `has_many :contents, through: :page_contents`
*   `has_many :ordered_visible_page_contents`

**Key Methods:**

*   `self.unique_instance`: A class method that returns the single instance of the `Website` model.
*   `style_variables`: Returns a hash of style variables that can be used to customize the website's appearance.
*   `logo_url`: Returns the URL of the website's logo.
*   `top_nav_display_links`: Returns a collection of links that should be displayed in the top navigation bar.
*   `footer_display_links`: Returns a collection of links that should be displayed in the footer.

---

### Page (`app/models/pwb/page.rb`)

The `Page` model represents a custom page on the website.

**Purpose:**

*   To allow administrators to create and manage custom pages with their own content.
*   To store the page's title, slug, and other metadata.

**Attributes:**

*   `slug` (string): The URL-friendly identifier for the page.
*   `raw_html` (text): The raw HTML content of the page (translatable).
*   `page_title` (string): The title of the page (translatable).
*   `link_title` (string): The title of the link to the page (translatable).
*   `show_in_top_nav` (boolean): Whether to show a link to the page in the top navigation bar.
*   `show_in_footer` (boolean): Whether to show a link to the page in the footer.
*   `visible` (boolean): Whether the page is visible to the public.

**Associations:**

*   `has_many :links, foreign_key: "page_slug", primary_key: "slug"`
*   `has_one :main_link, -> { where(placement: :top_nav) }, foreign_key: "page_slug", primary_key: "slug"`
*   `has_many :page_parts, foreign_key: "page_slug", primary_key: "slug"`
*   `has_many :page_contents`
*   `has_many :contents, through: :page_contents`

**Key Methods:**

*   `get_page_part(page_part_key)`: Returns the page part with the given key.
*   `create_fragment_photo(page_part_key, block_label, photo_file)`: Creates a new photo for a page fragment.
*   `set_fragment_html(page_part_key, locale, new_fragment_html)`: Sets the HTML content for a page fragment.

---

### Content (`app/models/pwb/content.rb`)

The `Content` model represents a reusable block of content.

**Purpose:**

*   To store and manage reusable content that can be displayed on multiple pages.
*   To allow for the creation of content blocks with their own photos and translations.

**Attributes:**

*   `key` (string): A unique identifier for the content block.
*   `page_part_key` (string): The key of the page part that the content block belongs to.
*   `raw` (text): The raw HTML content of the content block (translatable).

**Associations:**

*   `has_many :content_photos, dependent: :destroy`
*   `has_many :page_contents`
*   `has_many :pages, through: :page_contents`

**Key Methods:**

*   `default_photo_url`: Returns the URL of the first photo associated with the content block.
*   `self.import(file)`: A class method that imports content from a CSV file.
*   `self.to_csv`: A class method that exports content to a CSV file.

---

### Message (`app/models/pwb/message.rb`)

The `Message` model represents a message sent through a contact form.

**Purpose:**

*   To store messages submitted through the website's contact forms.
*   To associate each message with a contact.

**Attributes:**

*   `title` (string): The title of the message.
*   `content` (text): The content of the message.
*   `originating_page` (string): The page from which the message was sent.
*   And other details about the sender.

**Associations:**

*   `belongs_to :contact, optional: true`: A message can be associated with a contact.

---

### Contact (`app/models/pwb/contact.rb`)

The `Contact` model represents a contact, such as a client or a lead.

**Purpose:**

*   To store information about contacts, including their name, email, and phone number.
*   To associate contacts with messages, addresses, and users.

**Attributes:**

*   `title` (enum): The contact's title (e.g., "mr", "mrs").
*   `first_name` (string): The contact's first name.
*   `last_name` (string): The contact's last name.
*   `email` (string): The contact's email address.
*   `phone_number` (string): The contact's phone number.

**Associations:**

*   `has_many :messages`
*   `belongs_to :primary_address, optional: true, class_name: "Address"`
*   `belongs_to :secondary_address, optional: true, class_name: "Address"`
*   `belongs_to :user, optional: true`

---

### Link (`app/models/pwb/link.rb`)

The `Link` model represents a navigational link.

**Purpose:**

*   To create and manage links for the website's navigation menus, such as the top navigation bar and the footer.
*   To associate links with pages and external URLs.

**Attributes:**

*   `link_title` (string): The title of the link (translatable).
*   `link_path` (string): The URL of the link.
*   `placement` (enum): The location where the link should be displayed (e.g., "top_nav", "footer").
*   `sort_order` (integer): The sort order of the link.
*   `visible` (boolean): Whether the link is visible.
*   `page_slug` (string): The slug of the page that the link points to.

**Associations:**

*   `belongs_to :page, optional: true, foreign_key: "page_slug", primary_key: "slug"`

**Scopes:**

*   `ordered_visible_admin`, `ordered_visible_top_nav`, `ordered_visible_footer`: Return links for a specific placement, ordered by sort order.

---

### Theme (`app/models/pwb/theme.rb`)

The `Theme` model represents a theme for the website.

**Purpose:**

*   To define the look and feel of the website.
*   To allow for the creation of custom themes.

**Configuration:**

The `Theme` model uses `ActiveJSON::Base` to load theme configurations from JSON files located in the `app/themes` directory. Each theme has a `config.json` file that defines its name, author, and other details.

**Associations:**

*   `has_one :website, foreign_key: "theme_name", primary_key: "name"`: A theme can be associated with the website.

---
