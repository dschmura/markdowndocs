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
        doc = Commonmarker.parse(markdown, options: Markdowndocs.config.markdown_options)
        html = doc.to_html(options: Markdowndocs.config.markdown_options)
        html = apply_syntax_highlighting(html)
        sanitize_html(html)
      rescue StandardError => e
        Rails.logger.error("Markdowndocs::MarkdownRenderer error: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        ""
      end

      def apply_syntax_highlighting(html)
        doc = Nokogiri::HTML.fragment(html)

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
      rescue StandardError
        false
      end

      def highlight_code(code, language)
        lexer = Rouge::Lexer.find(language)
        formatter = Rouge::Formatters::HTML.new(css_class: "highlight")

        highlighted = formatter.format(lexer.lex(code))
        "<pre class=\"highlight\"><code>#{highlighted}</code></pre>"
      rescue StandardError => e
        Rails.logger.warn("Syntax highlighting failed for language '#{language}': #{e.message}")
        "<pre><code>#{ERB::Util.html_escape(code)}</code></pre>"
      end

      def sanitize_html(html)
        sanitizer = Rails::HTML5::SafeListSanitizer.new

        sanitizer.sanitize(
          html,
          tags: %w[
            h1 h2 h3 h4 h5 h6 p br hr blockquote
            ul ol li dl dt dd
            table thead tbody tfoot tr th td
            a img
            strong em b i u del
            code pre span div
          ],
          attributes: %w[
            href title
            src alt
            align
            class lang
          ]
        )
      end
    end
  end
end
