# frozen_string_literal: true

require 'twilio-ruby'

module Services
  class SMSService
    def self.client
      account_sid = Rails.application.credentials.twilio[:account_sid]
      auth_token = Rails.application.credentials.twilio[:auth_token]
      @client ||= Twilio::REST::Client.new(account_sid, auth_token)
    end

    def self.twilio_phone_number
      Rails.application.credentials.twilio[:phone_number]
    end

    def self.dial(to:, body:)
      return unless to.present? && body.present?

      begin
        message = client.messages.create(
          from: twilio_phone_number,
          to: to,
          body: body
        )
        Rails.logger.info "SMS sent successfully to #{to}. SID: #{message.sid}"
        true
      rescue Twilio::REST::TwilioError => e
        Rails.logger.error "Twilio Error: Failed to send SMS to #{to}. Reason: #{e.message}"
        false
      end
    end

    def self.dial_2fa_code(user, code)
      return unless user.phone.present?

      message_body = "Your two-factor authentication code is: #{code}"
      dial(to: user.phone, body: message_body)
    end
  end
end
