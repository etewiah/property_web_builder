module Pwb
  class Export::WebContentsController < ApplicationApiController
    # http://localhost:3000/export/web_contents/all
    def all
      # TODO: - figure out how to get associated cols like raw_en

      headers['Content-Disposition'] = "attachment; filename=\"pwb-web-contents.csv\""
      headers['Content-Type'] ||= 'text/csv'
      # send_data text: (Content.to_csv ["key", "tag", "status", "sort_order", "raw"])
      # above results in below message in chrome:
      # Resource interpreted as Document but transferred with MIME type application/octet-stream
      render plain: (Content.to_csv ["key", "tag", "status", "sort_order", "raw"])
    end
  end
end
