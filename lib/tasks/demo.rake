namespace :demo do
  desc "Regenerate the landing page dashboard demo and screenshots from lib/dashboard_demo/data.yml (SCREENSHOTS=0 to skip screenshots)"
  task dashboard: [ :environment, "tailwindcss:build" ] do
    screenshots = ActiveModel::Type::Boolean.new.cast(ENV.fetch("SCREENSHOTS", "1"))

    DashboardDemo.generate(screenshots:).each do |path|
      puts "Wrote #{path.relative_path_from(Rails.root)}"
    end

    if screenshots && Dir[Rails.root.join("app/assets/images/dashboard*.png")].any?
      puts "cwebp wasn't found, so screenshots were saved as .png. Convert them to .webp (brew install webp)."
    end
  end
end
