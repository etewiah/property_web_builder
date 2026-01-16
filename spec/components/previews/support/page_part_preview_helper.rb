# frozen_string_literal: true

# Helper module for Lookbook page part previews
# Provides mock data and theme switching utilities
module PagePartPreviewHelper
  extend ActiveSupport::Concern

  # Theme palettes based on app/themes/config.json
  PALETTES = {
    default: {
      name: "Default (Bristol)",
      primary_color: "#e91b23",
      secondary_color: "#2c3e50",
      accent_color: "#3498db",
      background_color: "#ffffff",
      text_color: "#333333"
    },
    brisbane: {
      name: "Brisbane Luxury",
      primary_color: "#c9a962",
      secondary_color: "#1a1a2e",
      accent_color: "#16213e",
      background_color: "#fafafa",
      text_color: "#2d2d2d"
    },
    bologna: {
      name: "Bologna Modern",
      primary_color: "#c45d3e",
      secondary_color: "#5c6b4d",
      accent_color: "#d4a574",
      background_color: "#faf9f7",
      text_color: "#3d3d3d"
    },
    brussels: {
      name: "Brussels Fresh",
      primary_color: "#7cb342",
      secondary_color: "#2d3436",
      accent_color: "#8bc34a",
      background_color: "#fafafa",
      text_color: "#2d3436"
    }
  }.freeze

  # Sample content for page parts
  SAMPLE_DATA = {
    "heroes/hero_centered" => {
      pretitle: "Welcome to",
      title: "Find Your Perfect Home",
      subtitle: "Discover properties that match your lifestyle and budget",
      cta_text: "Browse Properties",
      cta_link: "/buy",
      cta_secondary_text: "Contact Us",
      cta_secondary_link: "/contact-us",
      background_image: "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1920&q=80"
    },
    "heroes/hero_split" => {
      pretitle: "Luxury Living",
      title: "Modern Homes for Modern Families",
      subtitle: "Experience the finest properties",
      description: "We specialize in premium real estate, connecting discerning buyers with exceptional homes that exceed expectations.",
      cta_text: "View Properties",
      cta_link: "/buy",
      cta_secondary_text: "Learn More",
      cta_secondary_link: "/about-us",
      image: "https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800&q=80",
      image_alt: "Modern luxury home exterior"
    },
    "heroes/hero_search" => {
      title: "Find Your Dream Property",
      subtitle: "Search through thousands of listings",
      background_image: "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1920&q=80",
      search_action: "/search",
      label_buy: "Buy",
      label_rent: "Rent",
      placeholder_location: "Enter location...",
      label_all_types: "All Property Types",
      button_text: "Search"
    },
    "features/feature_grid_3col" => {
      section_pretitle: "Why Choose Us",
      section_title: "Our Services",
      section_subtitle: "We provide comprehensive real estate services",
      feature_1_icon: "home",
      feature_1_title: "Property Sales",
      feature_1_description: "Expert guidance through every step of buying or selling your property.",
      feature_1_link: "/buy",
      feature_2_icon: "key",
      feature_2_title: "Rentals",
      feature_2_description: "Find the perfect rental property or let us manage yours.",
      feature_2_link: "/rent",
      feature_3_icon: "chart",
      feature_3_title: "Valuations",
      feature_3_description: "Accurate property valuations based on current market data.",
      feature_3_link: "/contact-us"
    },
    "features/feature_cards_icons" => {
      section_title: "What We Offer",
      section_subtitle: "Comprehensive real estate solutions",
      card_1_icon: "building",
      card_1_title: "Property Management",
      card_1_text: "Complete management services for landlords",
      card_1_color: "#3498db",
      card_2_icon: "search",
      card_2_title: "Property Search",
      card_2_text: "Find your ideal property with our tools",
      card_2_color: "#e74c3c",
      card_3_icon: "handshake",
      card_3_title: "Negotiation",
      card_3_text: "Expert negotiation to get the best deal",
      card_3_color: "#2ecc71",
      card_4_icon: "document",
      card_4_title: "Legal Support",
      card_4_text: "Guidance through all legal processes",
      card_4_color: "#9b59b6"
    },
    "cta/cta_banner" => {
      title: "Ready to Find Your New Home?",
      subtitle: "Contact us today and let our experts help you find the perfect property.",
      button_text: "Get Started",
      button_link: "/contact-us",
      button_style: "primary",
      secondary_button_text: "Browse Listings",
      secondary_button_link: "/buy",
      style: "gradient"
    },
    "cta/cta_split_image" => {
      pretitle: "Let's Connect",
      title: "Get Expert Advice Today",
      description: "Our experienced team is ready to help you navigate the real estate market and find your perfect property.",
      features: "Free consultation, Market analysis, Property matching, Negotiation support",
      button_text: "Schedule a Call",
      button_link: "/contact-us",
      image: "https://images.unsplash.com/photo-1560520653-9e0e4c89eb11?w=800&q=80",
      bg_style: "light"
    },
    "testimonials/testimonial_carousel" => {
      section_title: "What Our Clients Say",
      section_subtitle: "Real stories from satisfied customers",
      testimonial_1_text: "The team was incredibly helpful throughout the entire buying process. They found us our dream home!",
      testimonial_1_name: "Sarah Johnson",
      testimonial_1_role: "Homeowner",
      testimonial_1_image: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80",
      testimonial_2_text: "Professional service from start to finish. I would highly recommend them to anyone looking to buy or sell.",
      testimonial_2_name: "Michael Chen",
      testimonial_2_role: "Property Investor",
      testimonial_3_text: "They made selling our house so easy. Got a great price and the process was smooth.",
      testimonial_3_name: "Emma Williams",
      testimonial_3_role: "Seller"
    },
    "stats/stats_counter" => {
      section_title: "Our Track Record",
      section_subtitle: "Numbers that speak for themselves",
      stat_1_value: "500",
      stat_1_label: "Properties Sold",
      stat_1_prefix: "",
      stat_1_suffix: "+",
      stat_2_value: "98",
      stat_2_label: "Client Satisfaction",
      stat_2_suffix: "%",
      stat_3_value: "15",
      stat_3_label: "Years Experience",
      stat_3_suffix: "+",
      stat_4_value: "50",
      stat_4_label: "Expert Agents",
      style: "cards"
    },
    "faqs/faq_accordion" => {
      section_title: "Frequently Asked Questions",
      section_subtitle: "Find answers to common questions",
      faq_1_question: "How do I start the buying process?",
      faq_1_answer: "Contact us for a free consultation. We'll discuss your requirements, budget, and preferences to find the perfect property.",
      faq_2_question: "What are your fees?",
      faq_2_answer: "Our fees vary depending on the service. For buyers, our service is typically free as we're paid by the seller. Contact us for specific details.",
      faq_3_question: "How long does it take to sell a property?",
      faq_3_answer: "On average, properties sell within 2-3 months, but this varies by location, price, and market conditions.",
      faq_4_question: "Do you offer property management?",
      faq_4_answer: "Yes, we offer comprehensive property management services for landlords, including tenant finding, maintenance, and rent collection."
    }
  }.freeze

  # Build a page_part hash structure that matches Liquid template expectations
  def build_page_part(key, overrides = {})
    data = (SAMPLE_DATA[key] || {}).merge(overrides)
    
    # Convert to nested hash structure expected by Liquid templates
    # e.g., page_part["title"]["content"]
    data.transform_values do |value|
      { "content" => value }
    end
  end

  # Generate CSS custom properties for a theme palette
  def palette_css_vars(theme)
    palette = PALETTES[theme.to_sym] || PALETTES[:default]
    
    <<~CSS
      --pwb-primary: #{palette[:primary_color]};
      --pwb-secondary: #{palette[:secondary_color]};
      --pwb-accent: #{palette[:accent_color]};
      --pwb-background: #{palette[:background_color]};
      --pwb-text: #{palette[:text_color]};
    CSS
  end

  # Wrap content with theme styles
  def with_theme(theme, &block)
    content_tag(:div, 
      style: palette_css_vars(theme),
      class: "pwb-preview pwb-theme-#{theme}",
      &block
    )
  end
end
