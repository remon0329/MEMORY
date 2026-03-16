class PostsController < ApplicationController
  before_action :authenticate_user!, only: [ :create, :edit, :update, :destroy, :new, :show ]
  before_action :set_post, only: [ :edit, :update, :destroy ]
  helper_method :prepare_meta_tags
  before_action :require_admin_or_owner, only: [ :edit, :update, :destroy ]

  def index
    @q = Post.ransack(params[:q])
    if params[:tag_list].present?
      @posts = Post.joins(:tags).where(tags: { name: params[:tag_list] }).distinct
    else
      if params[:q].present?
        @posts = @q.result(distinct: true)
      else
        @posts = Post.all
      end
    end
  end

  def sureddo
    @posts = Post.all
    @sureddos = Sureddo.all
  end

  def top
    @q = Post.ransack(params[:q])
    if params[:tag_list].present?
      @posts = Post.joins(:tags).where(tags: { name: params[:tag_list] }).distinct
    else
      if params[:q].present?
        @posts = @q.result(distinct: true)
      else
        @posts = Post.all
      end
    end
  end

  def search
    @q = Post.ransack(title_cont: params[:q])
    @posts = @q.result(distinct: true)

    respond_to do |format|
      format.json { render json: @posts.limit(10).pluck(:title) } # 件数制限も重要
      format.html { render :search }
    end
  end

  def new
    @post = Post.new
  end

  def sureddo_new
    @sureddo = Sureddo.new
  end

  def detail
    @post = Post.find(params[:id])
    @comments = @post.comments
    prepare_meta_tags(@post)
  end

  def show
    @user = current_user

    @posts = @user.posts
    @sureddos = @user.sureddos
  end

  def like_show
    @posts = current_user.likes.where.not(post_id: nil).map(&:post)
    @sureddos = current_user.likes.where.not(sureddo_id: nil).map(&:sureddo)
  end

  def create
    @post = current_user.posts.build(post_params)
    @post.user_name = current_user.name # user_idはbuildで自動セットされるのでnameだけでOK

    # タグの処理
    if params[:post][:predefined_tags].present?
      predefined_tags = params[:post][:predefined_tags].to_s.split(",")
      user_tags = params[:post][:tag_list].to_s.split(",")
      @post.tag_list = (predefined_tags + user_tags).uniq
    else
      @post.tag_list = params[:post][:tag_list].to_s.split(",")
    end

    # ★重要：両方入力されていた場合のガード
    if params[:post][:video_url].present? && params[:post][:video_file].present?
      @post.errors.add(:base, "YouTubeの動画URLと動画ファイルは同時に指定できません")
      render :new and return
    end

    # ★片方だけを確実に保存するための処理（念のため）
    if params[:post][:video_url].present?
      @post.video_file.purge # もしファイルがあっても消す
    elsif params[:post][:video_file].present?
      @post.video_url = nil   # URLが入っていても空にする
    end

    if @post.save
      redirect_to root_path, notice: "投稿が完了しました"
    else
      # バリデーションエラー時は入力内容を保持してnewへ
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # 1. まずタグなどの特殊な処理を済ませる
    if params[:post][:predefined_tags].present?
      all_tags = (params[:post][:predefined_tags].split(",") + params[:post][:tag_list].to_s.split(",")).uniq
      @post.tag_list = all_tags
    else
      @post.tag_list = params[:post][:tag_list].to_s.split(",")
    end

    # 2. 動画URLとファイルの排他チェック（コントローラでやるなら）
    if params[:post][:video_url].present? && params[:post][:video_file].present?
      @post.errors.add(:base, "YouTubeの動画URLと動画ファイルは同時に更新できません")
      render :edit and return
    end

    # 3. どちらか一方があったら片方を消す処理
    if params[:post][:video_url].present?
      @post.video_file.purge if @post.video_file.attached?
    elsif params[:post][:video_file].present?
      @post.video_url = nil
    end

    # 4. 保存（attributesを渡して一気に更新）
    if @post.update(post_params)
      redirect_to post_path(@post), notice: "投稿が更新されました" # @postに変更
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post = Post.find(params[:id])
    @post.comments.destroy_all
    @post.destroy
    redirect_to post_path(current_user), notice: "投稿が削除されました"
  end

  private

  def post_params
    params.require(:post).permit(:title, :description, :video_url, :video_file, :tag_list, :predefined_tags)
  end

  def set_post
    @post = Post.find(params[:id])
  end

  def require_admin_or_owner
    unless current_user&.admin? || current_user == @post.user
      flash[:alert] = "この投稿を編集・削除する権限がありません"
      redirect_to root_path
    end
  end

  def search_posts(query)
    conditions = [
        "title ILIKE ?",
        "title ILIKE ?",
        "title ILIKE ?",
        "title ILIKE ?" ]

    search_queries = [
        "%#{query}%",
        "%#{query.tr('ぁ-ん', 'ァ-ン')}%",
        "%#{query.tr('ァ-ン', 'ぁ-ん')}%",
        "%#{query.tr('a-zA-Z', '')}%" ]

    if query.match?(/[a-zA-Z]/)
        posts = posts.where("title ILIKE ?", "%#{query}%")
    end
    posts
  end

  def prepare_meta_tags(post)
    image_url = "#{request.base_url}/images/ogp.png?text=#{CGI.escape(post.title)}"
    set_meta_tags og: {
                    site_name: "GAMES_MEMORY",
                    title: post.title,
                    description: post.description,
                    type: "website",
                    url: request.original_url,
                    image: image_url,
                    locale: "ja-JP"
                  },
                  twitter: {
                    card: "summary_large_image",
                    image: image_url
                  }
  end
end
