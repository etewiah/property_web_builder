# frozen_string_literal: true

module Pwb
  module Zoho
    # Service for syncing PWB users/signups to Zoho CRM as Leads
    #
    # This service handles all lead lifecycle events:
    # - Creating leads from new signups
    # - Updating leads as users progress through onboarding
    # - Tracking user activity and engagement
    # - Converting leads to customers
    # - Marking leads as lost
    #
    # Usage:
    #   service = Pwb::Zoho::LeadSyncService.new
    #   service.create_lead_from_signup(user, request_info: { ip: '1.2.3.4' })
    #
    class LeadSyncService
      ACTIVITY_SCORES = {
        'first_property' => 20,
        'property_added' => 10,
        'five_properties' => 30,
        'ten_properties' => 20,
        'logo_uploaded' => 15,
        'theme_customized' => 15,
        'page_created' => 10,
        'inquiry_received' => 25,
        'team_member_added' => 20,
        'login' => 5
      }.freeze

      def initialize(client: nil)
        @client = client || Client.instance
      end

      # Check if Zoho sync is available
      #
      # @return [Boolean]
      #
      def available?
        @client.configured?
      end

      # Event 1: Create lead from new signup
      #
      # @param user [Pwb::User] The newly created user
      # @param request_info [Hash] Request context (ip, utm params)
      # @return [String, nil] Zoho lead ID or nil on failure
      #
      def create_lead_from_signup(user, request_info: {})
        return unless available?

        payload = {
          data: [{
            Email: user.email,
            Last_Name: extract_name_from_email(user.email),
            First_Name: user.first_names.presence,
            Phone: user.phone_number_primary.presence,
            Lead_Source: 'Website Signup',
            Lead_Status: 'New',
            PWB_User_ID: user.id.to_s,
            Signup_IP: request_info[:ip],
            UTM_Source: request_info[:utm_source],
            UTM_Medium: request_info[:utm_medium],
            UTM_Campaign: request_info[:utm_campaign],
            Description: build_signup_description(user, request_info)
          }.compact]
        }

        response = @client.post('/Leads', payload)
        zoho_lead_id = response.dig('data', 0, 'details', 'id')

        if zoho_lead_id
          store_zoho_lead_id(user, zoho_lead_id)
          Rails.logger.info "[Zoho] Created lead #{zoho_lead_id} for user #{user.id}"
          zoho_lead_id
        else
          Rails.logger.warn "[Zoho] No lead ID returned for user #{user.id}: #{response}"
          nil
        end
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to create lead for user #{user.id}: #{e.message}"
        raise
      end

      # Event 2: Update lead when website is created/configured
      #
      # @param user [Pwb::User] The user
      # @param website [Pwb::Website] The created website
      # @param plan [Pwb::Plan, nil] Selected plan
      # @return [Boolean] Success status
      #
      def update_lead_website_created(user, website, plan = nil)
        return false unless available?

        zoho_id = get_zoho_lead_id(user)

        # If no lead exists, create one first
        unless zoho_id
          zoho_id = create_lead_from_signup(user)
          return false unless zoho_id
        end

        trial_days = plan&.trial_days || 30

        payload = {
          data: [{
            Lead_Status: 'Configured',
            PWB_Subdomain: website.subdomain,
            Industry: map_site_type_to_industry(website.site_type),
            Plan_Selected: plan&.display_name || 'Starter',
            Annual_Value: calculate_annual_value(plan).to_s,
            Trial_Start_Date: Date.current.iso8601,
            Trial_End_Date: (Date.current + trial_days.days).iso8601,
            PWB_Website_ID: website.id.to_s
          }.compact]
        }

        @client.put("/Leads/#{zoho_id}", payload)
        Rails.logger.info "[Zoho] Updated lead #{zoho_id} with website #{website.id}"
        true
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to update lead for website #{website.id}: #{e.message}"
        false
      end

      # Event 3: Update lead when website goes live (email verified)
      #
      # @param user [Pwb::User] The user
      # @param website [Pwb::Website] The live website
      # @return [Boolean] Success status
      #
      def update_lead_website_live(user, website)
        return false unless available?

        zoho_id = get_zoho_lead_id(user)
        return false unless zoho_id

        site_url = build_website_url(website)

        payload = {
          data: [{
            Lead_Status: 'Active Trial',
            Website: site_url,
            Company: website.company_display_name.presence,
            Email_Verified: true,
            Verified_At: Time.current.iso8601
          }.compact]
        }

        @client.put("/Leads/#{zoho_id}", payload)
        Rails.logger.info "[Zoho] Lead #{zoho_id} website is live: #{site_url}"
        true
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to update lead website live: #{e.message}"
        false
      end

      # Event 4: Update lead when plan is selected or changed
      #
      # @param user [Pwb::User] The user
      # @param subscription [Pwb::Subscription] The subscription
      # @return [Boolean] Success status
      #
      def update_lead_plan_selected(user, subscription)
        return false unless available?

        zoho_id = get_zoho_lead_id(user)
        return false unless zoho_id

        plan = subscription.plan

        payload = {
          data: [{
            Plan_Selected: plan.display_name,
            Annual_Value: calculate_annual_value(plan).to_s,
            Subscription_Status: subscription.status,
            Trial_End_Date: subscription.trial_ends_at&.to_date&.iso8601
          }.compact]
        }

        @client.put("/Leads/#{zoho_id}", payload)
        Rails.logger.info "[Zoho] Lead #{zoho_id} plan updated to #{plan.display_name}"
        true
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to update lead plan: #{e.message}"
        false
      end

      # Event 5: Log user activity and update engagement score
      #
      # @param user [Pwb::User] The user
      # @param activity_type [String] Type of activity (see ACTIVITY_SCORES)
      # @param details [Hash] Additional activity details
      # @return [Boolean] Success status
      #
      def log_activity(user, activity_type, details = {})
        return false unless available?

        zoho_id = get_zoho_lead_id(user)
        return false unless zoho_id

        # Create a note for the activity
        create_activity_note(zoho_id, activity_type, details)

        # Update lead score and status
        update_lead_engagement(zoho_id, activity_type, details)

        Rails.logger.info "[Zoho] Logged activity '#{activity_type}' for lead #{zoho_id}"
        true
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to log activity: #{e.message}"
        false
      end

      # Event 6: Update lead when trial is ending soon
      #
      # @param user [Pwb::User] The user
      # @param days_remaining [Integer] Days left in trial
      # @return [Boolean] Success status
      #
      def update_trial_ending(user, days_remaining)
        return false unless available?

        zoho_id = get_zoho_lead_id(user)
        return false unless zoho_id

        payload = {
          data: [{
            Lead_Status: 'Trial Ending',
            Trial_Days_Left: days_remaining.to_s,
            Last_Activity_Date: Time.current.iso8601
          }]
        }

        @client.put("/Leads/#{zoho_id}", payload)
        Rails.logger.info "[Zoho] Lead #{zoho_id} trial ending in #{days_remaining} days"
        true
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to update trial ending: #{e.message}"
        false
      end

      # Event 7: Convert lead to customer when subscription activates
      #
      # @param user [Pwb::User] The user
      # @param subscription [Pwb::Subscription] The activated subscription
      # @return [Hash, nil] Conversion result with Contact/Account/Deal IDs
      #
      def convert_lead_to_customer(user, subscription)
        return nil unless available?

        zoho_id = get_zoho_lead_id(user)
        return nil unless zoho_id

        website = subscription.website
        plan = subscription.plan
        deal_name = "#{website&.company_display_name || user.email} - #{plan.display_name}"

        payload = {
          data: [{
            overwrite: true,
            notify_lead_owner: true,
            notify_new_entity_owner: true,
            Deals: {
              Deal_Name: deal_name,
              Stage: 'Closed Won',
              Amount: calculate_annual_value(plan),
              Closing_Date: Date.current.iso8601,
              PWB_Plan: plan.display_name,
              PWB_Website_ID: website&.id.to_s,
              Subscription_Status: 'active'
            }.compact
          }]
        }

        response = @client.post("/Leads/#{zoho_id}/actions/convert", payload)

        if response.dig('data', 0, 'Contacts')
          result = {
            contact_id: response.dig('data', 0, 'Contacts'),
            account_id: response.dig('data', 0, 'Accounts'),
            deal_id: response.dig('data', 0, 'Deals')
          }
          store_zoho_customer_ids(user, result)
          Rails.logger.info "[Zoho] Converted lead #{zoho_id} to customer: #{result}"
          result
        else
          Rails.logger.warn "[Zoho] Lead conversion returned unexpected response: #{response}"
          nil
        end
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to convert lead to customer: #{e.message}"
        raise
      end

      # Event 8: Mark lead as lost (trial expired or user canceled)
      #
      # @param user [Pwb::User] The user
      # @param reason [String] Reason for losing the lead
      # @return [Boolean] Success status
      #
      def mark_lead_lost(user, reason)
        return false unless available?

        zoho_id = get_zoho_lead_id(user)
        return false unless zoho_id

        payload = {
          data: [{
            Lead_Status: 'Lost',
            Lost_Reason: reason,
            Lost_Date: Date.current.iso8601,
            Last_Activity_Date: Time.current.iso8601
          }]
        }

        @client.put("/Leads/#{zoho_id}", payload)
        Rails.logger.info "[Zoho] Lead #{zoho_id} marked as lost: #{reason}"
        true
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to mark lead as lost: #{e.message}"
        false
      end

      # Find existing lead by email
      #
      # @param email [String] Email to search for
      # @return [String, nil] Zoho lead ID if found
      #
      def find_lead_by_email(email)
        return nil unless available?

        response = @client.get('/Leads/search', { email: email })

        response.dig('data', 0, 'id')
      rescue Zoho::NotFoundError
        nil
      rescue Zoho::Error => e
        Rails.logger.error "[Zoho] Failed to search for lead: #{e.message}"
        nil
      end

      private

      def extract_name_from_email(email)
        local_part = email.split('@').first
        local_part.gsub(/[._\-+]/, ' ').split.map(&:capitalize).join(' ')
      end

      def build_signup_description(user, request_info)
        parts = ["Signed up for PWB trial on #{Time.current.strftime('%Y-%m-%d %H:%M UTC')}"]
        parts << "Source: #{request_info[:utm_source]}" if request_info[:utm_source].present?
        parts << "Campaign: #{request_info[:utm_campaign]}" if request_info[:utm_campaign].present?
        parts.join("\n")
      end

      def map_site_type_to_industry(site_type)
        {
          'residential' => 'Residential Real Estate',
          'commercial' => 'Commercial Real Estate',
          'vacation_rental' => 'Vacation Rentals',
          'property_management' => 'Property Management',
          'mixed' => 'Real Estate'
        }[site_type.to_s] || 'Real Estate'
      end

      def calculate_annual_value(plan)
        return 0 unless plan

        monthly_cents = plan.price_cents
        monthly = monthly_cents / 100.0

        if plan.billing_interval == 'year'
          monthly
        else
          monthly * 12
        end
      end

      def build_website_url(website)
        base_domain = ENV['PWB_BASE_DOMAIN'] || 'pwb.io'

        if website.custom_domain.present?
          "https://#{website.custom_domain}"
        else
          "https://#{website.subdomain}.#{base_domain}"
        end
      end

      def store_zoho_lead_id(user, zoho_id)
        metadata = user.metadata || {}
        metadata['zoho_lead_id'] = zoho_id
        metadata['zoho_synced_at'] = Time.current.iso8601
        user.update_column(:metadata, metadata)
      end

      def store_zoho_customer_ids(user, ids)
        metadata = user.metadata || {}
        metadata['zoho_contact_id'] = ids[:contact_id]
        metadata['zoho_account_id'] = ids[:account_id]
        metadata['zoho_deal_id'] = ids[:deal_id]
        metadata['zoho_converted_at'] = Time.current.iso8601
        user.update_column(:metadata, metadata)
      end

      def get_zoho_lead_id(user)
        user.metadata&.dig('zoho_lead_id')
      end

      def create_activity_note(zoho_id, activity_type, details)
        note_content = format_activity_note(activity_type, details)

        payload = {
          data: [{
            Note_Title: "Activity: #{humanize_activity(activity_type)}",
            Note_Content: note_content,
            Parent_Id: zoho_id,
            se_module: 'Leads'
          }]
        }

        @client.post('/Notes', payload)
      end

      def format_activity_note(activity_type, details)
        timestamp = Time.current.strftime('%Y-%m-%d %H:%M UTC')

        case activity_type
        when 'first_property', 'property_added'
          "Added property: #{details[:title]} (REF: #{details[:reference]})\nTime: #{timestamp}"
        when 'five_properties'
          "Milestone: Added 5 properties to their website\nTotal properties: #{details[:total_count]}\nTime: #{timestamp}"
        when 'ten_properties'
          "Milestone: Added 10 properties to their website\nTotal properties: #{details[:total_count]}\nTime: #{timestamp}"
        when 'logo_uploaded'
          "Uploaded company logo - actively customizing their site\nTime: #{timestamp}"
        when 'theme_customized'
          "Customized website theme: #{details[:theme_name]}\nTime: #{timestamp}"
        when 'page_created'
          "Created new page: #{details[:page_title]}\nTime: #{timestamp}"
        when 'inquiry_received'
          "Received customer inquiry - site is generating leads!\nInquiry from: #{details[:contact_email]}\nTime: #{timestamp}"
        when 'team_member_added'
          "Added team member: #{details[:email]}\nRole: #{details[:role]}\nTime: #{timestamp}"
        when 'login'
          "User logged in\nSign-in count: #{details[:sign_in_count]}\nTime: #{timestamp}"
        else
          "Activity: #{activity_type}\n#{details.to_json}\nTime: #{timestamp}"
        end
      end

      def humanize_activity(activity_type)
        activity_type.to_s.tr('_', ' ').titleize
      end

      def update_lead_engagement(zoho_id, activity_type, details)
        # Get current lead data
        lead_response = @client.get("/Leads/#{zoho_id}")
        lead_data = lead_response.dig('data', 0) || {}

        current_score = (lead_data['Lead_Score'] || 0).to_i
        score_delta = ACTIVITY_SCORES[activity_type.to_s] || 5
        new_score = [current_score + score_delta, 100].min

        update_payload = {
          data: [{
            Lead_Score: new_score.to_s,
            Last_Activity_Date: Time.current.iso8601
          }]
        }

        # Add properties count if relevant
        if details[:total_count] && activity_type.to_s.include?('propert')
          update_payload[:data][0][:Properties_Count] = details[:total_count].to_s
        end

        # Update status based on score thresholds
        current_status = lead_data['Lead_Status']
        unless %w[Lost Converted].include?(current_status)
          if new_score >= 70
            update_payload[:data][0][:Lead_Status] = 'Hot'
          elsif new_score >= 40 && current_status != 'Hot'
            update_payload[:data][0][:Lead_Status] = 'Engaged'
          end
        end

        @client.put("/Leads/#{zoho_id}", update_payload)
      end
    end
  end
end
