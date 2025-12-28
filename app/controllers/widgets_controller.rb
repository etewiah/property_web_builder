# frozen_string_literal: true

# WidgetsController serves the embeddable widget resources:
# - JavaScript file for script-based embedding
# - Iframe HTML for iframe-based embedding
#
# These routes are publicly accessible for external website embedding.
class WidgetsController < ApplicationController
  include SubdomainTenant

  skip_before_action :verify_authenticity_token
  after_action :set_cors_headers

  # GET /widget.js
  # Serves the widget JavaScript loader
  def javascript
    response.headers['Content-Type'] = 'application/javascript'
    response.headers['Cache-Control'] = 'public, max-age=3600' # Cache for 1 hour

    render plain: widget_javascript, layout: false
  end

  # GET /widget/:widget_key
  # Renders the widget in an iframe-friendly format
  def iframe
    @widget_config = Pwb::WidgetConfig.active.find_by!(widget_key: params[:widget_key])
    @properties = @widget_config.properties_query.with_photos_only

    # Record impression
    @widget_config.record_impression!

    render layout: 'widget'
  rescue ActiveRecord::RecordNotFound
    render plain: 'Widget not found', status: :not_found
  end

  private

  def set_cors_headers
    # Allow embedding from any origin (the widget validates origins server-side)
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['X-Frame-Options'] = 'ALLOWALL'
  end

  def widget_javascript
    host = request.host_with_port
    protocol = request.protocol

    <<~JAVASCRIPT
      /**
       * PropertyWebBuilder Embeddable Widget
       * https://propertywebbuilder.com
       */
      (function() {
        'use strict';

        // Find all widget containers
        var scripts = document.querySelectorAll('script[data-widget-id]');

        scripts.forEach(function(script) {
          var widgetId = script.getAttribute('data-widget-id');
          var containerId = 'pwb-widget-' + widgetId;
          var container = document.getElementById(containerId);

          if (!container) {
            console.warn('PWB Widget: Container #' + containerId + ' not found');
            return;
          }

          // Create iframe
          var iframe = document.createElement('iframe');
          iframe.src = '#{protocol}#{host}/widget/' + widgetId;
          iframe.style.cssText = 'width:100%;border:none;min-height:600px;';
          iframe.setAttribute('loading', 'lazy');
          iframe.setAttribute('title', 'Property Listings');

          // Handle iframe resize messages
          window.addEventListener('message', function(event) {
            if (event.data && event.data.type === 'pwb-widget-resize' && event.data.widgetId === widgetId) {
              iframe.style.height = event.data.height + 'px';
            }
          });

          container.appendChild(iframe);
        });
      })();
    JAVASCRIPT
  end
end
