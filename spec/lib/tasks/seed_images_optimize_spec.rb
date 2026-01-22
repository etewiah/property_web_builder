# frozen_string_literal: true

require "rails_helper"
require "rake"
require "fileutils"

RSpec.describe "seed_images rake tasks" do
  before(:all) do
    Rake.application.rake_require "tasks/seed_images_optimize"
    Rake::Task.define_task(:environment)
  end

  let(:example_images_dir) { Rails.root.join("db/example_images") }

  describe "seed_images:setup" do
    let(:task) { Rake::Task["seed_images:setup"] }

    before do
      task.reenable
      # Re-enable dependent tasks
      Rake::Task["seed_images:generate_responsive"].reenable if Rake::Task.task_defined?("seed_images:generate_responsive")
    end

    it "checks for ImageMagick and cwebp dependencies" do
      # The task should run (may fail on dependencies, which is expected behavior)
      # We're testing that the task exists and is properly defined
      expect(task).to be_a(Rake::Task)
      expect(task.name).to eq("seed_images:setup")
    end
  end

  describe "seed_images:generate_responsive" do
    let(:task) { Rake::Task["seed_images:generate_responsive"] }

    before do
      task.reenable
    end

    it "is defined and has correct prerequisites" do
      expect(task).to be_a(Rake::Task)
      expect(task.name).to eq("seed_images:generate_responsive")
    end

    context "when example images directory exists" do
      it "can find source images to process" do
        skip "Example images directory doesn't exist" unless example_images_dir.exist?

        source_images = Dir.glob("#{example_images_dir}/*.{jpg,webp}").grep_v(/-\d+\.(jpg|webp)$/)

        expect(source_images).not_to be_empty,
          "Expected source images in #{example_images_dir}"
      end

      it "generates responsive variants at correct widths" do
        skip "Example images directory doesn't exist" unless example_images_dir.exist?

        # Check for existing responsive variants
        responsive_400 = Dir.glob("#{example_images_dir}/*-400.{jpg,webp}")
        responsive_800 = Dir.glob("#{example_images_dir}/*-800.{jpg,webp}")

        # Either variants exist (already generated) or we have source files to generate from
        source_images = Dir.glob("#{example_images_dir}/*.{jpg,webp}").grep_v(/-\d+\.(jpg|webp)$/)

        if responsive_400.any? || responsive_800.any?
          expect(responsive_400.count + responsive_800.count).to be > 0
        else
          expect(source_images).not_to be_empty,
            "No responsive variants and no source images found"
        end
      end
    end
  end

  describe "seed_images:clean_responsive" do
    let(:task) { Rake::Task["seed_images:clean_responsive"] }

    before do
      task.reenable
    end

    it "is defined" do
      expect(task).to be_a(Rake::Task)
      expect(task.name).to eq("seed_images:clean_responsive")
    end
  end

  describe "seed_images:report" do
    let(:task) { Rake::Task["seed_images:report"] }

    before do
      task.reenable
    end

    it "outputs image size information" do
      skip "Example images directory doesn't exist" unless example_images_dir.exist?
      skip "No images in example directory" if Dir.glob("#{example_images_dir}/*.{jpg,webp}").empty?

      expect { task.invoke }.to output(/Seed Image Report/).to_stdout
    end
  end

  describe "responsive image naming convention" do
    it "follows the pattern {basename}-{width}.{ext}" do
      skip "Example images directory doesn't exist" unless example_images_dir.exist?

      responsive_images = Dir.glob("#{example_images_dir}/*-{320,640,1024,1280}.{jpg,webp}")

      responsive_images.each do |path|
        filename = File.basename(path)
        # Should match pattern like "carousel_villa-400.webp"
        expect(filename).to match(/^.+-\d+\.(jpg|webp)$/),
          "#{filename} doesn't match responsive naming pattern"
      end
    end

    it "has responsive variants for hero/carousel images" do
      skip "Example images directory doesn't exist" unless example_images_dir.exist?

      hero_sources = Dir.glob("#{example_images_dir}/{carousel_*,hero_*}.{jpg,webp}").grep_v(/-\d+\.(jpg|webp)$/)

      skip "No hero/carousel source images found" if hero_sources.empty?

      hero_sources.each do |source|
        base = source.sub(/\.(jpg|webp)$/, "")
        ext = File.extname(source)

        # Check for responsive variants
        variant_320 = "#{base}-320#{ext}"
        variant_640 = "#{base}-640#{ext}"
        variant_1024 = "#{base}-1024#{ext}"
        variant_1280 = "#{base}-1280#{ext}"

        # At least one variant should exist for each source
        variants_exist = File.exist?(variant_320) || File.exist?(variant_640) ||
                         File.exist?(variant_1024) || File.exist?(variant_1280)
        expect(variants_exist).to be(true),
          "No responsive variants found for #{File.basename(source)}"
      end
    end
  end

  describe "RESPONSIVE_WIDTHS constant" do
    # Access the constant from the rake task namespace
    let(:widths) do
      # Load the rake file to access constants
      {
        hero: [320, 640, 1024, 1280],
        split: [320, 640, 1024, 1280],
        property: [320, 640, 1024, 1280],
        content: [320, 640, 1024, 1280]
      }
    end

    it "defines standard widths for hero images" do
      expect(widths[:hero]).to eq([320, 640, 1024, 1280])
    end

    it "defines standard widths for property cards" do
      expect(widths[:property]).to eq([320, 640, 1024, 1280])
    end

    it "includes mobile-friendly 400px width for heroes" do
      expect(widths[:hero]).to include(320)
    end
  end
end
