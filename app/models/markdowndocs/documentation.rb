# frozen_string_literal: true

module Markdowndocs
  # Documentation PORO (Plain Old Ruby Object)
  # Represents markdown documentation files from a configurable directory.
  # Handles metadata extraction, frontmatter parsing, and category associations.
  class Documentation
    attr_reader :slug, :path_slug, :title, :description, :category, :file_path, :keywords

    def initialize(file_path)
      @file_path = file_path
      @slug = derive_slug
      @path_slug = derive_path_slug
      extract_metadata
      @category = assign_category
    end

    def self.all
      docs_path = Markdowndocs.config.resolved_docs_path
      return [] unless docs_path.exist?

      files = Dir.glob(docs_path.join("*.md"))

      modes = Markdowndocs.config.modes
      modes.each do |mode|
        mode_dir = docs_path.join(mode)
        files.concat(Dir.glob(mode_dir.join("*.md"))) if mode_dir.exist?
      end

      warn_about_non_mode_subdirectories(docs_path, modes)

      files.map { |f| new(Pathname.new(f)) }.sort_by(&:path_slug)
    end

    # Emits a one-shot warning per process boot for each first-level
    # subdirectory under docs_path that isn't a configured mode. Files
    # inside such subdirectories are silently dropped by discovery —
    # the warning makes that visible.
    def self.warn_about_non_mode_subdirectories(docs_path, modes)
      warned = Markdowndocs.config.non_mode_subdirs_warned

      children = begin
        docs_path.children
      rescue Errno::ENOENT, Errno::EACCES => e
        Rails.logger.warn("[Markdowndocs] Could not scan for non-mode subdirectories: #{e.message}")
        return
      end

      children.each do |child|
        next unless child.directory?
        name = child.basename.to_s
        next if modes.include?(name)
        next if warned.include?(name)

        warned << name
        Rails.logger.warn(
          "[Markdowndocs] Ignoring subdirectory #{child}/ — name does not match " \
          "any configured mode (config.modes = #{modes.inspect}). Files inside " \
          "this subdirectory will not be discovered. Move them into #{docs_path}/ " \
          "or into a mode-named subdirectory."
        )
      end
    end
    private_class_method :warn_about_non_mode_subdirectories

    # Resolves a doc by slug. When `mode:` is given, prefers the mode-scoped
    # file (docs/<mode>/<slug>.md) and falls back to the root (docs/<slug>.md)
    # if visible_to?(mode) passes. With `mode: nil`, only the root is checked.
    def self.find_by_slug(slug, mode: nil)
      return nil if slug.blank?
      return nil if slug.include?("..") || slug.include?("/")

      docs_path = Markdowndocs.config.resolved_docs_path

      if mode.present? && Markdowndocs.config.modes.include?(mode.to_s)
        scoped = docs_path.join(mode.to_s, "#{slug}.md")
        return new(scoped) if scoped.exist?
      end

      root = docs_path.join("#{slug}.md")
      return nil unless root.exist?

      doc = new(root)
      return nil unless doc.visible_to?(mode)

      doc
    rescue => e
      Rails.logger.error("Error finding documentation by slug '#{slug}': #{e.message}")
      nil
    end

    def self.by_category(category)
      all.select { |doc| doc.category == category }
    end

    # When `mode:` is given, filters out docs whose `audience:` excludes
    # that mode AND drops categories that end up empty (so the index
    # sidebar doesn't render headers with no children).
    def self.grouped_by_category(mode: nil)
      Markdowndocs.config.categories.each_with_object({}) do |(category, slugs), hash|
        docs = slugs.map { |slug| find_by_slug(slug, mode: mode) }.compact
        hash[category] = docs unless docs.empty?
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

    # The audience(s) this doc is written for. Resolution order:
    #   1. `audience:` frontmatter (DEPRECATED in 0.7.0, removed in 1.0.0)
    #   2. Parent directory name when it matches a configured mode
    #   3. All configured modes (root file with no override — visible everywhere)
    def audience
      @audience ||= begin
        parsed = parse_frontmatter
        raw = parsed[:frontmatter]["audience"]
        case raw
        when Array then raw.map(&:to_s)
        when String then [raw]
        when nil
          scope = audience_from_path
          scope ? [scope] : Markdowndocs.config.modes.dup
        else Markdowndocs.config.modes.dup
        end
      end
    end

    # Whether this doc should be surfaced to a viewer in the given mode.
    # `nil` mode is treated as "no filter" — useful for callers that
    # don't care about audience (search indexer, admin tools).
    def visible_to?(mode)
      return true if mode.nil?
      audience.include?(mode.to_s)
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

    # Returns text extracted from fenced code blocks for search indexing.
    def code_content
      parsed = parse_frontmatter
      blocks = parsed[:markdown].scan(/```\w*\n([\s\S]*?)```/)
      blocks.flatten.join(" ").gsub(/\s+/, " ").strip
    end

    private

    def derive_slug
      file_path.basename(".md").to_s
    end

    def derive_path_slug
      docs_root = Markdowndocs.config.resolved_docs_path
      relative = file_path.relative_path_from(docs_root)
      relative.sub_ext("").to_s
    end

    def audience_from_path
      dir = file_path.dirname.basename.to_s
      Markdowndocs.config.modes.include?(dir) ? dir : nil
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
      @keywords = Array(parsed[:frontmatter]["keywords"])
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
        return category if slugs.include?(path_slug)
      end

      "Other"
    end
  end
end
