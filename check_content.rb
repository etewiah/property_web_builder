page = Pwb::Page.find_by_slug("home")
pc = page.page_contents.find { |pc| pc.page_part_key == "landing_hero" }
content = pc.content

if content
  puts "Content ID: #{content.id}"
  puts "Raw (default):"
  puts content.raw
  puts "Raw (en):"
  puts content.raw_en
  puts "Raw (es):"
  puts content.raw_es
else
  puts "Content not found"
end
