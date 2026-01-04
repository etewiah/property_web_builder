# frozen_string_literal: true

require_relative '../../../lib/pwb/website_scraper/scraper'

module TenantAdmin
  # SiteImportsController
  # Manages importing/scraping content from existing PWB websites to create seed packs.
  #
  # This allows tenant admins to:
  # - Scrape content from an existing PWB website
  # - Preview scraped content before applying
  # - Apply scraped content to provision new websites
  #
  class SiteImportsController < TenantAdminController
    before_action :set_import_pack, only: [:show, :destroy, :apply]

    def index
      @import_packs = list_import_packs
    end

    def new
      # Form for entering URL to scrape
    end

    def create
      url = params[:url]
      pack_name = params[:pack_name].presence || generate_pack_name(url)
      locales = params[:locales].presence&.split(',')&.map(&:strip) || ['en']

      if url.blank?
        flash[:alert] = "Please provide a URL to scrape."
        render :new, status: :unprocessable_entity
        return
      end

      begin
        scraper = Pwb::WebsiteScraper::Scraper.new(
          base_url: url,
          pack_name: pack_name,
          locales: locales
        )

        scraper.scrape!
        output_path = scraper.generate_seed_pack!

        flash[:notice] = "Successfully scraped website. Seed pack created at: #{output_path}"
        redirect_to tenant_admin_site_import_path(pack_name)
      rescue StandardError => e
        Rails.logger.error "[SiteImport] Scrape failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        flash[:alert] = "Failed to scrape website: #{e.message}"
        render :new, status: :unprocessable_entity
      end
    end

    def show
      # @import_pack set by before_action
      @pack_config = load_pack_config(@import_pack)
      @content_files = list_content_files(@import_pack)
    end

    def destroy
      pack_path = import_packs_path.join(@import_pack)

      if pack_path.exist?
        FileUtils.rm_rf(pack_path)
        flash[:notice] = "Import pack '#{@import_pack}' deleted successfully."
      else
        flash[:alert] = "Import pack not found."
      end

      redirect_to tenant_admin_site_imports_path
    end

    def apply
      website_id = params[:website_id]
      website = Pwb::Website.unscoped.find_by(id: website_id)

      unless website
        flash[:alert] = "Website not found."
        redirect_to tenant_admin_site_import_path(@import_pack)
        return
      end

      begin
        # Load the seed pack from the import location
        pack_path = import_packs_path.join(@import_pack)
        pack = Pwb::SeedPack.new(@import_pack, base_path: pack_path.parent)
        pack.apply!(website: website)

        flash[:notice] = "Successfully applied import pack to website '#{website.subdomain}'."
        redirect_to tenant_admin_website_path(website)
      rescue StandardError => e
        Rails.logger.error "[SiteImport] Apply failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        flash[:alert] = "Failed to apply import pack: #{e.message}"
        redirect_to tenant_admin_site_import_path(@import_pack)
      end
    end

    private

    def set_import_pack
      @import_pack = params[:id]

      unless import_packs_path.join(@import_pack).exist?
        flash[:alert] = "Import pack not found."
        redirect_to tenant_admin_site_imports_path
      end
    end

    def import_packs_path
      Rails.root.join('db', 'seeds', 'site_import_packs')
    end

    def list_import_packs
      return [] unless import_packs_path.exist?

      import_packs_path.children.select(&:directory?).reject { |d| d.basename.to_s.start_with?('.') }.map do |dir|
        pack_yml = dir.join('pack.yml')
        config = pack_yml.exist? ? YAML.safe_load(File.read(pack_yml), permitted_classes: [Symbol]) : {}

        {
          name: dir.basename.to_s,
          display_name: config['display_name'] || dir.basename.to_s.titleize,
          description: config['description'],
          created_at: dir.ctime,
          path: dir
        }
      end.sort_by { |p| p[:created_at] }.reverse
    end

    def load_pack_config(pack_name)
      pack_yml = import_packs_path.join(pack_name, 'pack.yml')
      return {} unless pack_yml.exist?

      YAML.safe_load(File.read(pack_yml), permitted_classes: [Symbol]) || {}
    end

    def list_content_files(pack_name)
      content_dir = import_packs_path.join(pack_name, 'content')
      return [] unless content_dir.exist?

      content_dir.children.select { |f| f.extname == '.yml' }.map do |file|
        content = begin
          YAML.safe_load(File.read(file), permitted_classes: [Symbol])
        rescue StandardError
          {}
        end
        {
          name: file.basename('.yml').to_s,
          path: file,
          content: content
        }
      end
    end

    def generate_pack_name(url)
      uri = URI.parse(url)
      host = uri.host.to_s.gsub(/^www\./, '')
      host.parameterize.underscore
    rescue StandardError
      "import_#{Time.current.to_i}"
    end
  end
end
