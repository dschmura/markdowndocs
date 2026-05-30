# frozen_string_literal: true

module Markdowndocs
  class Configuration
    # Route segments owned by the engine itself. A mode name matching any
    # of these would collide with built-in routes / controller actions.
    RESERVED_MODE_NAMES = %w[search_index preference preferences].freeze

    attr_accessor :docs_path, :categories, :default_mode,
      :markdown_options, :rouge_theme, :cache_expiry,
      :user_mode_resolver, :user_mode_saver, :search_enabled,
      :layout, :allow_svg
    attr_reader :modes, :non_mode_subdirs_warned, :audience_deprecation_emitted

    def modes=(value)
      @modes = normalize_modes(value)
    end

    def initialize
      @docs_path = nil # Resolved lazily so Rails.root is available
      @categories = {}
      self.modes = %w[guide technical]
      @default_mode = "guide"
      @markdown_options = default_markdown_options
      @rouge_theme = "github"
      @cache_expiry = 1.hour
      @user_mode_resolver = nil
      @user_mode_saver = nil
      @search_enabled = false
      @layout = "markdowndocs/application"
      # Opt-in: allow a curated, safe inline-SVG subset in rendered docs.
      # When true, the renderer passes raw HTML through commonmarker (unsafe)
      # and the sanitizer (the security boundary) whitelists structural SVG
      # tags/attributes while still stripping scripts/handlers. Default off.
      @allow_svg = false
      @non_mode_subdirs_warned = Set.new
      @audience_deprecation_emitted = Set.new
    end

    # Lazily resolve docs_path so Rails.root is available
    def resolved_docs_path
      @docs_path || Rails.root.join("app", "docs")
    end

    private

    def normalize_modes(value)
      list = Array(value).map do |entry|
        unless entry.is_a?(String)
          raise ArgumentError,
            "config.modes entries must be strings; got #{entry.inspect}"
        end

        name = entry.strip

        if name.empty?
          raise ArgumentError, "config.modes contains an invalid empty entry"
        end

        if name.match?(%r{[/?#&\s]})
          raise ArgumentError,
            "config.modes entry #{entry.inspect} is invalid — names cannot contain " \
            "path separators, URL-significant characters, or whitespace"
        end

        if RESERVED_MODE_NAMES.include?(name)
          raise ArgumentError,
            "config.modes entry #{name.inspect} is reserved by the engine " \
            "(conflicts with built-in route or controller). " \
            "Reserved names: #{RESERVED_MODE_NAMES.join(", ")}"
        end

        name
      end

      list.uniq
    end

    def default_markdown_options
      {
        parse: {
          smart: true,
          default_info_string: nil
        },
        render: {
          unsafe: false,
          github_pre_lang: true,
          full_info_string: true,
          hardbreaks: false,
          sourcepos: false,
          escaped_char_spans: true
        },
        extension: {
          strikethrough: true,
          tagfilter: true,
          table: true,
          autolink: true,
          tasklist: true,
          footnotes: true,
          description_lists: true,
          front_matter_delimiter: "---",
          shortcodes: false,
          header_ids: ""
        }
      }
    end
  end
end
