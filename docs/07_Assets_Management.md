# Asset Management

## Stylesheets and Sass

PropertyWebBuilder uses `dart-sass-rails` for compiling Sass stylesheets.

### Directory Structure

To avoid conflicts with the `sprockets` gem (which attempts to use the deprecated `sassc` gem for `.scss` files found in `app/assets`), we have moved the source stylesheets to a custom directory:

*   **Source Stylesheets**: `app/stylesheets/`
*   **Compiled Output**: `app/assets/builds/`

### Configuration

The configuration for `dart-sass-rails` is located in `config/initializers/dartsass.rb`. It maps the source files in `app/stylesheets` to their target output in `app/assets/builds`.

Example configuration:

```ruby
Rails.application.config.dartsass.builds = {
  "../../stylesheets/pwb/application.scss" => "pwb/application.css",
  # ... other mappings
}

Rails.application.config.dartsass.build_options << " --load-path=app/stylesheets --load-path=vendor/assets/stylesheets"
```

### Building Assets

To compile the stylesheets, run the following command:

```bash
bin/rails dartsass:build
```

This command is also automatically run during `assets:precompile`.

### Troubleshooting

If you encounter `LoadError: cannot load such file -- sassc`, it usually means that `.scss` files have been placed in `app/assets/stylesheets`. Ensure all Sass source files are located in `app/stylesheets`.
