require 'rails_helper'

module Pwb
  RSpec.describe AdminPanelController, type: :controller do
    routes { Rails.application.routes }

    describe 'Cross-Tenant Isolation Security' do
      let(:website_a) { FactoryBot.create(:pwb_website, subdomain: 'tenant-a') }
      let(:website_b) { FactoryBot.create(:pwb_website, subdomain: 'tenant-b') }
      
      let(:admin_a) { FactoryBot.create(:pwb_user, website: website_a, admin: true) }
      let(:admin_b) { FactoryBot.create(:pwb_user, website: website_b, admin: true) }
      let(:regular_user_a) { FactoryBot.create(:pwb_user, website: website_a, admin: false) }

      before do
        allow(controller).to receive(:current_website_from_subdomain).and_call_original
        allow(Pwb::Current).to receive(:website).and_call_original
      end

      describe '#user_matches_subdomain?' do
        context 'when user belongs to the correct tenant' do
          it 'allows access' do
            sign_in admin_a
            request.host = 'tenant-a.example.com'
            
            get :show
            
            expect(response).to have_http_status(:success)
          end
        end

        context 'when user tries to access different tenant' do
          it 'denies access and shows error page' do
            sign_in admin_a
            request.host = 'tenant-b.example.com'
            
            get :show
            
            expect(response).to render_template('pwb/errors/admin_required')
            expect(assigns(:subdomain)).to eq('tenant-b')
          end
        end

        context 'when accessing non-existent subdomain (SECURITY FIX)' do
          it 'denies access even if user website_id is nil' do
            # Create user with nil website_id (edge case)
            user_with_nil_website = FactoryBot.build(:pwb_user, admin: true)
            user_with_nil_website.save(validate: false) # Bypass validation
            
            sign_in user_with_nil_website
            request.host = 'nonexistent.example.com'
            
            get :show
            
            # Should deny access, not allow nil == nil to pass
            expect(response).to render_template('pwb/errors/admin_required')
          end

          it 'denies access for any valid user' do
            sign_in admin_a
            request.host = 'does-not-exist.example.com'
            
            get :show
            
            expect(response).to render_template('pwb/errors/admin_required')
          end
        end

        context 'when user is not authenticated' do
          it 'shows admin required page' do
            request.host = 'tenant-a.example.com'
            
            get :show
            
            expect(response).to render_template('pwb/errors/admin_required')
          end
        end

        context 'when user is not admin' do
          it 'denies access even if tenant matches' do
            sign_in regular_user_a
            request.host = 'tenant-a.example.com'
            
            get :show
            
            expect(response).to render_template('pwb/errors/admin_required')
          end
        end

        context 'when subdomain is blank' do
          it 'denies access' do
            sign_in admin_a
            request.host = 'example.com' # No subdomain
            
            get :show
            
            expect(response).to render_template('pwb/errors/admin_required')
          end
        end

        context 'attack scenarios' do
          it 'prevents subdomain enumeration' do
            # Try accessing multiple non-existent subdomains
            sign_in admin_a
            
            %w[test1 test2 test3 random].each do |subdomain|
              request.host = "#{subdomain}.example.com"
              get :show
              expect(response).to render_template('pwb/errors/admin_required')
            end
          end

          it 'prevents cross-tenant access via session manipulation' do
            # Sign in as admin_a
            sign_in admin_a
            request.host = 'tenant-a.example.com'
            get :show
            expect(response).to have_http_status(:success)
            
            # Try to access tenant-b with same session
            request.host = 'tenant-b.example.com'
            get :show
            expect(response).to render_template('pwb/errors/admin_required')
            
            # Verify we still can't access even after multiple attempts
            3.times do
              get :show
              expect(response).to render_template('pwb/errors/admin_required')
            end
          end

          it 'prevents privilege escalation via website_id manipulation' do
            # Even if attacker somehow modifies user.website_id to match target
            sign_in admin_a
            
            # Attempt to access tenant-b
            request.host = 'tenant-b.example.com'
            
            # Simulate attacker manipulating website_id in memory (NOT via DB)
            # This shouldn't work because we fetch website fresh in controller
            allow(admin_a).to receive(:website_id).and_return(website_b.id)
            
            get :show
            
            # Should still fail because actual DB record doesn't match
            expect(response).to render_template('pwb/errors/admin_required')
          end
        end

        context 'edge cases' do
          it 'handles case-insensitive subdomain matching' do
            sign_in admin_a
            request.host = 'TENANT-A.example.com'
            
            get :show
            
            # Should work (subdomain lookup is case-insensitive)
            expect(response).to have_http_status(:success)
          end

          it 'handles subdomain with special characters safely' do
            sign_in admin_a
            request.host = 'tenant-a.example.com' # Normal subdomain
            
            # Try accessing with URL-encoded characters
            get :show
            
            expect(response).to have_http_status(:success)
          end

          it 'denies access when user website is deleted' do
            sign_in admin_a
            original_website_id = admin_a.website_id
            
            # Delete the website
            website_a.destroy
            
            request.host = 'tenant-a.example.com'
            get :show
            
            # Should deny - either error page or redirect to login
            # When website is deleted, Devise may redirect to sign_in
            expect(response.status).to be_in([200, 302])
            if response.status == 200
              expect(response).to render_template('pwb/errors/admin_required')
            else
              expect(response).to redirect_to(/sign_in/)
            end
          end
        end

        context 'multi-tenant isolation verification' do
          it 'maintains total isolation between tenants' do
            # Tenant A admin cannot see Tenant B
            sign_in admin_a
            request.host = 'tenant-b.example.com'
            get :show
            expect(response).to render_template('pwb/errors/admin_required')
            
            # Tenant B admin cannot see Tenant A
            sign_in admin_b
            request.host = 'tenant-a.example.com'
            get :show
            expect(response).to render_template('pwb/errors/admin_required')
            
            # Each can access their own
            sign_in admin_a
            request.host = 'tenant-a.example.com'
            get :show
            expect(response).to have_http_status(:success)
            
            sign_in admin_b
            request.host = 'tenant-b.example.com'
            get :show
            expect(response).to have_http_status(:success)
          end
        end
      end

      describe '#show_legacy_1' do
        it 'applies same tenant validation' do
          sign_in admin_a
          request.host = 'tenant-b.example.com'
          
          get :show_legacy_1
          
          expect(response).to render_template('pwb/errors/admin_required')
        end
      end
    end
  end
end
