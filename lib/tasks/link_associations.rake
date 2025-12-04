namespace :pwb do
  desc "Link existing photos, features, and translations to RealtyAssets"
  task link_associations: :environment do
    puts "Starting association linking..."
    
    Pwb::Prop.find_each do |prop|
      # Find the corresponding RealtyAsset by reference
      # Assuming reference is unique enough for this migration
      asset = Pwb::RealtyAsset.find_by(reference: prop.reference)
      
      if asset
        # Link Photos
        prop.prop_photos.update_all(realty_asset_id: asset.id)
        
        # Link Features
        prop.features.update_all(realty_asset_id: asset.id)
        
        # Link Translations
        prop.translations.update_all(realty_asset_id: asset.id)
        
        print "."
      else
        puts "\nWarning: Could not find RealtyAsset for Prop #{prop.id} (Ref: #{prop.reference})"
      end
    end
    puts "\nAssociation linking complete."
  end
end
