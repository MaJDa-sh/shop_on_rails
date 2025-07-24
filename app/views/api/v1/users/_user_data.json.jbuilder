# frozen_string_literal: true

json.id user.id
json.mail user.mail
json.phone user.phone if user.phone.present?
json.role user.role
json.active user.active?
json.verified user.verified?
json.created_at user.created_at
json.updated_at user.updated_at
