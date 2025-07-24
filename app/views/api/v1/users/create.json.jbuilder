# frozen_string_literal: true

json.message 'User created successfully.'
json.user do
  json.partial! 'api/v1/users/user_data', user: @user
end
