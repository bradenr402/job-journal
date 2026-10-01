module PagesHelper
  SUGGESTION_TILE_CLASSES = "bg-neutral-100 dark:bg-neutral-800/60 p-3 rounded-md transition-all duration-80 " \
                            "hover:bg-neutral-200/70 dark:hover:bg-neutral-700/30 active:scale-98"

  def suggestion_grid_class_names(count)
    if minimal_style?
      collection_layout_class_names(layout: count > 1 ? "grid" : "list", count:, size: :small)
    else
      class_names("grid grid-cols-1 gap-1.5", "@xl:grid-cols-2" => count > 1)
    end
  end

  def suggestion_item_class_names
    class_names("relative flex flex-col gap-5", minimal_style? ? item_layout_class_names : SUGGESTION_TILE_CLASSES)
  end
end
