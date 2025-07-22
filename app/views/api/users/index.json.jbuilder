if @users
  json.array! @users do |user|
    json.extract! user, :id, :mail, :role
  end
else
  json.errors @errors
end
json.status @status
