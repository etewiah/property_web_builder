require 'nokogiri'
require 'open-uri'


module Pwb
  class SiteScrapper
    attr_accessor :target_url

    def initialize(target_url)
      self.target_url = target_url
    end

    def retrieve 
      # just a proof of concept at this stage
      properties = []
      property_hash = {}

      # Fetch and parse HTML document
      doc = Nokogiri::HTML(open(target_url))

      images = []
      doc.css(".imgvspace").each do |image_tag|
        image_url = image_tag["src"]
        images.push image_url
      end
      property_hash["images"] = images

      property_hash["price_sale_current"] = doc.css('.listing_detail_field2')[2].content

      property_hash["description_en"] = doc.css('.detail_indent').first.content
      property_hash["extras"] = doc.css('.detail_indent').last.content

      # puts "### Search for nodes by css"
      # doc.css('nav ul.menu li a', 'article h2').each do |link|
      #   puts link.content
      # end

      # puts "### Search for nodes by xpath"
      # doc.xpath('//nav//ul//li/a', '//article//h2').each do |link|
      #   puts link.content
      # end

      # puts "### Or mix and match."
      # doc.search('nav ul.menu li a', '//article//h2').each do |link|
      #   puts link.content
      # end

      properties.push property_hash
      return properties
    end



  end
end
