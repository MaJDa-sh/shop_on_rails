# frozen_string_literal: true

if @errors
  json.errors @errors
else
  json.message @message
end
