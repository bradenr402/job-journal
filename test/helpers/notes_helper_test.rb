require 'test_helper'

class NotesHelperTest < ActionView::TestCase
  test 'markdown_to_html returns empty string for blank content' do
    assert_equal '', markdown_to_html(nil)
    assert_equal '', markdown_to_html('')
    assert_equal '', markdown_to_html(' ')
  end

  test 'markdown_to_html converts links to anchor tags' do
    markdown = '[link](https://example.com)'
    expected_html = '<p><a href="https://example.com">link</a></p>'
    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html converts headings to h* tags with anchors' do
    markdown = <<~MD
      # Heading 1
      ## Heading 2
      ### Heading 3
      #### Heading 4
      ##### Heading 5
      ###### Heading 6
    MD

    expected_html = <<~HTML
      <h1><a href="#heading-1"></a>Heading 1</h1>
      <h2><a href="#heading-2"></a>Heading 2</h2>
      <h3><a href="#heading-3"></a>Heading 3</h3>
      <h4><a href="#heading-4"></a>Heading 4</h4>
      <h5><a href="#heading-5"></a>Heading 5</h5>
      <h6><a href="#heading-6"></a>Heading 6</h6>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles code blocks properly' do
    markdown = <<~MD
      ```ruby
      puts "Hello, world!"
      ```
    MD

    expected_html = <<~HTML
      <pre><code>puts "Hello, world!" </code></pre>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles inline code properly' do
    markdown = <<~MD
      `console.log('Hello, world!')`
    MD

    expected_html = <<~HTML
      <p><code>console.log('Hello, world!')</code></p>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles ordered lists properly' do
    markdown = <<~MD
      1. First
      2. Second
      3. Third
    MD

    expected_html = <<~HTML
      <ol>
        <li>First</li>
        <li>Second</li>
        <li>Third</li>
      </ol>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles unordered lists properly' do
    markdown = <<~MD
      - First
      - Second
      - Third
    MD

    expected_html = <<~HTML
      <ul>
        <li>First</li>
        <li>Second</li>
        <li>Third</li>
      </ul>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles nested lists properly' do
    markdown = <<~MD
    1. First item
       1. Nested ordered item
       2. Nested ordered item
    3. Second item
       - Nested unordered item
       - Nested unordered item
    4. Third item
       - Nested unordered item
         1. Deeply nested ordered item
         2. Deeply nested ordered item
    MD

    expected_html = <<~HTML
    <ol>
      <li>First item
        <ol>
          <li>Nested ordered item</li>
          <li>Nested ordered item</li>
        </ol>
      </li>
      <li>Second item
        <ul>
          <li>Nested unordered item</li>
          <li>Nested unordered item</li>
        </ul>
      </li>
      <li>Third item
        <ul>
          <li>Nested unordered item
            <ol>
              <li>Deeply nested ordered item</li>
              <li>Deeply nested ordered item</li>
            </ol>
          </li>
        </ul>
      </li>
    </ol>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles blockquotes correctly' do
    markdown = <<~MD
      > This is a blockquote
    MD

    expected_html = <<~HTML
      <blockquote>
      <p>This is a blockquote</p>
      </blockquote>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles horizontal rules correctly' do
    markdown = <<~MD
      ---
    MD

    expected_html = <<~HTML
      <hr>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end

  test 'markdown_to_html handles bold and italics correctly' do
    markdown = <<~MD
      *Italic text*
      **Bold text**
      ***Bold and italic text***
    MD

    expected_html = <<~HTML
      <p><em>Italic text</em><br>
      <strong>Bold text</strong><br>
      <em><strong>Bold and italic text</strong></em></p>
    HTML

    output = markdown_to_html(markdown)
    assert_equal expected_html.squish, output.squish
  end
end
