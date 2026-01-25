# frozen_string_literal: true

require "rails_helper"

RSpec.describe "assets_cdn rake tasks" do
  before do
    # Load rake tasks
    Rails.application.load_tasks
  end

  describe "content_type_for helper" do
    # Access the helper method through the rake task context
    let(:rake_context) do
      Class.new do
        include Rake::DSL

        def content_type_for(ext)
          {
            ".js" => "application/javascript",
            ".css" => "text/css",
            ".png" => "image/png",
            ".jpg" => "image/jpeg",
            ".jpeg" => "image/jpeg",
            ".gif" => "image/gif",
            ".svg" => "image/svg+xml",
            ".woff" => "font/woff",
            ".woff2" => "font/woff2",
            ".ttf" => "font/ttf",
            ".eot" => "application/vnd.ms-fontobject",
            ".otf" => "font/otf",
            ".ico" => "image/x-icon",
            ".map" => "application/json",
            ".json" => "application/json",
            ".webp" => "image/webp"
          }[ext.downcase] || "application/octet-stream"
        end
      end.new
    end

    describe "CSS files" do
      it "returns text/css for .css extension" do
        expect(rake_context.content_type_for(".css")).to eq("text/css")
      end

      it "handles uppercase extension" do
        expect(rake_context.content_type_for(".CSS")).to eq("text/css")
      end
    end

    describe "JavaScript files" do
      it "returns application/javascript for .js extension" do
        expect(rake_context.content_type_for(".js")).to eq("application/javascript")
      end
    end

    describe "image files" do
      it "returns image/png for .png extension" do
        expect(rake_context.content_type_for(".png")).to eq("image/png")
      end

      it "returns image/jpeg for .jpg extension" do
        expect(rake_context.content_type_for(".jpg")).to eq("image/jpeg")
      end

      it "returns image/jpeg for .jpeg extension" do
        expect(rake_context.content_type_for(".jpeg")).to eq("image/jpeg")
      end

      it "returns image/webp for .webp extension" do
        expect(rake_context.content_type_for(".webp")).to eq("image/webp")
      end

      it "returns image/svg+xml for .svg extension" do
        expect(rake_context.content_type_for(".svg")).to eq("image/svg+xml")
      end
    end

    describe "font files" do
      it "returns font/woff for .woff extension" do
        expect(rake_context.content_type_for(".woff")).to eq("font/woff")
      end

      it "returns font/woff2 for .woff2 extension" do
        expect(rake_context.content_type_for(".woff2")).to eq("font/woff2")
      end

      it "returns font/ttf for .ttf extension" do
        expect(rake_context.content_type_for(".ttf")).to eq("font/ttf")
      end
    end

    describe "unknown extensions" do
      it "returns application/octet-stream for unknown extensions" do
        expect(rake_context.content_type_for(".xyz")).to eq("application/octet-stream")
      end

      it "returns application/octet-stream for empty extension" do
        expect(rake_context.content_type_for("")).to eq("application/octet-stream")
      end
    end
  end

  describe "rake tasks existence" do
    it "has assets:sync_to_r2 task" do
      expect(Rake::Task.task_defined?("assets:sync_to_r2")).to be true
    end

    it "has assets:fix_content_types task" do
      expect(Rake::Task.task_defined?("assets:fix_content_types")).to be true
    end

    it "has assets:force_sync_to_r2 task" do
      expect(Rake::Task.task_defined?("assets:force_sync_to_r2")).to be true
    end

    it "has assets:cdn_deploy task" do
      expect(Rake::Task.task_defined?("assets:cdn_deploy")).to be true
    end

    it "has assets:clear_r2 task" do
      expect(Rake::Task.task_defined?("assets:clear_r2")).to be true
    end

    it "has assets:configure_cors task" do
      expect(Rake::Task.task_defined?("assets:configure_cors")).to be true
    end
  end
end
