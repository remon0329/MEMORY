class Sureddo < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_one_attached :image
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  has_many :notifications, dependent: :destroy
  def self.ransackable_attributes(auth_object = nil)
    [ "body", "created_at", "description", "id", "id_value", "thumbnail", "title", "updated_at", "user_id", "user_name", "image" ]
  end

  def tag_list=(tags)
    self.tags = tags.split(",").map { |tag| Tag.find_or_create_by(name: tag.strip) }
  end

  def liked_by?(user)
    return false if user.nil?
    likes.exists?(user_id: user.id)
  end

  def create_notification_like!(current_user)
    # すでに「いいね」されているか検索
    temp = Notification.where([ "visitor_id = ? and visited_id = ? and sureddo_id = ? and action = ? ",
                                current_user.id, user_id, id, "like" ])
    # いいねされていない場合のみ、通知レコードを作成
    return if temp.present?

    notification = current_user.active_notifications.new(
      sureddo_id: id,
      visited_id: user_id,
      action: "sureddo_like"
    )
    # 自分の投稿に対するいいねの場合は、通知済みとする
    notification.checked = true if notification.visitor_id == notification.visited_id
    notification.save if notification.valid?
  end

  def create_notification_comment!(current_user, comment_id)
    # 自分以外にコメントしている人をすべて取得し、全員に通知を送る
    temp_ids = Comment.select(:user_id).where(sureddo_id: id).where.not(user_id: current_user.id).distinct
    temp_ids.each do |temp_id|
      save_notification_comment!(current_user, comment_id, temp_id["user_id"])
    end
    # まだ誰もコメントしていない場合は、投稿者に通知を送る
    save_notification_comment!(current_user, comment_id, user_id) if temp_ids.blank?
  end

  def save_notification_comment!(current_user, comment_id, visited_id)
    # コメントは複数回することが考えられるため、１つの投稿に複数回通知する
    notification = current_user.active_notifications.new(
      sureddo_id: id,
      comment_id:,
      visited_id:,
      action: "sureddo_comment"
    )
    # 自分の投稿に対するコメントの場合は、通知済みとする
    notification.checked = true if notification.visitor_id == notification.visited_id
    notification.save if notification.valid?
  end
end
