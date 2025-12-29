# frozen_string_literal: true

module Pwb
  # SetupController handles the initial setup flow when no website exists
  # for the current subdomain. It allows users to create and seed a new website
  # from available seed packs.
  class SetupController < ActionController::Base
    protect_from_forgery with: :exception

    layout 'pwb/setup'

    before_action :check_already_setup, only: [:index, :create]

    def index
      @seed_packs = Pwb::SeedPack.available
      @subdomain = request.subdomain.presence || 'default'
    end

    def create
      pack_name = params[:pack_name]
      subdomain = params[:subdomain].presence || request.subdomain.presence || 'default'

      # Validate pack exists
      unless pack_name.present?
        flash[:error] = "Please select a seed pack"
        return redirect_to pwb_setup_path
      end

      begin
        pack = Pwb::SeedPack.find(pack_name)
      rescue Pwb::SeedPack::PackNotFoundError
        flash[:error] = "Seed pack '#{pack_name}' not found"
        return redirect_to pwb_setup_path
      end

      # Create the website
      website = Pwb::Website.new(
        subdomain: subdomain,
        provisioning_state: 'live',
        theme_name: pack.config.dig(:website, :theme_name) || 'default'
      )

      if website.save
        # Apply the seed pack
        begin
          pack.apply!(website: website, options: { verbose: false })
          flash[:success] = "Website '#{subdomain}' created and seeded successfully!"
          # allow_other_host: true is needed because we're redirecting to a different subdomain
          redirect_to root_url(subdomain: subdomain), allow_other_host: true
        rescue StandardError => e
          Rails.logger.error("Seed pack application failed: #{e.message}")
          flash[:error] = "Website created but seeding failed: #{e.message}"
          redirect_to root_url(subdomain: subdomain), allow_other_host: true
        end
      else
        flash[:error] = "Failed to create website: #{website.errors.full_messages.join(', ')}"
        redirect_to pwb_setup_path
      end
    end

    private

    def check_already_setup
      # Check if a website already exists for this subdomain
      subdomain = request.subdomain
      return if subdomain.blank?

      website = Pwb::Website.find_by_subdomain(subdomain)
      return if website.nil?

      # Website exists, redirect to home
      redirect_to root_path
    end
  end
end
