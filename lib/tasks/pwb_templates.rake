# frozen_string_literal: true

namespace :pwb do
  namespace :templates do
    desc "Extract page part templates from database to .liquid files"
    task extract: :environment do
      output_dir = Rails.root.join("app/views/pwb/page_parts")
      FileUtils.mkdir_p(output_dir)

      extracted_count = 0
      skipped_count = 0
      error_count = 0

      puts "Extracting templates from database to #{output_dir}..."
      puts "-" * 80

      Pwb::PagePart.find_each do |page_part|
        next if page_part.template.blank?

        file_path = output_dir.join("#{page_part.page_part_key}.liquid")

        # Skip if file already exists and content is different
        if File.exist?(file_path)
          existing = File.read(file_path)
          if existing == page_part.template
            puts "✓ SKIP: #{page_part.page_part_key}.liquid (already exists with same content)"
            skipped_count += 1
            next
          else
            puts "⚠ WARNING: #{file_path.relative_path_from(Rails.root)} exists with different content"
            puts "  Database version: #{page_part.template.length} chars"
            puts "  File version: #{existing.length} chars"
            puts "  Skipping to avoid overwrite. Review manually."
            error_count += 1
            next
          end
        end

        begin
          File.write(file_path, page_part.template)
          puts "✓ EXTRACTED: #{page_part.page_part_key}.liquid (#{page_part.template.length} chars)"
          extracted_count += 1
        rescue => e
          puts "✗ ERROR: Failed to extract #{page_part.page_part_key}: #{e.message}"
          error_count += 1
        end
      end

      puts "-" * 80
      puts "Extraction complete!"
      puts "  Extracted: #{extracted_count} files"
      puts "  Skipped: #{skipped_count} files (already match)"
      puts "  Errors/Warnings: #{error_count}" if error_count > 0
      puts "\nNext step: Run 'rake pwb:templates:verify' to verify extraction"
    end

    desc "Verify extracted templates match database content"
    task verify: :environment do
      template_dir = Rails.root.join("app/views/pwb/page_parts")
      
      unless Dir.exist?(template_dir)
        puts "✗ ERROR: Template directory does not exist: #{template_dir}"
        puts "Run 'rake pwb:templates:extract' first"
        exit 1
      end

      mismatches = []
      verified_count = 0
      missing_in_db = []
      missing_in_files = []

      puts "Verifying templates..."
      puts "-" * 80

      # Check all database templates have matching files
      Pwb::PagePart.where.not(template: [nil, ""]).find_each do |page_part|
        file_path = template_dir.join("#{page_part.page_part_key}.liquid")
        
        unless File.exist?(file_path)
          missing_in_files << page_part.page_part_key
          puts "✗ MISSING FILE: #{page_part.page_part_key}.liquid (exists in DB but not in files)"
          next
        end

        file_content = File.read(file_path)
        if file_content == page_part.template
          puts "✓ MATCH: #{page_part.page_part_key}.liquid"
          verified_count += 1
        else
          mismatches << {
            key: page_part.page_part_key,
            db_size: page_part.template.length,
            file_size: file_content.length
          }
          puts "✗ MISMATCH: #{page_part.page_part_key}.liquid"
          puts "  Database: #{page_part.template.length} chars"
          puts "  File: #{file_content.length} chars"
        end
      end

      # Check for orphaned files (files without database entries)
      Dir.glob(template_dir.join("*.liquid")).each do |file_path|
        key = File.basename(file_path, ".liquid")
        unless Pwb::PagePart.exists?(page_part_key: key)
          missing_in_db << key
          puts "⚠ ORPHANED FILE: #{key}.liquid (file exists but not in database)"
        end
      end

      puts "-" * 80
      puts "Verification complete!"
      puts "  Verified: #{verified_count} templates match"
      
      if mismatches.any?
        puts "  ✗ Mismatches: #{mismatches.length}"
        puts "\nMismatched files:"
        mismatches.each do |m|
          puts "  - #{m[:key]}.liquid (DB: #{m[:db_size]} chars, File: #{m[:file_size]} chars)"
        end
      end

      if missing_in_files.any?
        puts "  ✗ Missing files: #{missing_in_files.length}"
        puts "\nMissing template files:"
        missing_in_files.each { |key| puts "  - #{key}.liquid" }
      end

      if missing_in_db.any?
        puts "  ⚠ Orphaned files: #{missing_in_db.length}"
        puts "\nOrphaned template files (no database entry):"
        missing_in_db.each { |key| puts "  - #{key}.liquid" }
      end

      if mismatches.any? || missing_in_files.any?
        puts "\n✗ VERIFICATION FAILED"
        puts "Fix mismatches and missing files, then run verification again"
        exit 1
      else
        puts "\n✓ VERIFICATION PASSED"
        puts "All templates verified successfully!"
        
        if missing_in_db.any?
          puts "\nNote: #{missing_in_db.length} orphaned files found (this is OK if intentional)"
        end
      end
    end

    desc "List all page parts with their template sources"
    task list: :environment do
      puts "Page Part Templates"
      puts "=" * 80
      puts sprintf("%-30s %-15s %-10s", "KEY", "SOURCE", "SIZE")
      puts "-" * 80

      Pwb::PagePart.find_each do |page_part|
        # Determine source using same logic as template_content
        source = if page_part[:template].present?
          "Database"
        elsif File.exist?(Rails.root.join("app/themes/#{page_part.website&.theme_name || 'default'}/page_parts/#{page_part.page_part_key}.liquid"))
          "Theme File"
        elsif File.exist?(Rails.root.join("app/views/pwb/page_parts/#{page_part.page_part_key}.liquid"))
          "Default File"
        else
          "Missing"
        end

        size = page_part.template_content.length
        puts sprintf("%-30s %-15s %-10s", page_part.page_part_key, source, "#{size} chars")
      end

      puts "-" * 80
      puts "Total: #{Pwb::PagePart.count} page parts"
    end

    desc "Lint templates for framework-specific classes and non-semantic patterns"
    task lint: :environment do
      template_dir = Rails.root.join("app/views/pwb/page_parts")
      partials_dir = Rails.root.join("app/views/pwb/partials")
      
      # Patterns to flag as problematic
      forbidden_patterns = {
        # Tailwind utility classes
        /\btext-\w+-\d+\b/ => "Tailwind text color class",
        /\bbg-\w+-\d+\b/ => "Tailwind background color class",
        /\bp-\d+\b/ => "Tailwind padding utility",
        /\bm-\d+\b/ => "Tailwind margin utility",
        /\bw-\d+\b/ => "Tailwind width utility",
        /\bh-\d+\b/ => "Tailwind height utility",
        /\bgrid-cols-\d+(?!\s|">)/ => "Tailwind grid class (use pwb-grid-cols-*)",
        /\bgap-\d+\b/ => "Tailwind gap utility",
        /\brounded-\w+\b(?!pwb)/ => "Tailwind border radius",
        
        # Bootstrap classes
        /\bcol-(?:xs|sm|md|lg|xl)-\d+\b/ => "Bootstrap column class",
        /\bbtn-(?:primary|secondary|success|danger|warning|info)(?!\s*pwb)/ => "Bootstrap button class",
        /\bcard(?!\s*pwb-card)/ => "Bootstrap card class (use pwb-card)",
        /\bjumbotron\b/ => "Bootstrap jumbotron (use pwb-hero)",
        /\bcontainer-fluid(?!\s*pwb)/ => "Bootstrap container",
        
        # Generic forbidden patterns
        /\balert-\w+(?!\s*pwb)/ => "Framework alert class",
        /\bbadge-\w+(?!\s*pwb)/ => "Framework badge class"
      }
      
      issues_found = []
      files_checked = 0
      
      puts "Linting Liquid templates..."
      puts "=" * 80
      
      # Check all template files
      [template_dir, partials_dir].each do |dir|
        next unless Dir.exist?(dir)
        
        Dir.glob(dir.join("*.liquid")).each do |file_path|
          files_checked += 1
          file_content = File.read(file_path)
          relative_path = Pathname.new(file_path).relative_path_from(Rails.root)
          
          file_content.lines.each_with_index do |line, index|
            line_num = index + 1
            
            forbidden_patterns.each do |pattern, description|
              if line.match?(pattern)
                matches = line.scan(pattern)
                matches.each do |match|
                  issues_found << {
                    file: relative_path.to_s,
                    line: line_num,
                    issue: description,
                    matched: match.is_a?(Array) ? match[0] : match,
                    line_content: line.strip
                  }
                end
              end
            end
          end
        end
      end
      
      puts "Checked #{files_checked} template files"
      puts "-" * 80
      
      if issues_found.any?
        puts "\n⚠ ISSUES FOUND: #{issues_found.length}"
        puts "\nTemplates should only use semantic PWB classes (e.g., pwb-btn, pwb-card)"
        puts "See docs/SEMANTIC_CSS_CLASSES.md for the complete list"
        puts "\nIssues by file:\n\n"
        
        issues_found.group_by { |i| i[:file] }.each do |file, file_issues|
          puts "📄 #{file} (#{file_issues.count} issues)"
          file_issues.each do |issue|
            puts "   Line #{issue[:line]}: #{issue[:issue]}"
            puts "   Found: '#{issue[:matched]}'"
            puts "   #{issue[:line_content]}"
            puts ""
          end
        end
        
        puts "-" * 80
        puts "✗ LINT FAILED"
        puts "Fix the issues above to ensure theme compatibility"
        puts "\nCommon fixes:"
        puts "  - Replace Bootstrap grid (col-md-4) with pwb-grid + pwb-grid-cols-*"
        puts "  - Replace framework buttons (btn-primary) with pwb-btn pwb-btn-primary"
        puts "  - Replace Tailwind utilities (text-blue-600) with semantic classes or theme CSS variables"
        exit 1
      else
        puts "\n✓ LINT PASSED"
        puts "All templates use semantic class names"
        puts "Templates are theme-compatible! 🎉"
      end
    end
  end
end

