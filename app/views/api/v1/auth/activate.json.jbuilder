# frozen_string_literal: true

json.message @message
json.user do
  json.id @user.id
  json.mail @user.mail
  json.active @user.active?
end
