# frozen_string_literal: true

if @message
  json.message @message
else
  json.errors @errors
end
json.status @status
