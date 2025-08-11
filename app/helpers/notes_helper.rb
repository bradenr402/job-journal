module NotesHelper
  def markdown_to_html(content)
    return '' if content.blank?

    html = Commonmarker.to_html(content)

    sanitize(
      html,
      tags: %w[h1 h2 h3 h4 h5 h6 p br strong em a code pre blockquote ul ol li br hr],
      attributes: %w[href]
    )
  end
end
