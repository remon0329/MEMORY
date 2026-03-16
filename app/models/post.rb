class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_one_attached :video_file
  validate :video_url_or_video_file
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  has_many :notifications, dependent: :destroy
  def self.ransackable_attributes(auth_object = nil)
    [ "body", "created_at", "description", "id", "id_value", "thumbnail", "title", "updated_at", "user_id", "user_name", "video_file", "video_url" ]
  end


  def tag_list=(tags)
    if tags.is_a?(Array)
      self.tags = tags.map { |tag| Tag.find_or_create_by(name: tag.strip) }
    else
      self.tags = tags.split(",").map { |tag| Tag.find_or_create_by(name: tag.strip) }
    end
  end

  def liked_by?(user)
    return false if user.nil?
    likes.exists?(user_id: user.id)
  end

  def create_notification_like!(current_user)
    temp = Notification.where(
      visitor_id: current_user.id,
      visited_id: user_id,
      post_id: id,
      action: "like"
    )

    return if temp.exists?

    notification = current_user.active_notifications.new(
      post_id: id,
      visited_id: user_id,
      action: "like"
    )
    notification.checked = true if notification.visitor_id == notification.visited_id
    notification.save if notification.valid?
  end

  def create_notification_comment!(current_user, comment_id)
    temp_ids = Comment.select(:user_id).where(post_id: id).where.not(user_id: current_user.id).distinct

    temp_ids.each do |temp_id|
      save_notification_comment!(current_user, comment_id, temp_id["user_id"])
    end

    save_notification_comment!(current_user, comment_id, user_id) if temp_ids.blank?
  end

  def save_notification_comment!(current_user, comment_id, visited_id)
    notification = current_user.active_notifications.new(
      post_id: id,
      comment_id: comment_id,
      visited_id: visited_id,
      action: "comment"
    )

    notification.checked = true if notification.visitor_id == notification.visited_id
    notification.save if notification.valid?
  end

  private

  def video_url_or_video_file
    # 1. 両方空の場合
    if video_url.blank? && !video_file.attached?
      errors.add(:base, "YouTubeの動画URLまたは動画ファイルのどちらかを入力してください")
    end

    # 2. 両方入力されている場合（Active Storageは attached? で判定）
    if video_url.present? && video_file.attached?
      errors.add(:base, "YouTubeの動画URLと動画ファイルは同時に指定できません")
    end
  end
end
