# frozen_string_literal: true

require 'twilio-ruby'

account_sid = Rails.application.credentials.twilio[:account_sid]
auth_token = Rails.application.credentials.twilio[:auth_token]

if account_sid && auth_token
  TWILIO_CLIENT = Twilio::REST::Client.new(account_sid, auth_token)
  Rails.logger.info 'Twilio client initialized successfully.'
else
  Rails.logger.warn 'Twilio credentials not found. SMSService will not be available.'
end
