class AddPagePartsToPwbWebsites < ActiveRecord::Migration[5.1]
  def change
    # add_column :pwb_page_contents, :pwb_website, :belongs_to, index: true
    add_reference :pwb_page_contents, :website, index: true
    # add_foreign_key :pwb_page_contents, :pwb_websites
      # t.belongs_to :page, index: true


    # TODO - add favicon image (and logo image directly)
    # as well as details hash for storing pages..

  end
end
