ICONS_GLOB = Rails.root.join("app/assets/images/icons/*.svg")

JOB_JOURNAL_ICONS =
  Dir.glob(ICONS_GLOB).to_h do |path|
    [ File.basename(path, ".svg"), File.read(path) ]
  end
