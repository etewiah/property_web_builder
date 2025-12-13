# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe "tls:check rake task" do
  before(:all) do
    Rake.application.rake_require 'tasks/tls'
    Rake::Task.define_task(:environment)
  end

  before(:each) do
    Rake::Task['tls:check'].reenable
  end

  let(:platform_domain) { Pwb::Website.platform_domains.first }

  let!(:live_website) do
    FactoryBot.create(:pwb_website,
      subdomain: 'active-tenant',
      provisioning_state: 'live')
  end

  let!(:suspended_website) do
    FactoryBot.create(:pwb_website,
      subdomain: 'suspended-tenant',
      provisioning_state: 'suspended')
  end

  let!(:custom_domain_website) do
    FactoryBot.create(:pwb_website,
      subdomain: 'custom-tenant',
      custom_domain: 'myrealestate.com',
      custom_domain_verified: true,
      provisioning_state: 'live')
  end

  describe "platform subdomain verification" do
    context "when subdomain exists and is live" do
      it "outputs OK status" do
        expect {
          Rake::Task['tls:check'].invoke("active-tenant.#{platform_domain}")
        }.to output(/Status: ✓ OK/).to_stdout
      end

      it "shows website details" do
        expect {
          Rake::Task['tls:check'].invoke("active-tenant.#{platform_domain}")
        }.to output(/Website ID:.*\nSubdomain: active-tenant/).to_stdout
      end
    end

    context "when subdomain exists but is suspended" do
      it "outputs FORBIDDEN status" do
        expect {
          Rake::Task['tls:check'].invoke("suspended-tenant.#{platform_domain}")
        }.to output(/Status: ✗ FORBIDDEN.*Website suspended/m).to_stdout
      end
    end

    context "when subdomain does not exist" do
      it "outputs NOT FOUND status" do
        expect {
          Rake::Task['tls:check'].invoke("nonexistent.#{platform_domain}")
        }.to output(/Status: \? NOT FOUND/).to_stdout
      end

      it "shows subdomain not registered reason" do
        expect {
          Rake::Task['tls:check'].invoke("nonexistent.#{platform_domain}")
        }.to output(/Reason: Subdomain not registered/).to_stdout
      end
    end

    context "when subdomain is reserved (www, admin)" do
      it "returns OK for www" do
        expect {
          Rake::Task['tls:check'].invoke("www.#{platform_domain}")
        }.to output(/Status: ✓ OK.*Reserved subdomain/m).to_stdout
      end

      it "returns OK for admin" do
        Rake::Task['tls:check'].reenable
        expect {
          Rake::Task['tls:check'].invoke("admin.#{platform_domain}")
        }.to output(/Status: ✓ OK.*Reserved subdomain/m).to_stdout
      end
    end

    context "when it's the bare platform domain" do
      it "returns OK" do
        expect {
          Rake::Task['tls:check'].invoke(platform_domain)
        }.to output(/Status: ✓ OK.*Platform domain/m).to_stdout
      end
    end
  end

  describe "custom domain verification" do
    context "when custom domain is registered and verified" do
      it "returns OK" do
        expect {
          Rake::Task['tls:check'].invoke('myrealestate.com')
        }.to output(/Status: ✓ OK/).to_stdout
      end

      it "shows custom domain details" do
        expect {
          Rake::Task['tls:check'].invoke('myrealestate.com')
        }.to output(/Custom domain: myrealestate.com/).to_stdout
      end
    end

    context "when custom domain is not registered" do
      it "returns NOT FOUND" do
        expect {
          Rake::Task['tls:check'].invoke('unknown-domain.com')
        }.to output(/Status: \? NOT FOUND.*Custom domain not registered/m).to_stdout
      end
    end
  end

  describe "provisioning states" do
    it "allows 'ready' state" do
      live_website.update!(provisioning_state: 'ready')
      expect {
        Rake::Task['tls:check'].invoke("active-tenant.#{platform_domain}")
      }.to output(/Status: ✓ OK/).to_stdout
    end

    it "allows websites still provisioning (configuring state)" do
      Rake::Task['tls:check'].reenable
      live_website.update!(provisioning_state: 'configuring')
      expect {
        Rake::Task['tls:check'].invoke("active-tenant.#{platform_domain}")
      }.to output(/Status: ✓ OK.*provisioning in progress/m).to_stdout
    end

    it "forbids 'terminated' state" do
      Rake::Task['tls:check'].reenable
      live_website.update!(provisioning_state: 'terminated')
      expect {
        Rake::Task['tls:check'].invoke("active-tenant.#{platform_domain}")
      }.to output(/Status: ✗ FORBIDDEN.*terminated/m).to_stdout
    end

    it "forbids 'failed' state" do
      Rake::Task['tls:check'].reenable
      live_website.update!(provisioning_state: 'failed')
      expect {
        Rake::Task['tls:check'].invoke("active-tenant.#{platform_domain}")
      }.to output(/Status: ✗ FORBIDDEN.*failed/m).to_stdout
    end
  end

  describe "missing domain argument" do
    it "outputs usage message and exits" do
      expect {
        begin
          Rake::Task['tls:check'].invoke(nil)
        rescue SystemExit
          # Expected
        end
      }.to output(/Usage: rake tls:check/).to_stdout
    end
  end
end
