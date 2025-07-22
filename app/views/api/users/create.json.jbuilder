if @user&.persisted?
  json.extract! @user, :id, :mail, :phone, :role, :created_at, :updated_at
  json.user_detail @user.user_detail, :first_name, :last_name if @user.user_detail
else
  json.errors @errors
end
json.status @status
