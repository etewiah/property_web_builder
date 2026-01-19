
# Diagnostic script - Check 2
puts "Checking Pwb::Content count..."
total = Pwb::Content.count
puts "Total Pwb::Content records: #{total}"

if total > 0
  first_content = Pwb::Content.first
  puts "First content ID: #{first_content.id}"
  puts "Translations type: #{first_content.translations.class}"
  puts "Translations raw: #{first_content.translations.inspect}"
end
