# Path-Based Audience Routing — Design Spec

- **Date:** 2026-05-15
- **Status:** Approved for planning
- **Target version:** v0.7.0
- **Driver:** Editor experience — make documentation content easily updatable by different groups of editors using only filesystem conventions, without requiring frontmatter literacy.

## Context

The markdowndocs gem currently supports audience-specific content through three mechanisms layered on a single concept of "current mode" (one of the strings in `Markdowndocs.config.modes`, default `%w[guide technical]`):

| Layer | Where | Reference |
|---|---|---|
| Config universe | `config.modes` | [configuration.rb:13](../../../lib/markdowndocs/configuration.rb#L13) |
| Whole-doc filter | `audience:` YAML frontmatter (v0.6.0, 2026-05-13) | [docs_controller.rb:15](../../../app/controllers/markdowndocs/docs_controller.rb#L15) |
| In-doc fragment filter | `<!-- mode: X -->...<!-- /mode -->` HTML comments | [markdown_renderer.rb:29-45](../../../app/services/markdowndocs/markdown_renderer.rb#L29-L45) |

The current per-request mode is resolved in [docs_controller.rb:90-98](../../../app/controllers/markdowndocs/docs_controller.rb#L90-L98) from `params[:mode]`, then `Markdowndocs.config.user_mode_resolver`, then a cookie, then `config.default_mode`.

There is no authorization layer — any visitor can append `?mode=technical` and view audience-restricted content. The `user_mode_resolver` lambda only resolves a user's *preferred* mode, not a *permitted* set.

## Problem

Two related issues motivate this design:

1. **Authoring ergonomics.** `audience:` frontmatter requires editors to learn YAML conventions. Non-technical contributors making a content edit cannot easily tell, just by browsing the repo, which docs belong to which audience. Documents from different audiences are commingled in one directory.
2. **Editor isolation.** Different teams should be able to own different slices of the documentation (e.g., engineering owns technical docs, customer success owns guide docs). Today there is no filesystem signal that supports this — CODEOWNERS, branch protection, IDE folder views, and OS permissions all key off paths, but `audience:` lives inside the files.

This spec **does not** address authorization (gating viewer access by role/group). That concern was explicitly scoped out of the gem during brainstorming; host apps will continue to gate access externally (e.g., by wrapping `mount Markdowndocs::Engine` in an `authenticate` block).

## Design Decisions

### D1. Subdirectory-named modes drive whole-doc audience scoping

Files under `app/docs/` are scoped to audiences by their location:

```
app/docs/
├── getting_started.md         → shared (visible in every mode)
├── billing.md                 → shared
└── technical/
    ├── architecture.md        → technical mode only
    └── billing.md             → technical mode only
```

**Rule:** A first-level subdirectory of the docs root whose name exactly matches an entry in `Markdowndocs.config.modes` is an *audience scope*. Files inside that subdirectory are visible only when the current mode equals the subdirectory name.

**Files at the docs root are *shared* — visible in every mode.**

**Non-mode subdirectories.** A first-level subdirectory whose name does *not* match any entry in `config.modes` is ignored by the document discovery walker. The gem logs a warning once per boot for each such subdirectory:

```
[Markdowndocs] Ignoring subdirectory app/docs/api/ — name does not match any
configured mode (config.modes = ["guide", "technical"]). Files inside this
subdirectory will not be discovered. Move them into app/docs/ or into a
mode-named subdirectory.
```

Nested subdirectories within a mode scope (`app/docs/technical/sub/foo.md`) are also out of scope for this design; see "Out of Scope" below.

**Empty mode subdirectories.** `config.modes` may declare modes that have no corresponding subdirectory yet (e.g., a host is planning to add `sre` content). The mode remains valid for preference, the switcher offers it, and its index shows only shared docs. This is not an error.

Alternatives considered:
- *Filename-suffix variant* (`getting_started_technical.md`): rejected. CODEOWNERS patterns compose poorly with suffixes, mode renames touch every file, and the convention scales worse to N modes.
- *Default-mode-only at root* (root = only the default mode, every audience is a silo): rejected. Less natural for shared "About us" or "Getting started" docs that all audiences should read.

### D2. Distinct URLs (RESTful)

Each markdown file maps to exactly one URL. URLs do not change content based on mode.

| File | URL |
|---|---|
| `app/docs/getting_started.md` | `/docs/getting_started` |
| `app/docs/technical/architecture.md` | `/docs/technical/architecture` |
| `app/docs/technical/getting_started.md` | `/docs/technical/getting_started` |

This means it is valid for both `app/docs/getting_started.md` and `app/docs/technical/getting_started.md` to exist simultaneously — they are two distinct documents at two distinct URLs, sharing the slug `getting_started` within different mode locations.

**Rationale:** Shared links must point to a specific document. A reader copying `/docs/getting_started` from their address bar and pasting it into Slack expects every recipient to see the same content, regardless of which mode the recipient prefers.

### D3. Mode is a discovery preference, not an access gate

The gem does not authorize URL access by mode. A user in guide mode whose browser hits `/docs/technical/architecture` receives the document. The mode setting only affects:

- Which docs appear in the index
- Which docs appear in the sidebar / related-docs list
- Which docs are returned by search (when `config.search_enabled` is true)
- Mode switcher behavior (see D6)

Host apps that wish to restrict access to a subtree wrap the engine mount in their existing auth system. Examples:

```ruby
# config/routes.rb in the host app
authenticate :user, ->(u) { u.staff? } do
  mount Markdowndocs::Engine, at: "/docs"
end
```

…or place a parent controller in front of the engine, or use route constraints. None of this is the gem's responsibility.

### D4. Index page composition: merged into configured categories

Per mode, the index shows the union of shared docs and that mode's docs, slotted into the categories declared in `Markdowndocs.config.categories`. There is no separate "Shared" section, no audience badge, and no auto-generated mode-named category.

Categories whose visible-doc set is empty under the current mode are dropped from the index (matches the v0.6.0 behavior for `audience:` frontmatter).

### D5. `config.categories` slug format

`config.categories` continues to accept a hash of `String category_name => Array<String> slugs`. The slug entries gain a path-prefix convention:

```ruby
config.categories = {
  "Getting Started" => %w[welcome quickstart],
  "Architecture"    => %w[technical/architecture technical/data_model],
  "Billing"         => %w[billing technical/billing]
}
```

| Slug entry | Matches file | Visible in |
|---|---|---|
| `welcome` | `app/docs/welcome.md` | Every mode |
| `technical/architecture` | `app/docs/technical/architecture.md` | Technical mode only |
| `billing` | `app/docs/billing.md` | Every mode |
| `technical/billing` | `app/docs/technical/billing.md` | Technical mode only |

A bare slug (no slash) matches a file at the docs root. A path-prefixed slug (one slash) matches a file in a mode subdirectory. The first segment of a path-prefixed slug must equal an entry in `config.modes`.

### D6. Mode switcher behavior: smart navigation

When the user toggles the mode switcher, the engine attempts to navigate to a same-slug document in the target mode's location. The slug used for comparison is the basename of the current doc's source path (file name without `.md`).

**Unified lookup rule.** Given target mode `M`, current slug `S`, and current URL `U`:

1. If `app/docs/M/S.md` exists AND its URL is not equal to `U` → redirect to its URL.
2. Else if `app/docs/S.md` exists AND its URL is not equal to `U` → redirect to its URL.
3. Else → stay on `U`.

In all three branches, persist the new preference (cookie + `user_mode_saver` if configured). The "not equal to `U`" guard prevents pointless self-redirects.

Applied to each case:

| Currently viewing | Toggle to | Lookup | Outcome |
|---|---|---|---|
| `/docs/billing` | technical | `app/docs/technical/billing.md`? else `app/docs/billing.md` (= U, skip) | Redirect to `/docs/technical/billing` if it exists; else stay |
| `/docs/technical/billing` | guide | `app/docs/guide/billing.md`? else `app/docs/billing.md` | Redirect to the guide variant if it exists; else redirect to shared if it exists; else stay |
| `/docs/technical/architecture` (no shared sibling) | guide | `app/docs/guide/architecture.md`? else `app/docs/architecture.md` (neither exists) | Stay on `/docs/technical/architecture` |
| `/docs` (index, no slug) | technical | n/a — no slug to look up | Stay on `/docs`. Index re-renders with technical-mode content |

The lookup is direction-agnostic: the same rule handles shared→mode, mode→shared (implicit), and mode→other-mode transitions.

### D7. `audience:` frontmatter is deprecated

Authors using `audience:` in front matter receive a deprecation warning at request time (logged once per file path per process boot) suggesting the file-move migration. The key continues to function in v0.7.x exactly as it does in v0.6.x — no behavior change for hosts that have already adopted it.

**Warning text:**

```text
[Markdowndocs] DEPRECATION: `audience:` frontmatter in app/docs/foo.md is
deprecated. Move the file to app/docs/technical/foo.md instead and remove
the `audience:` key. The `audience:` key will be removed in v1.0.0.
```

For multi-audience frontmatter (`audience: [guide, technical]`), the suggested target is the file root (no move) and dropping the key. The warning emitter substitutes the right suggestion based on the resolved audience array.

**Removal target:** v1.0.0. (This gem is pre-1.0; the 0.7.x → 1.0.0 transition is the deprecation window.)

### D8. `<!-- mode: -->` HTML-comment blocks are unchanged

The block-level filter in [markdown_renderer.rb:29-45](../../../app/services/markdowndocs/markdown_renderer.rb#L29-L45) is orthogonal to whole-doc placement and continues to serve in-doc fragment filtering. No deprecation, no rename, no behavior change.

## URL Routing & Slug Validation

The current route mounts `DocsController#show` at `/docs/:slug` with the validator `SAFE_SLUG_PATTERN = /\A[a-zA-Z0-9_-]+\z/` in [docs_controller.rb:9](../../../app/controllers/markdowndocs/docs_controller.rb#L9).

Path-based routing adds a new shape: `/docs/<mode>/:slug` where `<mode>` is one of `config.modes`. Recommended routing approach:

- Add a new constrained route: `GET /docs/:mode/:slug` where `:mode` is constrained to `config.modes`.
- Both routes call `DocsController#show`; the controller resolves the file path from `(params[:mode], params[:slug])` using the same `SAFE_SLUG_PATTERN`.
- Directory traversal protection: the slug regex already prevents `..` and `/` in slugs. The mode segment is constrained by `config.modes`, so it cannot smuggle traversal.

`SAFE_SLUG_PATTERN` does not need to change — slugs remain segment-flat. Nested-subdirectory support (e.g., `docs/technical/sub/foo.md`) is **out of scope** for this design.

## Documentation Model Changes

`Markdowndocs::Documentation` (in [app/models/markdowndocs/documentation.rb](../../../app/models/markdowndocs/documentation.rb), to be edited) gains the following:

- **File discovery** walks `app/docs/*.md` (root) and `app/docs/<mode>/*.md` (for each mode in `config.modes`). Each Documentation instance is tagged with its source path; the audience is derived from the first path segment under `app/docs/`.
- **`Documentation#audience`** returns `Array<String>` (matches v0.6.x contract — never nil):
  - `Markdowndocs.config.modes.dup` for shared docs at root with no `audience:` frontmatter — visible everywhere. Observationally identical to v0.6.x.
  - `["technical"]` (single-element array) for a file at `app/docs/technical/foo.md` with no frontmatter — visible only in technical mode.
  - The value from `audience:` frontmatter when present — frontmatter wins for backward compat, AND emits the deprecation warning. (Mixing path-scoping with `audience:` frontmatter is an unusual combination but not an error.)
- **`Documentation#visible_to?(mode)`** unchanged in signature, updated semantics: `nil` audience → always visible; otherwise `audience.include?(mode)`.
- **`Documentation.find_by_slug(slug, mode: nil)`** resolves to:
  - `app/docs/<mode>/<slug>.md` if `mode` is non-nil AND the file exists in that subdirectory; OR
  - `app/docs/<slug>.md` if it exists at root AND `visible_to?(mode)` returns true; OR
  - `nil`.
- **`Documentation.grouped_by_category(mode: nil)`** filters the visible set: shared docs always pass; mode-scoped docs pass only when `mode` matches their audience. Empty categories are dropped (unchanged from v0.6.0).

No public API is removed. All existing call sites continue to work.

## Migration Guide (host-app-facing)

This will be inlined in the v0.7.0 release notes and CHANGELOG entry.

**URL stability.** Every existing URL continues to resolve. A host upgrading from v0.6.x to v0.7.0 without moving any files sees zero URL changes. Path-based routing introduces *new* URLs (`/docs/<mode>/<slug>`) for files that the host explicitly relocates into mode subdirectories. Search-engine indexed URLs, shared links, and bookmarks all keep working.

### If you don't use `audience:` today

No action required. Your existing root-level docs continue to render in every mode. Adopt the new convention at your leisure: create `app/docs/technical/` (or whatever mode directory you want) and move technical-only docs into it.

### If you use `audience: <single-mode>` today

For each such doc:

```
# before
app/docs/foo.md
---
audience: technical
---

# after
app/docs/technical/foo.md
(no `audience:` key)
```

The deprecation warning will surface in your logs and tell you which file to move.

### If you use `audience: [guide, technical]` today

The doc is already explicitly multi-audience. Move it to root and drop the key:

```
# before
app/docs/foo.md
---
audience: [guide, technical]
---

# after
app/docs/foo.md
(no `audience:` key — root = shared = visible in every mode)
```

### `config.categories` update

If you have technical-only docs that appear in categories on the index, prefix their slugs:

```ruby
# before
config.categories = {
  "Architecture" => %w[architecture data_model]
}

# after (technical-only architecture + shared data_model)
config.categories = {
  "Architecture" => %w[technical/architecture data_model]
}
```

Bare slugs continue to mean "the doc at the root with this name." No change needed for shared-only or guide-only categories.

## Test Surface

Each item below is a behavior that must be covered before v0.7.0 ships. Phrased as a test name suggestion.

### File discovery and visibility
- `Documentation.all` includes root files in every mode
- `Documentation.all` includes mode-subdirectory files only in that mode
- `Documentation.grouped_by_category(mode: "guide")` excludes `app/docs/technical/*` entries
- `Documentation.grouped_by_category(mode: "technical")` includes both root and `app/docs/technical/*` entries
- A category with no visible docs in the current mode is dropped
- A subdirectory whose name is NOT in `config.modes` is ignored (does not appear in any mode's listing) — and a warning is logged once per boot

### URL routing
- `GET /docs/billing` renders `app/docs/billing.md`
- `GET /docs/technical/billing` renders `app/docs/technical/billing.md` (independent doc, NOT a content-swap of the shared one)
- `GET /docs/technical/billing` returns the doc even when the request's mode is `guide` (D3: no access gating)
- `GET /docs/notamode/foo` returns 404 (the `:mode` segment must match a configured mode)
- `GET /docs/technical/../etc/passwd` returns 404 (slug pattern rejects)

### Mode switcher
- Toggling from guide → technical on `/docs/billing` (with `app/docs/technical/billing.md` present) redirects to `/docs/technical/billing`
- Toggling from guide → technical on `/docs/billing` (no technical sibling) stays on `/docs/billing` and updates preference
- Toggling from technical → guide on `/docs/technical/architecture` (no shared sibling) stays on `/docs/technical/architecture`
- Toggling on `/docs` (index) stays on `/docs` and the next render reflects the new mode
- Preference is persisted via cookie and (when configured) `user_mode_saver`

### `audience:` deprecation
- A doc with `audience: technical` continues to render correctly in v0.7.0
- A deprecation warning is logged (once per file per boot) when such a doc is loaded
- The warning text includes the file path and the suggested target path

### Existing block-comment filtering
- `<!-- mode: technical -->...<!-- /mode -->` content still strips in non-matching modes (unchanged from v0.6.x)
- `<!-- mode: all -->...<!-- /mode -->` content remains in every mode

## Out of Scope

These were considered and explicitly excluded from this design. Each may become its own follow-on spec.

- **Authorization / role-based access control.** Host apps gate access via standard Rails patterns ([feedback memory](../../../.claude/projects/-Users-dschmura-Documents-code-markdowndocs/memory/feedback_no_auth_in_gem.md)).
- **Inline browser editing.** Future feature.
- **"Edit on GitHub" links.** Small follow-on.
- **Directories as automatic categories.** `config.categories` remains the source of truth for the index. Subdirectories that match a mode are audience scopes only, not categories.
- **Nested mode-subdirectory paths.** `app/docs/technical/sub/foo.md` is not supported in this design. Files inside a mode subdirectory are flat.
- **Per-doc role/group frontmatter.** `audience:` was the closest existing analogue; it's deprecated. No new frontmatter keys for authorization.

## Open Questions

None. All decisions captured above were resolved during the 2026-05-15 brainstorming session.
