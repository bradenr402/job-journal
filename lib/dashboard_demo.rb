module DashboardDemo
  DATA_PATH = Rails.root.join("lib/dashboard_demo/data.yml")
  OUTPUT_PATH = Rails.root.join("app/assets/demo/JobJournal-demo.html")
  CSS_PATH = Rails.root.join("app/assets/builds/tailwind.css")

  # Renders the dashboard once, screenshots the full page (sidebar included),
  # then normalizes it into the static demo. Returns the paths written.
  def self.generate(data_path: DATA_PATH, output_path: OUTPUT_PATH, css_path: CSS_PATH, screenshots: true)
    data = YAML.safe_load_file(data_path)
    css = File.read(css_path)
    html = Capture.new(data).call

    images = screenshots ? Screenshots.new(html, css:).call : []
    File.write(output_path, Normalizer.new(html, css:).call)

    [ output_path, *images ]
  end
end
