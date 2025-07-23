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
      json.entrepreneur_detail do
        entrepreneur = @user.user_detail.entrepreneur_detail
        json.id entrepreneur.id
        json.business_name entrepreneur.business_name
        json.nip entrepreneur.nip
        json.krs entrepreneur.krs
        json.description entrepreneur.description
        json.offer entrepreneur.offer
        json.income entrepreneur.income
        json.costs entrepreneur.costs
        json.funding_capital entrepreneur.funding_capital
        json.industry entrepreneur.industry
        json.management_council_members entrepreneur.management_council_members
        json.decision_makers entrepreneur.decision_makers
        json.business_phone_number entrepreneur.business_phone_number
        json.business_mail entrepreneur.business_mail
        json.website_address entrepreneur.website_address
        json.created_at entrepreneur.created_at
        json.updated_at entrepreneur.updated_at
      end
    end
  end
end
