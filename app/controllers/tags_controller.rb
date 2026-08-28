class TagsController < ApplicationController
  before_action :set_tag, only: [ :edit, :update, :destroy ]
  before_action :set_merge_context, only: [ :edit, :update ]

  def index
    @tags = Current.user.tags
      .joins(:taggings)
      .group(:id)
      .select("tags.*, COUNT(taggings.id) as taggings_count")
      .order("taggings_count DESC", :name)
  end

  def edit
  end

  def update
    surviving_tag = @tag.rename_to(tag_params[:name])

    if surviving_tag
      redirect_to tags_path, success: rename_message(surviving_tag)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @tag.destroy
      redirect_to tags_path, success: "Tag was successfully deleted."
    else
      redirect_to tags_path, error: "Failed to delete the tag."
    end
  end

  private

  def set_tag
    @tag = Current.user.tags.find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    raise # Let config.exceptions_app handle the error
  end

  # Captured before the tag is renamed so the edit form and the flash message
  # can still refer to the tag's saved name.
  def set_merge_context
    @current_tag_name = @tag.name
    @mergeable_tag_names = Current.user.tags.where.not(id: @tag.id).pluck(:name)
  end

  # Flash messages are rendered as html_safe, so user-supplied tag names must be escaped.
  def rename_message(surviving_tag)
    return "Tag was successfully updated." if surviving_tag == @tag

    "Tag '#{ERB::Util.html_escape(@current_tag_name)}' was merged into " \
      "'#{ERB::Util.html_escape(surviving_tag.name)}'."
  end

  def tag_params
    params.expect(tag: [ :name ])
  end
end
