# frozen_string_literal: true

module Markdowndocs
  module DocsHelper
    def generate_table_of_contents(html)
      return [] if html.blank?

      doc = Nokogiri::HTML.fragment(html)
      toc_items = []

      doc.css("h2, h3").each do |heading|
        text = heading.text.strip
        next if text.blank?

        slug = heading["id"].presence || slugify_heading(text)

        toc_items << {
          text: text,
          slug: slug,
          level: heading.name[1].to_i
        }
      end

      toc_items
    end

    def slugify_heading(text)
      text.to_s
        .downcase
        .gsub(/[^\w\s-]/, "")
        .gsub(/\s+/, "-").squeeze("-")
        .gsub(/^-|-$/, "")
    end

    def add_heading_anchors(html)
      return html if html.blank?

      doc = Nokogiri::HTML.fragment(html)

      doc.css("h2, h3").each do |heading|
        text = heading.text.strip
        next if text.blank?

        unless heading["id"].present?
          slug = slugify_heading(text)
          heading["id"] = slug
        end
      end

      doc.css("a.anchor").each do |anchor|
        anchor.remove if anchor.text.strip.empty?
      end

      doc.to_html
    end

    def markdowndocs_format_breadcrumbs(category, title)
      [
        {name: "Docs", path: markdowndocs.root_path, current: false},
        {name: category, path: nil, current: false},
        {name: title, path: nil, current: true}
      ]
    end
  end
end
