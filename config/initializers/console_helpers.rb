module Pwb
  module ConsoleHelpers
    def tenant(subdomain_or_id)
      website = if subdomain_or_id.is_a?(Integer)
                  Pwb::Website.find(subdomain_or_id)
                else
                  Pwb::Website.find_by(subdomain: subdomain_or_id)
                end

      if website
        Pwb::Current.website = website
        puts "✅ Switched to tenant: #{website.subdomain} (ID: #{website.id})"
        puts "   PwbTenant models are now scoped to this website."
      else
        puts "❌ Tenant not found: #{subdomain_or_id}"
      end
      website
    end
    
    def current_tenant
      if Pwb::Current.website
        puts "Current tenant: #{Pwb::Current.website.subdomain} (ID: #{Pwb::Current.website.id})"
        Pwb::Current.website
      else
        puts "No tenant currently set."
        nil
      end
    end
    
    def list_tenants
      Pwb::Website.select(:id, :subdomain).find_each do |w|
        marker = (Pwb::Current.website&.id == w.id) ? "*" : " "
        puts "#{marker} [#{w.id}] #{w.subdomain}"
      end
      nil
    end
  end
end

# Auto-include in Rails console
if defined?(Rails::Console)
  include Pwb::ConsoleHelpers
  puts "Loaded PWB Console Helpers."
  puts "Type `list_tenants` to see available websites."
  puts "Type `tenant('subdomain')` or `tenant(id)` to switch context."
end
