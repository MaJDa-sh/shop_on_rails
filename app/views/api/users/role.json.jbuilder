if @user&.persisted?
  json.extract! @user, :id, :mail, :role
else
  json.errors @errors
end
json.status @status
