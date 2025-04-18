class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post, optional: true
  belongs_to :sureddo, optional: true
  has_many :notifications, dependent: :destroy
end
