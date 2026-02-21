# frozen_string_literal: true

module Markdowndocs
  # Documentation PORO (Plain Old Ruby Object)
  # Represents markdown documentation files from a configurable directory.
  # Handles metadata extraction, frontmatter parsing, and category associations.
  class Documentation
    attr_reader :slug, :title, :description, :category, :file_path

    def initialize(file_path)
      @file_path = file_path
      @slug = derive_slug
      extract_metadata
      @category = assign_category
    end

    def self.all
      docs_path = Markdowndocs.config.resolved_docs_path
      return [] unless docs_path.exist?

      Dir.glob(docs_path.join("*.md")).map do |file|
        new(Pathname.new(file))
      end.sort_by(&:slug)
    end

    def self.find_by_slug(slug)
      return nil if slug.blank?
      return nil if slug.include?("..") || slug.include?("/")

      file_path = Markdowndocs.config.resolved_docs_path.join("#{slug}.md")
      return nil unless file_path.exist?

      new(file_path)
    rescue => e
      Rails.logger.error("Error finding documentation by slug '#{slug}': #{e.message}")
      nil
    end

    def self.by_category(category)
      all.select { |doc| doc.category == category }
    end

    def self.grouped_by_category
      Markdowndocs.config.categories.each_with_object({}) do |(category, slugs), hash|
        hash[category] = slugs.map { |slug| find_by_slug(slug) }.compact
      end
    end

    def content
      @content ||= file_path.read
    rescue => e
      Rails.logger.error("Error reading documentation file '#{file_path}': #{e.message}")
      ""
    end

    def cache_key
      "#{slug}-#{mtime.to_i}"
    end

    def mtime
      @mtime ||= file_path.mtime
    rescue
      Time.current
    end

    def available_modes
      @available_modes ||= begin
        parsed = parse_frontmatter
        modes = parsed[:frontmatter]["modes"]
        modes.is_a?(Array) ? modes.map(&:to_s) : Markdowndocs.config.modes.dup
      end
    end

    def default_mode
      @default_mode ||= begin
        parsed = parse_frontmatter
        mode = parsed[:frontmatter]["default_mode"]
        mode.present? ? mode.to_s : Markdowndocs.config.default_mode
      end
    end

    def supports_mode?(mode)
      available_modes.include?(mode.to_s)
    end

    # Returns content stripped of frontmatter, markdown syntax, and HTML tags
    # for use in search indexing.
    def plain_text_content
      parsed = parse_frontmatter
      text = parsed[:markdown]
      text = text.gsub(/^#+\s*/, "")          # headings
      text = text.gsub(/\[([^\]]+)\]\([^)]+\)/, '\1') # links
      text = text.gsub(/[*_~`]/, "")          # emphasis markers
      text = text.gsub(/```[\s\S]*?```/, "")  # fenced code blocks
      text = text.gsub(/<[^>]+>/, "")         # HTML tags
      text = text.gsub(/^\s*[-*+]\s/, "")     # list markers
      text = text.gsub(/\n{2,}/, "\n")        # collapse blank lines
      text.strip
    end

    private

    def derive_slug
      file_path.basename(".md").to_s
    end

    def extract_metadata
      parsed = parse_frontmatter

      if parsed[:frontmatter].present?
        @title = parsed[:frontmatter]["title"] || extract_title_from_markdown(parsed[:markdown])
        @description = parsed[:frontmatter]["description"] || extract_description_from_markdown(parsed[:markdown])
      else
        @title = extract_title_from_markdown(content)
        @description = extract_description_from_markdown(content)
      end

      @title ||= slug.titleize
      @description ||= "Documentation for #{@title}"
    end

    def parse_frontmatter
      text = content
      frontmatter = {}
      markdown = text

      if text.start_with?("---")
        parts = text.split(/^---\s*$/, 3)
        if parts.size >= 3
          begin
            frontmatter = YAML.safe_load(parts[1]) || {}
            markdown = parts[2].strip
          rescue Psych::SyntaxError => e
            Rails.logger.warn("Invalid YAML frontmatter in #{file_path}: #{e.message}")
          end
        end
      end

      {frontmatter: frontmatter, markdown: markdown}
    end

    def extract_title_from_markdown(text)
      match = text.match(/^#\s+(.+?)$/m)
      match ? match[1].strip : nil
    end

    def extract_description_from_markdown(text)
      text = text.split(/^---\s*$/, 3).last if text.start_with?("---")

      lines = text.lines
      in_heading_block = true
      paragraphs = []
      current_paragraph = []

      lines.each do |line|
        stripped = line.strip

        if stripped.start_with?("#")
          in_heading_block = false
          next
        end

        next if in_heading_block && stripped.empty?

        in_heading_block = false

        if stripped.empty?
          if current_paragraph.any?
            paragraphs << current_paragraph.join(" ").strip
            current_paragraph = []
          end
        else
          current_paragraph << stripped
        end
      end

      paragraphs << current_paragraph.join(" ").strip if current_paragraph.any?

      description = paragraphs.find { |p| p.present? && p.length > 10 }
      description&.truncate(200)
    end

    def assign_category
      Markdowndocs.config.categories.each do |category, slugs|
        return category if slugs.include?(slug)
      end

      "Other"
    end
  end
end
