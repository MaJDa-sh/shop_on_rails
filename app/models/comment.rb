# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :product
  belongs_to :user

  belongs_to :parent, class_name: 'Comment', optional: true, counter_cache: :replies_count

  has_many :replies, class_name: 'Comment', foreign_key: :parent_id, dependent: :destroy

  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }
  validates :user, presence: true
  validates :product, presence: true

  scope :top_level, -> { where(parent_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def is_reply?
    parent_id.present?
  end
end
