# frozen_string_literal: true

json.message '2FA code verified successfully.'
json.token @token
json.user do
  json.id @user.id
  json.mail @user.mail
end
