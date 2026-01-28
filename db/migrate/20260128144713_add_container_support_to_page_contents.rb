# frozen_string_literal: true

# Add container support to page_contents for composable layouts.
# This enables page parts to be nested within container page parts,
# allowing side-by-side arrangements (e.g., contact form next to map).
#
# Key additions:
# - parent_page_content_id: References parent container (null for root-level)
# - slot_name: Which slot in the parent container this content occupies
#
# Constraints:
# - Only one level of nesting allowed (enforced in model)
# - Containers cannot be nested inside other containers (enforced in model)
# - Children must specify a valid slot_name (enforced in model)
#
class AddContainerSupportToPageContents < ActiveRecord::Migration[7.0]
  def change
    # Parent reference for nesting - allows page content to be a child of another
    add_reference :pwb_page_contents, :parent_page_content,
                  foreign_key: { to_table: :pwb_page_contents },
                  null: true,
                  index: true

    # Slot assignment for children within a container
    # e.g., 'left', 'right', 'main', 'sidebar'
    add_column :pwb_page_contents, :slot_name, :string, null: true

    # Composite index for efficient child lookups by parent and slot
    add_index :pwb_page_contents,
              [:parent_page_content_id, :slot_name],
              name: 'index_pwb_page_contents_on_parent_and_slot'

    # Index for finding all children ordered within a slot
    add_index :pwb_page_contents,
              [:parent_page_content_id, :slot_name, :sort_order],
              name: 'index_pwb_page_contents_on_parent_slot_order'
  end
end
