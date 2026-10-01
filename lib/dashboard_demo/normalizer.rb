module DashboardDemo
  # Turns a rendered dashboard page into the static, self-contained demo that
  # the landing page embeds in an iframe:
  #
  # - Keeps only the contents of <main>, inside a minimal page shell with the
  #   compiled Tailwind CSS inlined (no external stylesheets, scripts, favicons,
  #   manifest, or CSRF/CSP meta tags).
  # - Removes everything interactive or navigational: links covering whole cards
  #   are deleted (their cards keep the hover effect via `card-interactive`), other
  #   links and buttons become <span>s, and forms, scripts, inline event handlers,
  #   Stimulus/Turbo attributes, and record IDs are stripped.
  # - Localizes <time data-local> elements to the demo's time zone the same way
  #   the local_time JavaScript would, since the demo runs no JavaScript.
  # - Drops HTML comments, including development template annotations.
  class Normalizer
    EXTRA_CSS = <<~CSS.freeze
      .card-interactive:hover, [class*="hover:"]:hover {
        cursor: pointer;
      }
    CSS

    REMOVED_ELEMENTS = %w[script noscript template iframe link form input select textarea dialog].freeze
    COVERING_LINKS = "a.blanket-link, a.absolute.inset-0".freeze
    REMOVED_ATTRIBUTES = %w[href src srcset action formaction method target rel download tabindex].freeze
    REMOVED_ATTRIBUTE_PATTERN = /\A(?:on|data-(?:controller|action|turbo|.*-target\z|.*-class\z|.*-value\z))/

    def initialize(html, css:, time_zone: Time.zone)
      @html = html
      @css = css
      @time_zone = time_zone
    end

    def call
      document = Nokogiri::HTML5(@html)
      main = document.at_css("main") or raise "Rendered page has no <main> element"

      remove_comments(main)
      remove_covering_links(main)
      main.css(REMOVED_ELEMENTS.join(", ")).each(&:remove)
      main.css("a, button").each { convert_to_span(it) }
      main.css("*").each { clean_attributes(it) }
      LocalTimes.apply(main, time_zone: @time_zone)

      page(main.inner_html.strip)
    end

    private

    def remove_comments(node)
      node.xpath(".//comment()").each(&:remove)
    end

    def remove_covering_links(node)
      node.css(COVERING_LINKS).each do |link|
        parent = link.parent
        parent.add_class("card-interactive") if parent.classes.include?("card")
        remove_with_trailing_whitespace(link)
      end
    end

    def remove_with_trailing_whitespace(node)
      following = node.next_sibling
      following.remove if following&.text? && following.content.strip.empty? && node.previous_sibling&.text?
      node.remove
    end

    def convert_to_span(node)
      node.name = "span"
      node.remove_attribute("type")
    end

    def clean_attributes(node)
      node.attribute_nodes.each do |attribute|
        name = attribute.name
        node.remove_attribute(name) if REMOVED_ATTRIBUTES.include?(name) || name.match?(REMOVED_ATTRIBUTE_PATTERN)
      end

      node.remove_attribute("id") if node["id"]&.match?(/_\d+\z/)
      node.remove_attribute("aria-label") if node.name == "span" && node.children.empty?
      clean_style(node)
    end

    def clean_style(node)
      return unless node["style"]

      declarations = node["style"].split(";").map(&:strip).reject { it.empty? || it.start_with?("view-transition-name") }
      declarations.any? ? node["style"] = declarations.join("; ") + ";" : node.remove_attribute("style")
    end

    def page(content)
      <<~HTML
        <!DOCTYPE html>
        <html style="overscroll-behavior: none;"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>JobJournal</title>
        <meta name="viewport" content="width=device-width,initial-scale=1">

          <style>
        #{@css.strip}

        #{EXTRA_CSS}  </style>
          </head>

          <body class="bg-neutral-200/80 dark:bg-black text-normal">
            <div class="bg-white dark:bg-neutral-925">
              <main class="container mx-auto pt-28 pb-16">
        #{content}
              </main>
            </div>
        </body></html>
      HTML
    end
  end
end
