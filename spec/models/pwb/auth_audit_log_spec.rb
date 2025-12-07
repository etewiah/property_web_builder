# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::AuthAuditLog, type: :model do
  let!(:website) { create(:pwb_website) }
  let!(:user) { create(:pwb_user, website: website) }

  describe 'validations' do
    it 'requires event_type' do
      log = Pwb::AuthAuditLog.new(event_type: nil)
      expect(log).not_to be_valid
      expect(log.errors[:event_type]).to include("can't be blank")
    end

    it 'validates event_type inclusion' do
      log = Pwb::AuthAuditLog.new(event_type: 'invalid_event')
      expect(log).not_to be_valid
      expect(log.errors[:event_type]).to include("is not included in the list")
    end

    it 'accepts valid event types' do
      Pwb::AuthAuditLog::EVENT_TYPES.each do |event_type|
        log = Pwb::AuthAuditLog.new(event_type: event_type)
        log.valid?
        expect(log.errors[:event_type]).to be_empty
      end
    end
  end

  describe 'associations' do
    it 'belongs to user optionally' do
      log = Pwb::AuthAuditLog.create!(event_type: 'login_failure', email: 'unknown@example.com')
      expect(log.user).to be_nil
    end

    it 'belongs to website optionally' do
      log = Pwb::AuthAuditLog.create!(event_type: 'login_success', user: user)
      expect(log.website).to be_nil
    end
  end

  describe 'scopes' do
    before do
      # Create various log entries
      Pwb::AuthAuditLog.create!(event_type: 'login_success', user: user, email: user.email, created_at: 1.hour.ago)
      Pwb::AuthAuditLog.create!(event_type: 'login_failure', email: 'test@example.com', ip_address: '192.168.1.1', created_at: 30.minutes.ago)
      Pwb::AuthAuditLog.create!(event_type: 'login_failure', email: 'test@example.com', ip_address: '192.168.1.1', created_at: 10.minutes.ago)
      Pwb::AuthAuditLog.create!(event_type: 'logout', user: user, email: user.email, created_at: 5.minutes.ago)
    end

    it 'returns logs for a specific user' do
      logs = Pwb::AuthAuditLog.for_user(user)
      # 2 explicitly created + 1 registration log from user creation
      expect(logs.count).to eq(3)
    end

    it 'returns logs for a specific email' do
      logs = Pwb::AuthAuditLog.for_email('test@example.com')
      expect(logs.count).to eq(2)
    end

    it 'returns logs for a specific IP' do
      logs = Pwb::AuthAuditLog.for_ip('192.168.1.1')
      expect(logs.count).to eq(2)
    end

    it 'returns only failures' do
      logs = Pwb::AuthAuditLog.failures
      expect(logs.count).to eq(2)
      expect(logs.pluck(:event_type).uniq).to eq(['login_failure'])
    end

    it 'returns only successes' do
      logs = Pwb::AuthAuditLog.successes
      expect(logs.count).to eq(1)
      expect(logs.first.event_type).to eq('login_success')
    end

    it 'returns logs from the last hour' do
      logs = Pwb::AuthAuditLog.last_hour
      # 3 explicitly created in last hour + 1 registration log from user creation
      expect(logs.count).to eq(4)
    end

    it 'orders recent logs descending' do
      logs = Pwb::AuthAuditLog.recent
      expect(logs.first.created_at).to be > logs.last.created_at
    end
  end

  describe 'logging methods' do
    let(:mock_request) do
      double('request',
        remote_ip: '10.0.0.1',
        ip: '10.0.0.1',
        user_agent: 'Mozilla/5.0 Test Browser',
        fullpath: '/users/sign_in'
      )
    end

    describe '.log_login_success' do
      it 'creates a login_success log entry' do
        expect {
          Pwb::AuthAuditLog.log_login_success(user: user, request: mock_request)
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        log = Pwb::AuthAuditLog.last
        expect(log.event_type).to eq('login_success')
        expect(log.user).to eq(user)
        expect(log.email).to eq(user.email)
        expect(log.ip_address).to eq('10.0.0.1')
        expect(log.user_agent).to include('Mozilla')
      end
    end

    describe '.log_login_failure' do
      it 'creates a login_failure log entry' do
        expect {
          Pwb::AuthAuditLog.log_login_failure(
            email: 'attacker@example.com',
            reason: 'invalid_credentials',
            request: mock_request
          )
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        log = Pwb::AuthAuditLog.last
        expect(log.event_type).to eq('login_failure')
        expect(log.email).to eq('attacker@example.com')
        expect(log.failure_reason).to eq('invalid_credentials')
        expect(log.ip_address).to eq('10.0.0.1')
      end

      it 'links to user if email exists' do
        Pwb::AuthAuditLog.log_login_failure(
          email: user.email,
          reason: 'invalid_password',
          request: mock_request
        )

        log = Pwb::AuthAuditLog.last
        expect(log.user).to eq(user)
      end
    end

    describe '.log_logout' do
      it 'creates a logout log entry' do
        expect {
          Pwb::AuthAuditLog.log_logout(user: user, request: mock_request)
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        log = Pwb::AuthAuditLog.last
        expect(log.event_type).to eq('logout')
        expect(log.user).to eq(user)
      end
    end

    describe '.log_oauth_success' do
      it 'creates an oauth_success log entry' do
        expect {
          Pwb::AuthAuditLog.log_oauth_success(
            user: user,
            provider: 'facebook',
            request: mock_request
          )
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        log = Pwb::AuthAuditLog.last
        expect(log.event_type).to eq('oauth_success')
        expect(log.provider).to eq('facebook')
      end
    end

    describe '.log_password_reset_request' do
      it 'creates a password_reset_request log entry' do
        expect {
          Pwb::AuthAuditLog.log_password_reset_request(
            email: user.email,
            request: mock_request
          )
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        log = Pwb::AuthAuditLog.last
        expect(log.event_type).to eq('password_reset_request')
        expect(log.user).to eq(user)
      end
    end

    describe '.log_account_locked' do
      it 'creates an account_locked log entry' do
        user.update!(failed_attempts: 5)

        expect {
          Pwb::AuthAuditLog.log_account_locked(user: user)
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        log = Pwb::AuthAuditLog.last
        expect(log.event_type).to eq('account_locked')
        expect(log.failure_reason).to include('5 failed attempts')
      end
    end

    describe '.log_account_unlocked' do
      it 'creates an account_unlocked log entry' do
        expect {
          Pwb::AuthAuditLog.log_account_unlocked(user: user, unlock_method: 'email')
        }.to change(Pwb::AuthAuditLog, :count).by(1)

        log = Pwb::AuthAuditLog.last
        expect(log.event_type).to eq('account_unlocked')
        expect(log.metadata['unlock_method']).to eq('email')
      end
    end
  end

  describe 'query helpers' do
    describe '.failed_attempts_for_email' do
      before do
        3.times do
          Pwb::AuthAuditLog.create!(
            event_type: 'login_failure',
            email: 'target@example.com',
            created_at: 30.minutes.ago
          )
        end
        # Old failure - should not be counted
        Pwb::AuthAuditLog.create!(
          event_type: 'login_failure',
          email: 'target@example.com',
          created_at: 2.hours.ago
        )
      end

      it 'counts recent failed attempts for an email' do
        count = Pwb::AuthAuditLog.failed_attempts_for_email('target@example.com')
        expect(count).to eq(3)
      end
    end

    describe '.failed_attempts_for_ip' do
      before do
        5.times do
          Pwb::AuthAuditLog.create!(
            event_type: 'login_failure',
            ip_address: '192.168.1.100',
            created_at: 30.minutes.ago
          )
        end
      end

      it 'counts recent failed attempts for an IP' do
        count = Pwb::AuthAuditLog.failed_attempts_for_ip('192.168.1.100')
        expect(count).to eq(5)
      end
    end

    describe '.suspicious_ips' do
      before do
        # Suspicious IP - 15 failures
        15.times do
          Pwb::AuthAuditLog.create!(
            event_type: 'login_failure',
            ip_address: '10.0.0.99',
            created_at: 30.minutes.ago
          )
        end
        # Normal IP - 2 failures
        2.times do
          Pwb::AuthAuditLog.create!(
            event_type: 'login_failure',
            ip_address: '10.0.0.1',
            created_at: 30.minutes.ago
          )
        end
      end

      it 'returns IPs exceeding threshold' do
        suspicious = Pwb::AuthAuditLog.suspicious_ips(threshold: 10)
        expect(suspicious.keys).to include('10.0.0.99')
        expect(suspicious.keys).not_to include('10.0.0.1')
      end
    end
  end

  describe 'user model integration' do
    it 'logs registration when user is created' do
      expect {
        create(:pwb_user, website: website, email: 'newuser@example.com')
      }.to change(Pwb::AuthAuditLog, :count).by(1)

      log = Pwb::AuthAuditLog.last
      expect(log.event_type).to eq('registration')
      expect(log.email).to eq('newuser@example.com')
    end

    describe 'lockout logging' do
      it 'logs when account is locked' do
        expect {
          user.update!(locked_at: Time.current, failed_attempts: 5)
        }.to change { Pwb::AuthAuditLog.where(event_type: 'account_locked').count }.by(1)
      end

      it 'logs when account is unlocked' do
        user.update!(locked_at: Time.current, unlock_token: 'test_token')

        expect {
          user.update!(locked_at: nil, unlock_token: nil)
        }.to change { Pwb::AuthAuditLog.where(event_type: 'account_unlocked').count }.by(1)
      end
    end

    describe '#recent_auth_activity' do
      before do
        3.times { Pwb::AuthAuditLog.create!(event_type: 'login_success', user: user) }
      end

      it 'returns recent activity for user' do
        activity = user.recent_auth_activity(limit: 2)
        expect(activity.count).to eq(2)
      end
    end

    describe '#suspicious_activity?' do
      it 'returns false when below threshold' do
        2.times { Pwb::AuthAuditLog.create!(event_type: 'login_failure', user: user) }
        expect(user.suspicious_activity?).to be false
      end

      it 'returns true when at or above threshold' do
        5.times { Pwb::AuthAuditLog.create!(event_type: 'login_failure', user: user) }
        expect(user.suspicious_activity?).to be true
      end
    end
  end
end
