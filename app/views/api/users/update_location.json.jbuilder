# frozen_string_literal: true

if @errors
  json.errors @errors
  json.status @status
else
  json.status @status
  json.user do
    json.id @user.id
    json.mail @user.mail
    json.phone @user.phone
    json.role @user.role
    json.active @user.active
    json.verified @user.verified
    json.user_detail do
      json.id @user.user_detail.id
      json.name @user.user_detail.name
      json.first_name @user.user_detail.first_name
      json.last_name @user.user_detail.last_name
      json.location do
        location = @user.user_detail.locations.first
        json.id location.id
        json.country location.country
        json.province location.province
        json.city location.city
        json.postal_code location.postal_code
        json.street location.street
        json.building_number location.building_number
        json.apartment_number location.apartment_number
        json.created_at location.created_at
        json.updated_at location.updated_at
      end
    end
  end
end
