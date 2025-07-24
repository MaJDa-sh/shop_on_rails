# frozen_string_literal: true

json.message 'User location updated successfully.'
if @user.user_detail&.location.present?
  json.location do
    json.partial! 'api/v1/locations/location', location: @user.user_detail.location
  end
end
