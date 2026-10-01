require "selenium-webdriver"

module DashboardDemo
  # Screenshots the full rendered dashboard (sidebar included) for the landing
  # page hero, in light and dark mode at desktop and small sizes.
  #
  # The page is shown in headless Chrome from a temporary file, with the
  # compiled CSS inlined, scripts removed, and times localized, so it doesn't
  # need a running server.
  class Screenshots
    IMAGES_PATH = Rails.root.join("app/assets/images")
    # name => [CSS viewport width, height, device pixel ratio]
    SIZES = {
      "dashboard" => [ 1594, 1039, 3 ],
      "dashboard-small" => [ 1158, 773, 2 ]
    }.freeze

    SCHEMES = { "light" => "", "dark" => "-dark" }.freeze

    def initialize(html, css:, output_dir: IMAGES_PATH, time_zone: Time.zone)
      @html = html
      @css = css
      @output_dir = Pathname(output_dir)
      @time_zone = time_zone
    end

    # Returns the paths written: .webp when cwebp is available, otherwise .png.
    def call
      Dir.mktmpdir("dashboard-demo") do |dir|
        page_path = File.join(dir, "dashboard.html")
        File.write(page_path, static_page)

        with_browser do |driver|
          driver.navigate.to "file://#{page_path}"

          SIZES.flat_map do |name, (width, height, scale)|
            SCHEMES.map do |scheme, suffix|
              png_path = File.join(dir, "#{name}#{suffix}.png")
              capture(driver, png_path, width:, height:, scale:, scheme:)
              save(png_path, "#{name}#{suffix}")
            end
          end
        end
      end
    end

    private

    def static_page
      document = Nokogiri::HTML5(@html)

      document.css("script, link[rel='stylesheet'], link[rel='manifest'], link[rel~='icon']").each(&:remove)
      document.at_css("head").add_child("<style>#{css_with_local_assets}</style>")
      LocalTimes.apply(document, time_zone: @time_zone)

      document.to_html
    end

    # Root-relative URLs (like the /fonts/ web fonts) don't resolve from a file,
    # so embed files from public/ as data URIs.
    def css_with_local_assets
      @css.gsub(%r{url\((["']?)(/[^/)"'][^)"']*)\1\)}) do
        path = Rails.public_path.join(Regexp.last_match(2).delete_prefix("/"))
        next Regexp.last_match(0) unless path.file?

        "url(data:#{Marcel::MimeType.for(path)};base64,#{Base64.strict_encode64(path.binread)})"
      end
    end

    def capture(driver, path, width:, height:, scale:, scheme:)
      driver.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: scale, mobile: false)
      driver.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: scheme } ])
      driver.execute_script("window.scrollTo(0, 0)")
      driver.execute_async_script("document.fonts.ready.then(arguments[0])")
      sleep 0.3

      result = driver.execute_cdp("Page.captureScreenshot", format: "png")
      File.binwrite(path, Base64.decode64(result.fetch("data")))
    end

    def save(png_path, name)
      if system("which cwebp > /dev/null 2>&1")
        output = @output_dir.join("#{name}.webp")
        system("cwebp", "-quiet", "-q", "90", png_path, "-o", output.to_s, exception: true)
      else
        output = @output_dir.join("#{name}.png")
        FileUtils.cp(png_path, output)
      end

      output
    end

    def with_browser
      options = Selenium::WebDriver::Chrome::Options.new
      %w[--headless=new --hide-scrollbars --disable-gpu --allow-file-access-from-files].each { options.add_argument(it) }

      driver = Selenium::WebDriver.for(:chrome, options:)
      yield driver
    ensure
      driver&.quit
    end
  end
end
