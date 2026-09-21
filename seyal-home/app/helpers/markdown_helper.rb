module MarkdownHelper
  ALLOWED_TAGS = %w[
    h1 h2 h3 h4 h5 h6 p br hr strong em b i u del ins
    blockquote ul ol li dl dt dd a img code pre span div
    table thead tbody tfoot tr th td sup sub
  ].freeze

  ALLOWED_ATTRIBUTES = %w[href src alt title class id].freeze

  RENDERER = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(hard_wrap: true),
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    superscript: true,
    underline: true,
    highlight: true,
    footnotes: true
  )

  def markdown_to_html(markdown)
    sanitize(RENDERER.render(markdown.to_s), tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end
end
