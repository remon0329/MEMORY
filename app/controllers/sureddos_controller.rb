class SureddosController < ApplicationController
  before_action :authenticate_user!, only: [ :create, :edit, :update, :destroy, :new ]
  before_action :set_sureddo, only: [ :show, :edit, :update, :destroy ]
  helper_method :prepare_meta_tags
  before_action :require_admin_or_owner, only: [ :edit, :update, :destroy ]

  def index
    @q = Sureddo.ransack(params[:q])
    if params[:tag_list].present?
      @sureddos = Sureddo.joins(:tags).where(tags: { name: params[:tag_list].split(",") }).distinct
    elsif params[:tag_id].present?
      tag = Tag.find(params[:tag_id])
      @sureddos = tag.sureddos.distinct
    else
      if params[:q].present?
        @sureddos = @q.result(distinct: true)
      else
        @sureddos = Sureddo.all
      end
    end
  end

  def search
    @q = Sureddo.ransack(title_cont: params[:q])

    if params[:tag_id].present?
      tag = Tag.find(params[:tag_id])
      @sureddos = tag.sureddos.distinct
    else
      @sureddos = @q.result(distinct: true)
    end

    respond_to do |format|
      format.js
      format.json { render json: @sureddos.limit(10).pluck(:title) } # ← 件数制限追加
      format.html { render :search }
    end
  end

  def new
    @sureddo = Sureddo.new
  end

  def show
    @sureddo = Sureddo.find(params[:id])
    @comments = @sureddo.comments
    prepare_meta_tags(@sureddo)
  end

  def create
    @sureddo = current_user.sureddos.build(sureddo_params)
    @sureddo.user_id = current_user.id
    @sureddo.user_name = current_user.name
    if params[:sureddo][:predefined_tags].present?
      predefined_tag = params[:sureddo][:predefined_tags]
      @sureddo.tag_list = [ predefined_tag, params[:sureddo][:tag_list] ].join(",")
    else
      @sureddo.tag_list = params[:sureddo][:tag_list]
    end
    if @sureddo.save
      redirect_to sureddos_path, notice: "投稿が作成されました"
    else
      render :new
    end
  end

  def edit
  end

  def update
    sureddo_attributes = sureddo_params
    if params[:sureddo][:predefined_tags].present?
      predefined_tag = params[:sureddo][:predefined_tags]
      @sureddo.tag_list = [ predefined_tag, params[:sureddo][:tag_list] ].join(",")
    else
      @sureddo.tag_list = params[:sureddo][:tag_list]
    end

    if @sureddo.update(sureddo_attributes)
      redirect_to post_path(current_user), notice: "投稿が更新されました"
    else
      render :edit
    end
  end

  def destroy
    @sureddo = Sureddo.find(params[:id])
    @sureddo.comments.destroy_all
    @sureddo.destroy
    redirect_to post_path(current_user), notice: "投稿が削除されました"
  end

  private

  def set_sureddo
    @sureddo = Sureddo.find(params[:id])
  end

  def require_admin_or_owner
    unless current_user&.admin? || current_user == @sureddo.user
      flash[:alert] = "この投稿を編集・削除する権限がありません"
      redirect_to sureddos_path
    end
  end

  def sureddo_params
    params.require(:sureddo).permit(:title, :description, :image, :tag_list)
  end

  def search_sureddos(query)
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
      sureddos = sureddos.where("title ILIKE ?", "%#{query}%")
    end
    sureddos
  end

  def prepare_meta_tags(sureddo)
    image_url = "#{request.base_url}/images/ogp.png?text=#{CGI.escape(sureddo.title)}"
    set_meta_tags og: {
                    site_name: "GAMES_MEMORY",
                    title: sureddo.title,
                    description: sureddo.description,
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
