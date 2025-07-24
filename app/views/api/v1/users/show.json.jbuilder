# frozen_string_literal: true

json.cache! ['user_show', @user.id, @user.updated_at] do
  json.user do
    json.partial! 'api/v1/users/user_data', user: @user

    if @user.user_detail.present?
      json.user_detail do
        json.partial! 'api/v1/user_details/user_detail', user_detail: @user.user_detail
      end
    end

    if @user.user_detail&.location.present?
      json.location do
        json.partial! 'api/v1/locations/location', location: @user.user_detail.location
      end
    end

    if @user.entrepreneur_detail.present?
      json.entrepreneur_detail do
        json.partial! 'api/v1/entrepreneur_details/entrepreneur_detail', entrepreneur_detail: @user.entrepreneur_detail
      end
    end
  end
end
