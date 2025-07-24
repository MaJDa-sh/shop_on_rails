# frozen_string_literal: true

if @errors
  json.errors @errors
  json.status @status
  json.details @details
else
  json.message @message
  json.status @status
  json.details @details
end
