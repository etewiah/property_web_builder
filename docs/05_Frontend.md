# Frontend Documentation

This section provides a detailed overview of the frontend of the PropertyWebBuilder application. The frontend is divided into two main parts: the public-facing website and the admin panel.

## Public-Facing Website

The public-facing website is the part of the application that is visible to visitors. It is built using a combination of Ruby on Rails views and a Vue.js application.

---

## Admin Panel

The admin panel is a secure area where administrators can manage the website. It is a single-page application (SPA) built with Vue.js.

---

### Public Pages

The following pages are available to public visitors:

*   **Home Page (`/`)**: The main landing page of the website. It displays featured properties and a search bar. (Handled by `welcome_controller.rb`)
*   **Property Listings (`/properties/...`)**: These pages display the details of a single property. There are separate routes for properties for sale and for rent. (Handled by `props_controller.rb`)
*   **Custom Pages (`/p/:page_slug`)**: These are custom pages that can be created by the administrator. (Handled by `pages_controller.rb`)
*   **About Us (`/about-us`)**: A custom page that displays information about the agency. (Handled by `pages_controller.rb`)
*   **Contact Us (`/contact-us`)**: A page with a contact form that allows visitors to send a message to the agency. (Handled by `contact_us_controller.rb`)
*   **Buy (`/buy`)**: A search page for properties for sale. (Handled by `search_controller.rb`)
*   **Rent (`/rent`)**: A search page for properties for rent. (Handled by `search_controller.rb`)

### Admin Panel

The admin panel is a single-page application (SPA) built with Vue.js. It is located at `/admin` and provides a secure area for administrators to manage the website. The admin panel includes the following sections:

*   **Dashboard**: An overview of the website's activity.
*   **Properties**: A section for managing property listings.
*   **Pages**: A section for managing custom pages.
*   **Content**: A section for managing reusable content blocks.
*   **Messages**: A section for viewing and managing messages sent through the contact forms.
*   **Settings**: A section for configuring the website and agency settings.

---
