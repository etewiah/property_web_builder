module Pwb
  module ConsoleHelpers
    def tenant(subdomain_or_id)
      website = if subdomain_or_id.is_a?(Integer)
                  Pwb::Website.find_by(id: subdomain_or_id)
                else
                  Pwb::Website.find_by(subdomain: subdomain_or_id)
                end

      if website
        Pwb::Current.website = website
        ActsAsTenant.current_tenant = website
        puts "✅ Switched to tenant: #{website.subdomain} (ID: #{website.id})"
        puts "   PwbTenant models are now scoped to this website."
      else
        puts "❌ Tenant not found: #{subdomain_or_id}"
      end
      website
    end
    
    def current_tenant
      website = ActsAsTenant.current_tenant || Pwb::Current.website
      if website
        puts "Current tenant: #{website.subdomain} (ID: #{website.id})"
        website
      else
        puts "No tenant currently set."
        nil
      end
    end

    def clear_tenant
      Pwb::Current.website = nil
      ActsAsTenant.current_tenant = nil
      puts "🔓 Tenant cleared. PwbTenant models will now raise errors; use Pwb:: models for cross-tenant queries."
      nil
    end
    
    def list_tenants
      current = ActsAsTenant.current_tenant || Pwb::Current.website
      Pwb::Website.select(:id, :subdomain).find_each do |w|
        marker = (current&.id == w.id) ? "*" : " "
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
  puts "  list_tenants    - see available websites"
  puts "  tenant(id)      - switch to tenant (PwbTenant models will be scoped)"
  puts "  current_tenant  - show current tenant"
  puts "  clear_tenant    - clear tenant (use Pwb:: for cross-tenant queries)"
end
