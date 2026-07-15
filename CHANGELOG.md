# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.11.2] - 2026-07-15

### Accessibility

- **Scrollable code blocks are keyboard-focusable.** Long lines make a `<pre>`
  overflow horizontally via the host's CSS; a scrollable region that isn't
  focusable strands keyboard-only users (WCAG 2.1.1; axe
  `scrollable-region-focusable`). Every rendered code block now carries
  `tabindex="0"`, mirroring the same fix already applied to wide tables in
  0.11.0. No `aria-label` is added — a `<pre>`'s own text is its accessible
  name.

## [0.11.1] - 2026-07-13

### Accessibility (follow-up review)

- **Caption-less tables get a numbered, localized accessible name.** v0.11.0
  labelled every un-captioned table the hardcoded English `"Table"`, so a
  page of tables was undifferentiated to a screen reader and unlocalized.
  They are now `"Table 1"`, `"Table 2"`, … via the new
  `markdowndocs.table_label` I18n key (`"Table %{number}"`).

## [0.11.0] - 2026-07-13

### Accessibility

- **Keyboard-scrollable tables (WCAG 2.1.1).** A wide GFM table overflows and
  becomes horizontally scrollable via the host's typography CSS. The renderer
  now marks every `<table>` with `tabindex="0"` so keyboard-only users can
  scroll it with the arrow keys (axe `scrollable-region-focusable`). The
  table's implicit `role="table"` is preserved — no `role="region"` is added,
  which would strip row/column semantics — and an un-captioned table gets a
  minimal `aria-label="Table"` so the focus stop is announced. `tabindex` is
  now in the sanitizer's base attribute allow-list.
- **44px chrome target sizes (WCAG 2.5.5 AAA).** Sidebar table-of-contents
  links, related-documentation links, breadcrumb links, and the audience
  mode-switcher buttons now meet the 44×44 minimum target size (they measured
  ~20–28px). Purely additive utility classes; no visual change beyond the
  taller hit area.

## [0.10.0] - 2026-06-24

### Added

- **Persistent audience switcher.** The viewing-mode switcher now renders in a
  toolbar at the top of both the docs index and every doc page (new
  `markdowndocs/docs/_docs_toolbar` partial), instead of only the show-page
  sidebar — the audience choice is always visible and rendered once per page.
  `DocsController#index` and `#show` both expose `@available_modes` from
  `config.modes`.
- **Screen-reader mode announcement.** Switching audience sets `flash[:notice]`
  (`markdowndocs.mode_announcement`), surfaced in a `role="status"
  aria-live="polite"` region in the engine layout so the Turbo-replace mode
  change isn't silent for assistive tech. Hosts may render the flash their own way.

### Changed

- **No-counterpart audience switch goes to the target index.** Switching to a
  mode where the current doc has no counterpart (and no shared-root fallback)
  now redirects to that audience's index — with a distinct flash
  (`markdowndocs.no_counterpart_announcement`) — instead of stranding the reader
  on a doc outside the audience they chose. Topic-preserving (scoped counterpart)
  and shared-root docs are unchanged.

### Fixed

- **Mode switcher ARIA: toggle-button group, not a radiogroup.** Each mode is a
  submit button using `aria-pressed` (was `role="radio"` / `aria-checked`, which
  implied unimplemented arrow-key navigation). Focus returns to the chosen button
  after the Turbo replace.

## [0.9.0] - 2026-06-21

### Added

- **Collapsible disclosure (`<details>` / `<summary>`).** Both tags — plus the
  `open` attribute — are now in the sanitizer allow-list, so docs can use native,
  no-JS click-to-expand sections. Rides the same curated raw-HTML passthrough as
  inline SVG (requires `config.allow_svg = true`, which flips commonmarker to
  unsafe so the markup reaches the sanitizer). Scripts and `on*` handlers inside
  a disclosure are still stripped.

## [0.8.0] - 2026-05-29

### Added

- **Opt-in inline SVG (`config.allow_svg`).** When set to `true`, a curated,
  safe subset of structural SVG tags and attributes is permitted in rendered
  documents — useful for hand-authored diagrams. The `Rails::HTML5`
  SafeListSanitizer remains the security boundary: `<script>`,
  `<foreignObject>`, `on*` event handlers, and `javascript:` URIs are still
  stripped. Defaults to `false`, so existing behavior is unchanged.

### Fixed

- Heading-anchor injection, table-of-contents extraction, and syntax
  highlighting now parse with `Nokogiri::HTML5` instead of `Nokogiri::HTML`,
  preserving case-sensitive SVG/MathML foreign-content attributes (e.g.
  `viewBox`, `markerWidth`, `refX`) that were previously lowercased on
  re-serialization, which silently broke any inline SVG.

## [0.7.0] - 2026-05-15

### Added

- **Path-based audience routing.** A first-level subdirectory of
  `app/docs/` whose name matches an entry in `config.modes` is now
  treated as an audience scope. Files inside `app/docs/technical/` are
  visible only when the current mode is `technical`; files at the root
  remain shared (visible in every mode). The new convention is the
  recommended way to scope whole documents and replaces `audience:`
  frontmatter (see Deprecated below).
- **`/docs/:mode/:slug` route.** Mode-scoped documents are served at
  stable, RESTful URLs (e.g., `/docs/technical/architecture`). The
  `:mode` segment is constrained to entries in `config.modes`; unknown
  modes return 404.
- **Path-prefixed slugs in `config.categories`.** Slug entries may now
  include a mode prefix (e.g., `"technical/architecture"`) to attach a
  mode-scoped doc to a category. Bare slugs continue to match root
  files. Example:

      config.categories = {
        "Architecture" => %w[technical/architecture]
      }

- **Smart navigation in mode switcher.** Toggling the mode now attempts
  to navigate to a same-slug document in the target mode's location,
  falling back to the shared root sibling, then staying put. Sharing
  links still works because URLs are stable.
- **`Markdowndocs.deprecator`** ActiveSupport::Deprecation instance for
  emitting gem-specific deprecation warnings. Hosts can configure
  behavior (silence / raise / log) via standard
  `ActiveSupport::Deprecation` APIs.

### Changed

- `Documentation.all` walks both `app/docs/*.md` and
  `app/docs/<mode>/*.md` for every configured mode.
- `Documentation` instances expose `#path_slug` (the file's path
  relative to the docs root, sans `.md`).
- `Documentation.find_by_slug(slug, mode:)` prefers the mode-scoped
  file first, then falls back to the root.
- `PreferencesController#update` now expects a `current_path` form
  field (added in `_mode_switcher.html.erb`) and computes the smart-nav
  target before redirecting. Hosts with custom forms targeting
  `preference_path` should include `<input type="hidden"
  name="current_path" value="<%= request.fullpath %>">` to opt into
  smart navigation. Without it, the controller redirects to the docs
  index (no behavior loss, just no smart-nav benefit).

### Deprecated

- **`audience:` frontmatter.** Still functional, but emits a one-shot
  warning per file path per process boot. Will be removed in v1.0.0.
  Migration: move the file into a matching mode subdirectory (or, for
  multi-audience docs, drop the key — root files are shared). The
  warning message includes the suggested target path.

### Migration notes

- See `README.md` ("Migrating from v0.6.x to v0.7.0") for full guidance.
- URL stability: every URL from v0.6.x continues to resolve unchanged.
- Subdirectories under `app/docs/` whose name doesn't match a
  configured mode are now ignored (one-line warning at discovery). If
  you've been using non-mode subdirectories for organization, either
  flatten them or rename them to match a configured mode.

## [0.6.1] - 2026-05-13

### Fixed

- **Duplicate `id="docs-mode-switcher"` in the DOM** (issue #20). The
  show layout renders `_navigation` (and therefore the mode switcher)
  twice — once for the mobile sidebar, once for the desktop sidebar.
  The hardcoded id on `_mode_switcher.html.erb` produced two elements
  with the same id on every doc show page, a WCAG 4.1.1 violation.

  Dropped the `id=` from the partial entirely. Stimulus already scopes
  the controller via `data-controller="docs-mode"`, which can appear
  N times in a document without colliding.

  Host apps / tests / custom CSS selecting via `#docs-mode-switcher`
  should switch to `[data-controller="docs-mode"]`. Note: any host app
  relying on that id was already in a broken state (duplicate ids in
  the DOM); this fix surfaces the issue rather than creating it.

### Migration notes

- If you have a CSS rule like `#docs-mode-switcher { ... }`, change it
  to `[data-controller="docs-mode"] { ... }`.
- If you have a Capybara test using `within "#docs-mode-switcher"`,
  change it to `within first("[data-controller='docs-mode']")` (or
  similar — the partial may render twice depending on your layout).

## [0.6.0] - 2026-05-13

### Added

- `audience:` frontmatter key on individual docs. Accepts a single string
  or an array of mode names (e.g. `audience: technical`, or
  `audience: [guide, technical]`). When the current mode does not appear
  in a doc's audience, the doc is hidden from the index and unreachable
  via slug (returns 404). Docs WITHOUT an `audience:` key remain visible
  in every mode — fully backward compatible with pre-0.6 docs.
- `Documentation#audience` returns the resolved audience as `Array<String>`.
- `Documentation#visible_to?(mode)` predicate. `nil` mode means no filter.
- `Documentation.find_by_slug(slug, mode: nil)` and
  `Documentation.grouped_by_category(mode: nil)` both accept an optional
  `mode:` kwarg. Default behavior (no kwarg) is unchanged — backward
  compatible signature.

### Changed

- `Documentation.grouped_by_category` now drops empty categories when a
  `mode:` filter is applied — categories whose docs are all hidden by the
  current audience no longer render as empty headers.
- `Markdowndocs::DocsController#index` and `#show` pass the resolved
  `@docs_mode` through to `Documentation` so the index reflects the
  user's mode pick. URL guessing / shared links to wrong-audience docs
  now return 404.

### Migration notes

- No action required if you don't use modes. Existing docs continue to
  appear in both `guide` and `technical` modes.
- To restrict a doc to a specific audience, add `audience: technical`
  (or `audience: guide`) to its frontmatter.
- To make a doc explicitly multi-audience, use `audience: [guide, technical]`.

## [0.5.0] - 2026-05-05

### Added

- Dark mode support across all docs templates. Every `bg-*`, `text-*`, and
  `border-*` class now has a paired `dark:` variant chosen for WCAG 2.2 AAA
  contrast (7:1) on dark surfaces. Host apps with `class="dark"` on `<html>`
  (or `prefers-color-scheme: dark`) will see proper dark theming without
  needing to override gem views.

### Changed

- Bumped indigo link colors from `text-indigo-600` to `text-indigo-700` (light)
  and `text-indigo-300` (dark) so links pass AAA contrast on both surfaces.
- Selected-state mode-switcher cyan text bumped from `text-cyan-700`/`-800` to
  `text-cyan-900` (light) and `text-cyan-100` (dark) for AAA against the
  selected card's `bg-cyan-50`/`bg-cyan-900/40` background.
- `prose-indigo` content area now also applies `dark:prose-invert` so the
  rendered Markdown body inverts cleanly in dark mode.

## [0.4.0] - 2026-03-20

### Changed

- Engine now uses its own layout instead of inheriting the host app's layout, eliminating route helper conflicts caused by `isolate_namespace`. Host apps can override at `app/views/layouts/markdowndocs/application.html.erb` or configure via `config.layout`.
- Supports `content_for` blocks (`:docs_header`, `:docs_footer`, `:head`, `:title`) for customization.
- Removed `ensure_host_route_helpers` `before_action` — no longer needed with isolated layout.

## [0.3.1] - 2026-03-20

### Changed

- Fenced code block content is now indexed as a low-boost (0.5x) search field, making class names, methods, and config keys in examples discoverable.
- Visible cards are now reordered by MiniSearch relevance score within each category.
- Search debounce reduced from 150ms to 50ms for snappier results.

## [0.3.0] - 2026-03-20

### Added

- Keywords frontmatter support (`keywords: [login, signin, ...]`) indexed by full-text search with highest boost (4x), improving search relevance for docs with explicit keyword tags.

## [0.2.3] - 2026-03-20

### Fixed

- Host app route helpers (e.g., `about_path`) no longer resolve against the engine namespace. Replaced `method_missing` delegation with explicit `define_method` overrides built lazily on first request via `before_action`.

## [0.2.2] - 2026-03-18

### Changed

- Stimulus controllers now auto-register via a single JS entry point (`import "markdowndocs"`), following the ActionText/Trix pattern. Host apps no longer need to pin individual controllers in their importmap.
- Install generator adds `import "markdowndocs"` to the host app's `application.js` instead of injecting importmap pins.
- Added engine and generator specs for the new JS registration flow.

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

[0.7.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.7.0
[0.6.1]: https://github.com/dschmura/markdowndocs/releases/tag/v0.6.1
[0.6.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.6.0
[0.5.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.5.0
[0.4.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.4.0
[0.3.1]: https://github.com/dschmura/markdowndocs/releases/tag/v0.3.1
[0.3.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.3.0
[0.2.3]: https://github.com/dschmura/markdowndocs/releases/tag/v0.2.3
[0.2.2]: https://github.com/dschmura/markdowndocs/releases/tag/v0.2.2
[0.2.1]: https://github.com/dschmura/markdowndocs/releases/tag/v0.2.1
[0.2.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.2.0
[0.1.5]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.5
[0.1.4]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.4
[0.1.3]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.3
[0.1.2]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.2
[0.1.1]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.1
[0.1.0]: https://github.com/dschmura/markdowndocs/releases/tag/v0.1.0
