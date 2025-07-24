# frozen_string_literal: true

json.message 'User entrepreneur details updated successfully.'
if @user.entrepreneur_detail.present?
  json.entrepreneur_detail do
    json.partial! 'api/v1/entrepreneur_details/entrepreneur_detail', entrepreneur_detail: @user.entrepreneur_detail
  end
end
