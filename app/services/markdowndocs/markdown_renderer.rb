# frozen_string_literal: true

require "commonmarker"
require "rouge"
require "rails-html-sanitizer"

module Markdowndocs
  # Service for rendering Markdown content to HTML with syntax highlighting and security measures.
  # Uses commonmarker for GFM (GitHub Flavored Markdown) and Rouge for syntax highlighting.
  class MarkdownRenderer
    class << self
      def render(markdown, cache_key: nil, mode: nil)
        return "" if markdown.blank?

        filtered_markdown = filter_by_mode(markdown, mode)

        if cache_key.present?
          mode_key = mode.present? ? "#{cache_key}:#{mode}" : cache_key
          Rails.cache.fetch("markdowndocs:#{mode_key}", expires_in: Markdowndocs.config.cache_expiry) do
            render_markdown(filtered_markdown)
          end
        else
          render_markdown(filtered_markdown)
        end
      end

      private

      def filter_by_mode(markdown, mode)
        valid_modes = Markdowndocs.config.modes
        return markdown if mode.blank? || !valid_modes.include?(mode)

        mode_block_pattern = /<!--\s*mode:\s*(\w+)\s*-->(.*?)<!--\s*\/mode\s*-->/m

        markdown.gsub(mode_block_pattern) do |_match|
          block_mode = ::Regexp.last_match(1).downcase
          block_content = ::Regexp.last_match(2)

          if block_mode == "all" || block_mode == mode
            block_content
          else
            ""
          end
        end
      end

      def render_markdown(markdown)
        options = markdown_render_options
        doc = Commonmarker.parse(markdown, options: options)
        html = doc.to_html(options: options)
        html = apply_syntax_highlighting(html)
        sanitize_html(html)
      rescue => e
        # Bare rescue is intentional: third-party errors from commonmarker,
        # Gumbo (Nokogiri::HTML5), Rouge, and Loofah are diverse and not
        # worth enumerating. We never want a single malformed doc — e.g.
        # a deeply nested inline SVG — to blank-render the page. Logs
        # carry the diagnostic; the user sees their content as text.
        Rails.logger.error("Markdowndocs::MarkdownRenderer error: #{e.message}")
        Rails.logger.error(e.backtrace.first(20).join("\n"))
        render_fallback(markdown)
      end

      def render_fallback(markdown)
        escaped = ERB::Util.html_escape(markdown.to_s)
        %(<pre class="markdowndocs-render-error">#{escaped}</pre>)
      end

      def apply_syntax_highlighting(html)
        # HTML5 parsing preserves case-sensitive SVG/MathML foreign-content
        # attributes (e.g. viewBox) that Nokogiri::HTML would lowercase.
        doc = Nokogiri::HTML5.fragment(html)

        doc.css("pre[lang]").each do |pre|
          language = pre["lang"]
          code = pre.at_css("code")
          next unless code

          text = code.text

          if language && lexer_exists?(language)
            highlighted = highlight_code(text, language)
            pre.replace(highlighted)
          end
        end

        doc.to_html
      end

      def lexer_exists?(language)
        Rouge::Lexer.find(language).present?
      rescue
        false
      end

      def highlight_code(code, language)
        lexer = Rouge::Lexer.find(language)
        formatter = Rouge::Formatters::HTML.new(css_class: "highlight")

        highlighted = formatter.format(lexer.lex(code))
        "<pre class=\"highlight\"><code>#{highlighted}</code></pre>"
      rescue => e
        Rails.logger.warn("Syntax highlighting failed for language '#{language}': #{e.message}")
        "<pre><code>#{ERB::Util.html_escape(code)}</code></pre>"
      end

      # Force commonmarker to pass raw HTML through when SVG is allowed, so the
      # markup reaches the sanitizer (the security boundary) instead of being
      # escaped. Returns a copy — does not mutate the configured options.
      def markdown_render_options
        options = Markdowndocs.config.markdown_options
        return options unless Markdowndocs.config.allow_svg

        options.merge(render: (options[:render] || {}).merge(unsafe: true))
      end

      BASE_SANITIZE_TAGS = %w[
        h1 h2 h3 h4 h5 h6 p br hr blockquote
        ul ol li dl dt dd
        table thead tbody tfoot tr th td
        a img
        strong em b i u del
        code pre span div
      ].freeze

      BASE_SANITIZE_ATTRS = %w[href title src alt align class lang].freeze

      # Curated structural SVG subset. Deliberately excludes script,
      # foreignObject, and SMIL animate/set tags, plus all on* handlers — the
      # SafeListSanitizer drops anything not listed, so scripts/handlers and
      # javascript: URIs are stripped even with unsafe HTML enabled.
      SVG_SANITIZE_TAGS = %w[
        svg g path rect circle ellipse line polyline polygon
        text tspan defs marker title desc
      ].freeze

      SVG_SANITIZE_ATTRS = %w[
        viewBox d points
        x y x1 y1 x2 y2 cx cy r rx ry width height
        fill stroke stroke-width stroke-linecap stroke-linejoin stroke-dasharray
        transform opacity text-anchor dominant-baseline
        font-size font-family font-weight
        marker-start marker-end markerWidth markerHeight refX refY orient
        role aria-label id
      ].freeze

      def sanitize_html(html)
        allow_svg = Markdowndocs.config.allow_svg

        Rails::HTML5::SafeListSanitizer.new.sanitize(
          html,
          tags: allow_svg ? BASE_SANITIZE_TAGS + SVG_SANITIZE_TAGS : BASE_SANITIZE_TAGS,
          attributes: allow_svg ? BASE_SANITIZE_ATTRS + SVG_SANITIZE_ATTRS : BASE_SANITIZE_ATTRS
        )
      end
    end
  end
end
