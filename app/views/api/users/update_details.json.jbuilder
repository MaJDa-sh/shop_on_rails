# frozen_string_literal: true

if @errors
  json.errors @errors
  json.status @status
else
  json.status @status
  json.user do
    json.id @user.id
    json.mail @user.mail
    json.phone @user.phone
    json.role @user.role
    json.active @user.active
    json.verified @user.verified
    json.user_detail do
      json.id @user.user_detail.id
      json.name @user.user_detail.name
      json.first_name @user.user_detail.first_name
      json.last_name @user.user_detail.last_name
      json.created_at @user.user_detail.created_at
      json.updated_at @user.user_detail.updated_at
    end
  end
end
