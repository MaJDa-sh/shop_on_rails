if @token
  json.token @token
  json.user do
    json.id @user.id
    json.mail @user.mail
    json.role @user.role
  end
elsif @message
  json.message @message
else
  json.errors @errors
end
json.status @status
