# frozen_string_literal: true

Markdowndocs.configure do |config|
  # Path to markdown files (default: Rails.root.join("app/docs"))
  # config.docs_path = Rails.root.join("app", "docs")

  # Category → slug mapping
  # Maps category names to arrays of markdown file slugs (filenames without .md).
  # Bare slugs ("welcome") match files at app/docs/. Path-prefixed slugs
  # ("technical/architecture") match files in mode subdirectories — see modes
  # below.
  config.categories = {
    # "Getting Started" => %w[introduction quickstart],
    # "Guides" => %w[authentication deployment],
    # "Reference" => %w[api-reference technical/architecture]
  }

  # Available documentation modes (default: %w[guide technical])
  #
  # Each entry in `modes` also doubles as a path-based audience scope: files
  # under `app/docs/<mode>/` are visible ONLY in that mode and served at
  # `/docs/<mode>/<slug>`. Files at the docs root are shared across all modes.
  #
  #   app/docs/
  #   ├── welcome.md              → shared, visible in every mode
  #   └── technical/
  #       └── architecture.md     → technical mode only
  #
  # config.modes = %w[guide technical]

  # Default mode (default: "guide")
  # config.default_mode = "guide"

  # Rouge syntax highlighting theme (default: "github")
  # config.rouge_theme = "github"

  # Cache expiry for rendered markdown (default: 1.hour)
  # config.cache_expiry = 1.hour

  # Enable full-text search on the documentation index (default: false)
  # Adds a search bar that filters docs by title, description, and content
  # config.search_enabled = true

  # Allow a curated, safe subset of inline SVG for hand-authored diagrams
  # (default: false). Scripts, event handlers, and javascript: URIs are
  # always stripped by the sanitizer regardless of this setting.
  # config.allow_svg = true

  # Optional: Resolve current user's mode preference from database
  # Return nil to fall back to cookie/default
  # config.user_mode_resolver = ->(controller) {
  #   controller.send(:current_user)&.preferences&.docs_mode
  # }

  # Optional: Save user's mode preference to database
  # config.user_mode_saver = ->(controller, mode) {
  #   controller.send(:current_user)&.preferences&.update!(docs_mode: mode)
  # }
end
