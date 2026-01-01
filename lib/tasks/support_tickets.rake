# frozen_string_literal: true

namespace :support_tickets do
  desc "Seed example support tickets for testing"
  task seed: :environment do
    puts "\n=== Seeding Support Tickets ==="

    # Find or create a test website
    website = find_or_create_test_website
    puts "Using website: #{website.subdomain}"

    # Find or create a user for the website
    user = find_or_create_test_user(website)
    puts "Using user: #{user.email}"

    # Seed example tickets
    seed_example_tickets(website, user)

    puts "\n=== Done! ==="
    puts "Created tickets for website: #{website.subdomain}"
    puts "View in site_admin at: /site_admin/support_tickets"
    puts "View in tenant_admin at: /tenant_admin/support_tickets"
  end

  desc "Seed tickets for a specific website (use SUBDOMAIN=name)"
  task seed_for_website: :environment do
    subdomain = ENV['SUBDOMAIN']
    unless subdomain
      puts "Usage: rake support_tickets:seed_for_website SUBDOMAIN=my-site"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: subdomain)
    unless website
      puts "Website '#{subdomain}' not found"
      exit 1
    end

    user = website.users.first
    unless user
      puts "No users found for website '#{subdomain}'. Creating a test user..."
      user = find_or_create_test_user(website)
    end

    puts "Seeding tickets for: #{subdomain}"
    seed_example_tickets(website, user)
    puts "Done!"
  end

  desc "Seed a single ticket with custom attributes"
  task create: :environment do
    subdomain = ENV.fetch('SUBDOMAIN', nil)
    subject = ENV.fetch('SUBJECT', 'Test Ticket')
    category = ENV.fetch('CATEGORY', 'general')
    priority = ENV.fetch('PRIORITY', 'normal')
    description = ENV.fetch('DESCRIPTION', 'This is a test ticket created via rake task.')

    website = if subdomain
                Pwb::Website.find_by!(subdomain: subdomain)
              else
                find_or_create_test_website
              end

    user = website.users.first || find_or_create_test_user(website)

    ticket = ActsAsTenant.with_tenant(website) do
      Pwb::SupportTicket.create!(
        website: website,
        creator: user,
        subject: subject,
        description: description,
        category: category,
        priority: priority
      )
    end

    puts "Created ticket: #{ticket.ticket_number}"
    puts "  Subject: #{ticket.subject}"
    puts "  Category: #{ticket.category}"
    puts "  Priority: #{ticket.priority}"
    puts "  Status: #{ticket.status}"
  end

  desc "List all support tickets"
  task list: :environment do
    puts "\n=== Support Tickets ==="
    puts "Total: #{Pwb::SupportTicket.count}\n\n"

    Pwb::SupportTicket.includes(:website, :creator).recent.limit(20).each do |ticket|
      puts "#{ticket.ticket_number} | #{ticket.status.ljust(20)} | #{ticket.priority.ljust(8)} | #{ticket.website.subdomain.ljust(20)} | #{ticket.subject.truncate(40)}"
    end

    if Pwb::SupportTicket.count > 20
      puts "\n... and #{Pwb::SupportTicket.count - 20} more. Use LIMIT=n to show more."
    end
  end

  desc "Show ticket details (use TICKET=TKT-XXXXXXXX)"
  task show: :environment do
    ticket_number = ENV['TICKET']
    unless ticket_number
      puts "Usage: rake support_tickets:show TICKET=TKT-12345678"
      exit 1
    end

    ticket = Pwb::SupportTicket.find_by(ticket_number: ticket_number)
    unless ticket
      puts "Ticket '#{ticket_number}' not found"
      exit 1
    end

    puts "\n=== Ticket Details ==="
    puts "Ticket Number: #{ticket.ticket_number}"
    puts "Subject:       #{ticket.subject}"
    puts "Status:        #{ticket.status}"
    puts "Priority:      #{ticket.priority}"
    puts "Category:      #{ticket.category}"
    puts "Website:       #{ticket.website.subdomain}"
    puts "Creator:       #{ticket.creator.email}"
    puts "Assigned To:   #{ticket.assigned_to&.email || 'Unassigned'}"
    puts "Created At:    #{ticket.created_at}"
    puts "Messages:      #{ticket.message_count}"

    if ticket.messages.any?
      puts "\n--- Messages ---"
      ticket.messages.chronological.each_with_index do |msg, i|
        prefix = msg.internal_note ? "[INTERNAL] " : ""
        from = msg.from_platform_admin ? "[Platform] " : "[Customer] "
        puts "\n##{i + 1} #{from}#{prefix}(#{msg.created_at.strftime('%Y-%m-%d %H:%M')})"
        puts "   #{msg.content.truncate(200)}"
      end
    end
  end

  desc "Delete all support tickets (use CONFIRM=true to execute)"
  task clear: :environment do
    unless ENV['CONFIRM'] == 'true'
      puts "This will delete ALL support tickets and messages!"
      puts "To confirm, run: rake support_tickets:clear CONFIRM=true"
      exit 1
    end

    count = Pwb::SupportTicket.count
    Pwb::TicketMessage.delete_all
    Pwb::SupportTicket.delete_all
    puts "Deleted #{count} tickets and all associated messages."
  end

  desc "Show ticket statistics"
  task stats: :environment do
    puts "\n=== Support Ticket Statistics ==="
    puts "Total Tickets:    #{Pwb::SupportTicket.count}"
    puts "Total Messages:   #{Pwb::TicketMessage.count}"

    puts "\n--- By Status ---"
    Pwb::SupportTicket.group(:status).count.each do |status, count|
      puts "  #{status.to_s.ljust(20)} #{count}"
    end

    puts "\n--- By Priority ---"
    Pwb::SupportTicket.group(:priority).count.each do |priority, count|
      puts "  #{priority.to_s.ljust(20)} #{count}"
    end

    puts "\n--- By Category ---"
    Pwb::SupportTicket.group(:category).count.each do |category, count|
      puts "  #{(category || 'none').to_s.ljust(20)} #{count}"
    end

    puts "\n--- By Website ---"
    Pwb::SupportTicket.joins(:website)
                      .group('pwb_websites.subdomain')
                      .count
                      .sort_by { |_, v| -v }
                      .first(10)
                      .each do |subdomain, count|
      puts "  #{subdomain.ljust(25)} #{count}"
    end

    active_count = Pwb::SupportTicket.active.count
    needs_response = Pwb::SupportTicket.needs_response.count
    unassigned = Pwb::SupportTicket.unassigned.where.not(status: [:resolved, :closed]).count

    puts "\n--- Actionable ---"
    puts "  Active tickets:      #{active_count}"
    puts "  Needs response:      #{needs_response}"
    puts "  Unassigned (active): #{unassigned}"
  end

  # =========================================================================
  # Helper Methods
  # =========================================================================

  def find_or_create_test_website
    Pwb::Website.find_by(subdomain: 'support-test') ||
      Pwb::Website.create!(
        subdomain: 'support-test',
        site_type: 'residential',
        provisioning_state: 'live'
      )
  end

  def find_or_create_test_user(website)
    website.users.first ||
      ActsAsTenant.with_tenant(website) do
        Pwb::User.create!(
          email: "support-test-user@#{website.subdomain}.test",
          password: 'password123',
          password_confirmation: 'password123',
          website: website,
          admin: true,
          first_names: 'Test',
          last_names: 'User'
        )
      end
  end

  def seed_example_tickets(website, user)
    example_tickets.each_with_index do |ticket_data, index|
      ActsAsTenant.with_tenant(website) do
        ticket = Pwb::SupportTicket.create!(
          website: website,
          creator: user,
          subject: ticket_data[:subject],
          description: ticket_data[:description],
          category: ticket_data[:category],
          priority: ticket_data[:priority],
          status: ticket_data[:status] || :open
        )

        # Add example messages if provided
        ticket_data[:messages]&.each do |msg|
          Pwb::TicketMessage.create!(
            support_ticket: ticket,
            website: website,
            user: user,
            content: msg[:content],
            from_platform_admin: msg[:from_platform] || false,
            internal_note: msg[:internal_note] || false
          )
        end

        # Update status timestamps
        if ticket_data[:status] == :resolved
          ticket.update!(resolved_at: Time.current - rand(1..48).hours)
        elsif ticket_data[:status] == :closed
          ticket.update!(
            resolved_at: Time.current - rand(48..96).hours,
            closed_at: Time.current - rand(1..24).hours
          )
        end

        puts "  Created: #{ticket.ticket_number} - #{ticket.subject.truncate(40)}"
      end
    end
  end

  def example_tickets
    [
      {
        subject: "Cannot upload property images",
        description: "When I try to upload images for my property listings, the upload gets stuck at 50% and then fails with no error message. I've tried different browsers and the issue persists.",
        category: "technical",
        priority: :high,
        status: :open,
        messages: [
          { content: "We're looking into this issue. Can you tell us the file sizes and formats of the images you're trying to upload?", from_platform: true },
          { content: "The images are JPG files, around 2-3MB each. I've tried with smaller files too but same issue.", from_platform: false }
        ]
      },
      {
        subject: "How do I change my subscription plan?",
        description: "I'd like to upgrade from the Basic plan to the Professional plan. How do I do this and will I be charged immediately?",
        category: "billing",
        priority: :normal,
        status: :waiting_on_customer,
        messages: [
          { content: "You can upgrade your plan from the Settings > Subscription page. When you upgrade, you'll be charged a prorated amount for the remainder of your current billing period. Would you like me to walk you through the process?", from_platform: true }
        ]
      },
      {
        subject: "Feature request: Export listings to CSV",
        description: "It would be really helpful if we could export our property listings to a CSV file for backup purposes or to import into other systems.",
        category: "feature_request",
        priority: :low,
        status: :open
      },
      {
        subject: "Website showing 404 error on property pages",
        description: "All my property detail pages are showing 404 errors since this morning. The listings still appear on the home page but clicking on them leads to a 404.",
        category: "bug",
        priority: :urgent,
        status: :in_progress,
        messages: [
          { content: "This is a critical issue - escalating to engineering team immediately.", from_platform: true, internal_note: true },
          { content: "We've identified the issue and are working on a fix. This should be resolved within the hour. We apologize for the inconvenience.", from_platform: true }
        ]
      },
      {
        subject: "Question about SEO settings",
        description: "Where can I find the SEO settings for my website? I want to customize the meta descriptions for my pages.",
        category: "general",
        priority: :normal,
        status: :resolved,
        messages: [
          { content: "You can find SEO settings under Settings > SEO in your admin panel. From there you can set meta titles, descriptions, and other SEO-related options for each page.", from_platform: true },
          { content: "Found it, thank you!", from_platform: false }
        ]
      },
      {
        subject: "Billing discrepancy on last invoice",
        description: "My last invoice shows a charge of $49.99 but my plan should be $39.99. Can you explain the difference?",
        category: "billing",
        priority: :high,
        status: :closed,
        messages: [
          { content: "I've looked into your account and the additional $10 was for the premium themes add-on that was activated on the 15th. Would you like me to provide a detailed breakdown?", from_platform: true },
          { content: "Oh yes, I remember adding that now. Thanks for clarifying!", from_platform: false },
          { content: "You're welcome! Let us know if you have any other questions.", from_platform: true }
        ]
      },
      {
        subject: "Contact form not sending emails",
        description: "The contact form on my website isn't sending emails to my inbox. I've checked the spam folder but nothing there either.",
        category: "technical",
        priority: :high,
        status: :open,
        messages: [
          { content: "Check email configuration in admin settings - may need to verify SMTP settings.", from_platform: true, internal_note: true }
        ]
      },
      {
        subject: "Request for custom domain setup",
        description: "I'd like to use my own domain (myrealestate.com) instead of the subdomain. What are the steps to set this up?",
        category: "general",
        priority: :normal,
        status: :in_progress,
        messages: [
          { content: "Custom domains are available on Professional and above plans. Here are the steps:\n\n1. Go to Settings > Domain\n2. Enter your domain name\n3. Update your DNS records as shown\n4. Wait for verification (usually 24-48 hours)\n\nLet me know if you need help with any of these steps!", from_platform: true }
        ]
      },
      {
        subject: "Mobile view looks broken",
        description: "When I view my website on my phone, the property cards are overlapping and the menu doesn't work properly. This started after the last update.",
        category: "bug",
        priority: :high,
        status: :resolved,
        messages: [
          { content: "Thanks for reporting this. We've identified a CSS issue that was introduced in yesterday's release. A fix has been deployed and your site should display correctly now. Please clear your browser cache and let us know if you still see issues.", from_platform: true },
          { content: "Cleared cache and it looks perfect now. Thanks for the quick fix!", from_platform: false }
        ]
      },
      {
        subject: "How to add Google Analytics?",
        description: "I want to track visitor analytics on my property website. Is there a way to add Google Analytics or similar tracking?",
        category: "general",
        priority: :low,
        status: :resolved,
        messages: [
          { content: "Yes! You can add Google Analytics by going to Settings > Integrations > Analytics. Paste your GA4 Measurement ID there and save. The tracking code will be automatically added to all pages.", from_platform: true },
          { content: "Perfect, I've added it. Thank you!", from_platform: false }
        ]
      }
    ]
  end
end
