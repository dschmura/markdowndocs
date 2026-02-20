# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.2]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.2
[0.1.1]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.1
[0.1.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.0
