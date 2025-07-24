# frozen_string_literal: true

json.message "User role updated to #{@user.role} successfully."
json.user do
  json.partial! 'api/v1/users/user_data', user: @user
end
