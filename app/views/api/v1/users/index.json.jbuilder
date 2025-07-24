# frozen_string_literal: true

json.cache! ['users_index', @users.map(&:id).sort, @users.maximum(:updated_at) || Time.current, params[:page]] do
  json.users @users do |user|
    json.partial! 'api/v1/users/user_data', user: user
  end

  json.meta do
    json.current_page @users.current_page
    json.next_page @users.next_page
    json.prev_page @users.prev_page
    json.total_pages @users.total_pages
    json.total_count @users.total_count
  end
end
