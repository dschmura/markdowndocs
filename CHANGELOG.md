# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-02-21

### Fixed

- Stimulus controllers and vendored minisearch now auto-register with the host app's importmap. Previously, host apps had to manually add pins to `config/importmap.rb`.
- Engine now registers `app/assets/javascripts` in the asset pipeline paths so Propshaft/Sprockets can serve the JS files.
- Install generator now injects importmap pins into the host app's `config/importmap.rb` during installation.
- Both asset and importmap initializers gracefully skip when the host app doesn't use the relevant gems.

## [0.2.0] - 2026-02-21

### Added

- Opt-in full-text search for the documentation index page (`config.search_enabled = true`)
- Pre-built JSON search index served from `/docs/search_index` endpoint
- Instant search-as-you-type powered by vendored MiniSearch (~7KB gzipped)
- Stimulus controller (`docs_search_controller`) with debounced input, fuzzy matching, and prefix search
- Title matches boosted 3x, description matches boosted 2x for relevance ranking
- Cards and category sections auto-hide/show based on search results
- "No matching documents" empty state when search yields no results
- `plain_text_content` method on `Documentation` model for stripped searchable text
- Search index cached via `Rails.cache` with file-mtime-based invalidation

## [0.1.5] - 2026-02-20

### Changed

- Move mobile navigation dropdown above the main content area (directly under breadcrumbs) so it's accessible without scrolling. Desktop sidebar remains in the right column.

## [0.1.4] - 2026-02-20

### Added

- Hamburger menu for mobile sidebar navigation — replaces the plain chevron toggle with a hamburger/X icon, smooth slide-down animation, and proper `aria-expanded` state management. Desktop sidebar behavior unchanged.

## [0.1.3] - 2026-02-20

### Fixed

- Install generator now injects a Tailwind `@source` directive into the host app's CSS so the gem's view templates are scanned for CSS classes. Without this, Tailwind 4 purges the gem's layout classes (grid, sticky sidebar, etc.) and the sidebar renders at the bottom of the page instead of as a column.

## [0.1.2] - 2026-02-20

### Fixed

- `root_path` in host app layouts now resolves to the host app's root (`/`) instead of the engine's root (`/docs/`). The engine defines its own `root` route, so the existing `method_missing` delegation couldn't intercept it. Added explicit `root_path`/`root_url` overrides that delegate to `main_app`.

## [0.1.1] - 2026-02-20

### Fixed

- Host app route helpers (e.g., `about_path`, `root_path`) now resolve correctly when rendered inside the engine's layout context. Previously, `isolate_namespace` caused these helpers to resolve against the engine's catch-all `:slug` route, producing URLs like `/docs/about` instead of `/about`. Replaced `helper Rails.application.routes.url_helpers` with `main_app` delegation pattern.

## [0.1.0] - 2026-02-20

### Added

- Mountable Rails engine that serves markdown files as a browsable documentation site
- GitHub Flavored Markdown rendering via Commonmarker (tables, task lists, strikethrough, autolinks, footnotes)
- Syntax highlighting via Rouge with configurable theme
- YAML front matter support for per-document title, description, and mode availability
- Mode-based content filtering using HTML comment blocks
- Category organization for the index page
- Auto-generated table of contents from H2/H3 headings with anchor links
- Breadcrumb navigation and related-documents sidebar
- File-mtime-based cache invalidation using Rails.cache
- HTML sanitization via rails-html-sanitizer
- Directory traversal prevention via slug validation
- i18n support for all UI strings
- Install generator (`rails generate markdowndocs:install`)

[0.2.1]: https://github.com/dschmura/markdowndocs/releases/tag/v0.2.1
[0.2.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.2.0
[0.1.5]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.5
[0.1.4]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.4
[0.1.3]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.3
[0.1.2]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.2
[0.1.1]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.1
[0.1.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.0
