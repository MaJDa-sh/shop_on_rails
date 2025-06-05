class Product < ApplicationRecord
  has_many_attached :photos, dependent: :purge_later
end
