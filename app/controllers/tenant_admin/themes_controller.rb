# frozen_string_literal: true

module TenantAdmin
  # Theme and palette management dashboard controller
  #
  # Provides overview of available themes and color palettes,
  # showing which websites use which themes and palettes.
  class ThemesController < TenantAdminController
    # GET /tenant_admin/themes
    def index
      @themes = build_theme_list
      @distribution = theme_distribution
      @palette_usage = palette_usage_stats
    end

    # GET /tenant_admin/themes/:id
    def show
      @theme = Pwb::Theme.find_by(name: params[:id])

      unless @theme
        redirect_to tenant_admin_themes_path, alert: "Theme '#{params[:id]}' not found"
        return
      end

      @websites = Pwb::Website.unscoped.where(theme_name: @theme.name).order(created_at: :desc)
      @palette_stats = build_palette_stats(@theme)
    end

    # GET /tenant_admin/themes/:id/websites
    def websites
      @theme = Pwb::Theme.find_by(name: params[:id])

      unless @theme
        redirect_to tenant_admin_themes_path, alert: "Theme '#{params[:id]}' not found"
        return
      end

      websites = Pwb::Website.unscoped.where(theme_name: @theme.name).order(created_at: :desc)
      @pagy, @websites = pagy(websites, limit: 20)
    end

    private

    def build_theme_list
      Pwb::Theme.enabled.map do |theme|
        website_count = Pwb::Website.unscoped.where(theme_name: theme.name).count

        OpenStruct.new(
          name: theme.name,
          friendly_name: theme.friendly_name,
          description: theme.description,
          version: theme.version,
          tags: theme.tags,
          palette_count: theme.palettes.count,
          palettes: theme.palettes,
          website_count: website_count,
          default_palette_id: theme.default_palette_id
        )
      end
    end

    def theme_distribution
      total = Pwb::Website.unscoped.count
      distribution = Pwb::Website.unscoped.group(:theme_name).count

      percentages = distribution.transform_values do |count|
        total > 0 ? (count.to_f / total * 100).round(1) : 0
      end

      {
        total: total,
        distribution: distribution,
        percentages: percentages
      }
    end

    def palette_usage_stats
      # Get palette usage across all websites
      Pwb::Website.unscoped
        .where.not(selected_palette: [nil, ''])
        .group(:theme_name, :selected_palette)
        .count
    end

    def build_palette_stats(theme)
      websites = Pwb::Website.unscoped.where(theme_name: theme.name)

      theme.palettes.map do |palette_id, palette_config|
        # Count websites using this palette (either explicitly or as default)
        explicit_count = websites.where(selected_palette: palette_id).count

        # If this is the default palette, also count websites with no palette set
        default_count = if palette_config['is_default']
          websites.where(selected_palette: [nil, '']).count
        else
          0
        end

        OpenStruct.new(
          id: palette_id,
          name: palette_config['name'],
          description: palette_config['description'],
          preview_colors: palette_config['preview_colors'] || [],
          colors: palette_config['colors'] || {},
          is_default: palette_config['is_default'],
          website_count: explicit_count + default_count,
          explicit_count: explicit_count,
          default_count: default_count
        )
      end
    end
  end
end
