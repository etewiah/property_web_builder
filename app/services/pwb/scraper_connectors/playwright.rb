# frozen_string_literal: true

require "open3"
require "json"
require "tempfile"

module Pwb
  module ScraperConnectors
    # Playwright connector for JavaScript-rendered pages.
    # Uses Node.js with Playwright to render pages with full JavaScript execution.
    # Falls back to HTTP connector if Playwright is not available.
    #
    # Requirements:
    # - Node.js installed and in PATH
    # - Playwright installed: npm install playwright
    # - Chromium browser: npx playwright install chromium
    #
    # Usage:
    #   connector = Pwb::ScraperConnectors::Playwright.new(url, wait_for: 3000)
    #   result = connector.fetch
    #
    class Playwright < Base
      TIMEOUT = 60 # seconds
      DEFAULT_WAIT = 2000 # milliseconds to wait for dynamic content
      MIN_CONTENT_LENGTH = 1000

      def fetch
        unless playwright_available?
          Rails.logger.warn("[Playwright] Playwright not available, falling back to HTTP connector")
          return Http.new(@url, **@options).fetch
        end

        result = execute_playwright_script
        return result if result[:success] == false

        validate_content!(result[:html])
        check_for_blocking!(result[:html])

        {
          success: true,
          html: result[:html],
          content_type: "text/html",
          final_url: result[:final_url] || @url,
          connector: "playwright"
        }
      rescue BlockedError, InvalidContentError => e
        {
          success: false,
          error: e.message,
          error_class: e.class.name
        }
      rescue StandardError => e
        Rails.logger.error("[Playwright] Execution failed: #{e.message}")
        {
          success: false,
          error: "Browser error: #{e.message}",
          error_class: e.class.name
        }
      end

      def self.available?
        new("https://example.com").playwright_available?
      end

      def playwright_available?
        return @playwright_available if defined?(@playwright_available)

        @playwright_available = check_playwright_installed
      end

      private

      def check_playwright_installed
        # Check if node is available
        _, status = Open3.capture2("which", "node")
        return false unless status.success?

        # Check if playwright is installed
        stdout, status = Open3.capture2("node", "-e", "require('playwright')")
        status.success?
      rescue StandardError
        false
      end

      def execute_playwright_script
        script = generate_playwright_script
        script_file = Tempfile.new(["playwright_scrape", ".js"])
        script_file.write(script)
        script_file.close

        stdout, stderr, status = Open3.capture3(
          "node", script_file.path,
          timeout: TIMEOUT
        )

        script_file.unlink

        unless status.success?
          error_msg = stderr.presence || "Unknown playwright error"
          return { success: false, error: "Playwright execution failed: #{error_msg}" }
        end

        result = JSON.parse(stdout)
        if result["error"]
          { success: false, error: result["error"] }
        else
          { success: true, html: result["html"], final_url: result["url"] }
        end
      rescue JSON::ParserError
        { success: false, error: "Failed to parse Playwright response" }
      rescue Timeout::Error
        { success: false, error: "Browser timeout after #{TIMEOUT} seconds" }
      end

      def generate_playwright_script
        wait_time = options[:wait_for] || DEFAULT_WAIT
        wait_until = options[:wait_until] || "networkidle"

        <<~JAVASCRIPT
          const { chromium } = require('playwright');

          (async () => {
            let browser;
            try {
              browser = await chromium.launch({
                headless: true,
                args: [
                  '--no-sandbox',
                  '--disable-setuid-sandbox',
                  '--disable-dev-shm-usage',
                  '--disable-accelerated-2d-canvas',
                  '--disable-gpu'
                ]
              });

              const context = await browser.newContext({
                userAgent: '#{user_agent}',
                viewport: { width: 1920, height: 1080 },
                locale: 'en-GB',
                timezoneId: 'Europe/London'
              });

              const page = await context.newPage();

              // Block unnecessary resources to speed up loading
              await page.route('**/*', (route) => {
                const resourceType = route.request().resourceType();
                if (['font', 'media'].includes(resourceType)) {
                  route.abort();
                } else {
                  route.continue();
                }
              });

              await page.goto('#{escape_js(@url)}', {
                waitUntil: '#{wait_until}',
                timeout: #{(TIMEOUT - 5) * 1000}
              });

              // Wait additional time for dynamic content
              await page.waitForTimeout(#{wait_time});

              // Try to close cookie consent dialogs
              try {
                await page.click('[class*="cookie"] button, [id*="cookie"] button, [class*="consent"] button', { timeout: 1000 });
                await page.waitForTimeout(500);
              } catch (e) {
                // No cookie dialog found, continue
              }

              const html = await page.content();
              const url = page.url();

              console.log(JSON.stringify({ html, url }));

            } catch (error) {
              console.log(JSON.stringify({ error: error.message }));
            } finally {
              if (browser) {
                await browser.close();
              }
            }
          })();
        JAVASCRIPT
      end

      def user_agent
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      end

      def escape_js(str)
        str.gsub("'", "\\\\'").gsub("\n", "\\n")
      end

      def validate_content!(html)
        if html.nil? || html.length < MIN_CONTENT_LENGTH
          raise InvalidContentError, "Content too short (#{html&.length || 0} bytes). Page may not have loaded."
        end
      end

      def check_for_blocking!(html)
        blocked_patterns = [
          /cloudflare/i,
          /checking your browser/i,
          /please wait while we verify/i,
          /just a moment/i,
          /attention required/i,
          /access denied/i,
          /ray id:/i
        ]

        blocked_patterns.each do |pattern|
          if html.match?(pattern) && html.length < 50_000
            raise BlockedError, "Request may have been blocked by bot protection."
          end
        end
      end
    end
  end
end
