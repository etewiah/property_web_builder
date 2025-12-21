# Tailwind Helpers

This project includes custom helpers to generate form inputs with Tailwind CSS styling, specifically designed for the Bristol theme and other Tailwind-based themes.

## `tailwind_inmo_input`

Generates a text input field with a label, placeholder, and validation styling.

### Usage

```erb
<%= tailwind_inmo_input form_object, field_key, placeholder_key, input_type, required %>
```

### Parameters

*   `form_object`: The form builder object (e.g., `f` from `form_for`).
*   `field_key`: The symbol or string for the field name (e.g., `:name`, `:email`). This is also used as the translation key for the label.
*   `placeholder_key`: The key for the placeholder translation (looked up under `placeHolders.`).
*   `input_type`: The HTML input type (e.g., `"text"`, `"email"`).
*   `required`: Boolean indicating if the field is required. If true, adds a red asterisk to the label.

### Example

```erb
<%= tailwind_inmo_input f, :email, "email", "email", true %>
```

This will generate HTML similar to:

```html
<div>
  <label class="block text-sm font-medium text-gray-700 mb-1">
    Email <span class="text-red-500">*</span>
  </label>
  <input class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" 
         type="email" name="contact[email]" required="required" placeholder="Your email">
</div>
```

## `tailwind_inmo_textarea`

Generates a textarea field with a label and placeholder.

### Usage

```erb
<%= tailwind_inmo_textarea form_object, field_key, placeholder_key, input_type, required, rows %>
```

### Parameters

*   `form_object`: The form builder object.
*   `field_key`: The field name and label translation key.
*   `placeholder_key`: The placeholder translation key.
*   `input_type`: (Unused but kept for consistency) usually `"text"`.
*   `required`: Boolean for required status.
*   `rows`: Number of rows for the textarea (default is 5).

### Example

```erb
<%= tailwind_inmo_textarea f, :message, "message", "text", false %>
```
