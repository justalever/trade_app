class Trade < ApplicationRecord
  belongs_to :user
  has_many_attached :images, dependent: :destroy
end
