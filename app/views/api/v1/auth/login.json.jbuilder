# frozen_string_literal: true

json.message @message
json.token @token if @token.present?
json.user do
  json.id @user.id
  json.mail @user.mail
  json.two_factor_enabled @user.two_factor_enabled? if @user.respond_to?(:two_factor_enabled?)
end
