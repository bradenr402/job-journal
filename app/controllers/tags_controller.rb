class TagsController < ApplicationController
  before_action :set_tag, only: [ :edit, :update, :destroy ]

  def index
    @tags = Current.user.tags.left_outer_joins(:taggings)
      .group('tags.id')
      .select('tags.*, COUNT(taggings.id) as taggings_count')
      .order('taggings_count DESC, tags.name ASC')
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, notice: 'Tag was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy
    redirect_to tags_path, notice: 'Tag was successfully deleted.'
  end

  private

  def set_tag
    @tag = Current.user.tags.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    raise # Let config.exceptions_app handle the error
  end

  def tag_params
    params.expect(tag: [ :name ])
  end
end
