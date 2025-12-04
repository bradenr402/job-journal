class TagsController < ApplicationController
  before_action :set_tag, only: [ :edit, :update, :destroy ]

  def index
    @tags = Current.user.tags
      .joins(:taggings)
      .group(:id)
      .select('tags.*, COUNT(taggings.id) as taggings_count')
      .order('taggings_count DESC', :name)
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, success: 'Tag was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @tag.destroy
      redirect_to tags_path, success: 'Tag was successfully deleted.'
    else
      redirect_to tags_path, error: 'Failed to delete tag.'
    end
  end

  private

  def set_tag
    @tag = Current.user.tags.find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    raise # Let config.exceptions_app handle the error
  end

  def tag_params
    params.expect(tag: [ :name ])
  end
end
