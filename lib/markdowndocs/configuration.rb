# frozen_string_literal: true

module Markdowndocs
  class Configuration
    attr_accessor :docs_path, :categories, :modes, :default_mode,
      :markdown_options, :rouge_theme, :cache_expiry,
      :user_mode_resolver, :user_mode_saver

    def initialize
      @docs_path = nil # Resolved lazily so Rails.root is available
      @categories = {}
      @modes = %w[guide technical]
      @default_mode = "guide"
      @markdown_options = default_markdown_options
      @rouge_theme = "github"
      @cache_expiry = 1.hour
      @user_mode_resolver = nil
      @user_mode_saver = nil
    end

    # Lazily resolve docs_path so Rails.root is available
    def resolved_docs_path
      @docs_path || Rails.root.join("app", "docs")
    end

    private

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
