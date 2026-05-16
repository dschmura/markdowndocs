# Path-Based Audience Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add path-based audience routing to the markdowndocs gem (v0.7.0) — subdirectory-named modes scope whole docs, root docs are shared, RESTful URLs are stable, mode switcher does smart navigation, and `audience:` frontmatter is deprecated.

**Architecture:** A first-level subdirectory under `app/docs/` whose name matches an entry in `Markdowndocs.config.modes` becomes an audience scope. Files inside it are visible only when the current mode matches the subdirectory name. Files at root are shared (visible in every mode). Two URL shapes are served by the same `DocsController#show`: `/docs/:slug` (root) and `/docs/:mode/:slug` (scoped), the latter via a regex-constrained route. The `Documentation` PORO gains a `path_slug` attribute (`"technical/architecture"` for a scoped file, `"billing"` for a root file) used by both category matching and audience derivation. `PreferencesController#update` becomes smart-navigation aware: it computes the target URL using the unified lookup rule (target-mode-subdir file → root file → stay) and redirects there.

**Tech Stack:** Ruby 3.2+, Rails ≥ 7.1, RSpec, Capybara-free system specs, ActiveSupport::Deprecation, Pathname.

**Spec:** [docs/superpowers/specs/2026-05-15-path-based-audience-routing-design.md](../specs/2026-05-15-path-based-audience-routing-design.md)

---

## File Structure

### Files to create

| Path | Responsibility |
|---|---|
| `spec/dummy/app/docs/billing.md` | Shared fixture — visible in every mode |
| `spec/dummy/app/docs/technical/architecture.md` | Technical-only fixture, no shared sibling |
| `spec/dummy/app/docs/technical/billing.md` | Technical sibling to `docs/billing.md` (tests override path / smart nav) |

### Files to modify

| Path | Change |
|---|---|
| `app/models/markdowndocs/documentation.rb` | Add `path_slug` attribute; walk mode subdirs in `.all`; derive audience from path; resolve mode-scoped paths in `.find_by_slug`; emit deprecation warning when `audience:` frontmatter is used |
| `app/controllers/markdowndocs/docs_controller.rb` | Read `params[:mode]` in `#show`; pass to `Documentation.find_by_slug` |
| `app/controllers/markdowndocs/preferences_controller.rb` | Smart-nav target URL computation; replace `redirect_back` with the computed target |
| `app/views/markdowndocs/docs/_mode_switcher.html.erb` | Pass `current_path` to the preferences form |
| `config/routes.rb` (engine) | Add constrained `:mode/:slug` route before `:slug` |
| `lib/markdowndocs.rb` | Add `Markdowndocs.deprecator` helper (ActiveSupport::Deprecation instance) |
| `lib/markdowndocs/configuration.rb` | Add `audience_deprecation_emitted` Set for once-per-file warning tracking |
| `spec/spec_helper.rb` | Add new fixtures to the test category configuration |
| `spec/models/markdowndocs/documentation_spec.rb` | Tests for new behavior |
| `spec/requests/markdowndocs/docs_spec.rb` | Request specs for `/docs/:mode/:slug` |
| `spec/requests/markdowndocs/preferences_spec.rb` | New file — request specs for smart navigation |
| `README.md` | Document the new convention, new categories slug format, migration steps |
| `CHANGELOG.md` | Add v0.7.0 entry |
| `lib/markdowndocs/version.rb` | Bump to `0.7.0` |

---

## Task 1: Add path-based test fixtures

**Files:**

- Create: `spec/dummy/app/docs/billing.md`
- Create: `spec/dummy/app/docs/technical/architecture.md`
- Create: `spec/dummy/app/docs/technical/billing.md`
- Modify: `spec/spec_helper.rb` (extend `categories` config to reference the new fixtures)

- [ ] **Step 1: Create the shared `billing.md` fixture**

Create `spec/dummy/app/docs/billing.md`:

```markdown
---
title: Billing
description: How billing works for all customers
---

# Billing

This is the shared billing doc, visible to every audience. It explains
the customer-facing aspects of billing.
```

- [ ] **Step 2: Create the technical subdirectory and architecture fixture**

```bash
mkdir -p spec/dummy/app/docs/technical
```

Create `spec/dummy/app/docs/technical/architecture.md`:

```markdown
---
title: System Architecture
description: How the billing service is wired internally
---

# System Architecture

Technical-only doc with no shared sibling. Used to verify smart-nav
fallback behavior when toggling to guide mode (should stay put).
```

- [ ] **Step 3: Create the technical billing sibling**

Create `spec/dummy/app/docs/technical/billing.md`:

```markdown
---
title: Billing Internals
description: Stripe webhook plumbing and idempotency keys
---

# Billing Internals

Technical sibling to the shared billing doc. Used to verify the smart-nav
override path (toggle from guide → technical jumps here when sitting on
the shared /docs/billing).
```

- [ ] **Step 4: Extend the test category configuration**

Modify `spec/spec_helper.rb`. Find both `Markdowndocs.configure` blocks (one in `before(:suite)`, one in `after`) and update the `c.categories` hash in both:

```ruby
c.categories = {
  "Getting Started" => %w[welcome quickstart],
  "Guides" => %w[authentication billing],
  "Administrator Reference" => %w[admin-reference],
  "Architecture" => %w[technical/architecture technical/billing]
}
```

This exercises both bare slugs (`billing`) and path-prefixed slugs (`technical/architecture`, `technical/billing`).

- [ ] **Step 5: Run existing suite to confirm no regressions from fixtures alone**

Run: `bundle exec rspec`
Expected: All existing tests still pass. The new fixtures are present on disk but no test references them yet. There may be a NEW failure where `grouped_by_category` builds a "Architecture" category whose slugs `technical/architecture` resolve to nothing under today's code — that's expected and will turn green in Task 3. If the existing tests pass and only the new path-prefix slugs produce empty/missing docs (which is fine because `grouped_by_category` already drops empty categories), the commit can proceed.

- [ ] **Step 6: Commit**

```bash
git add spec/dummy/app/docs/billing.md \
        spec/dummy/app/docs/technical/architecture.md \
        spec/dummy/app/docs/technical/billing.md \
        spec/spec_helper.rb
git commit -m "test: add fixtures for path-based audience routing"
```

---

## Task 2: Documentation walks mode subdirectories and derives `path_slug`

**Files:**

- Modify: `app/models/markdowndocs/documentation.rb`
- Test: `spec/models/markdowndocs/documentation_spec.rb`

The `Documentation` PORO learns two new things in this task:

1. `Documentation.all` walks both the root and each mode-named subdirectory under `app/docs/`.
2. Each instance gains a `path_slug` attribute (the file's path relative to docs root, sans `.md`). This is used in subsequent tasks for category matching and audience derivation.

- [ ] **Step 1: Write failing tests for path-based discovery**

Add to `spec/models/markdowndocs/documentation_spec.rb` (inside the existing `describe ".all"` block):

```ruby
context "with files in mode-named subdirectories" do
  it "discovers files in subdirectories whose name matches a configured mode" do
    slugs = described_class.all.map(&:slug)
    expect(slugs).to include("architecture", "billing")
    # `billing` appears twice: docs/billing.md AND docs/technical/billing.md.
    # We use path_slug in later tests to distinguish them.
  end

  it "exposes the path relative to the docs root via #path_slug" do
    path_slugs = described_class.all.map(&:path_slug)
    expect(path_slugs).to include("billing")
    expect(path_slugs).to include("technical/architecture")
    expect(path_slugs).to include("technical/billing")
  end

  it "ignores subdirectories whose name is not in config.modes" do
    Dir.mktmpdir do |tmp|
      docs = Pathname.new(tmp)
      docs.join("root.md").write("# Root\n")
      docs.join("api").mkpath
      docs.join("api", "ignored.md").write("# Ignored\n")
      docs.join("technical").mkpath
      docs.join("technical", "kept.md").write("# Kept\n")

      Markdowndocs.config.docs_path = docs
      slugs = described_class.all.map(&:slug)

      expect(slugs).to include("root", "kept")
      expect(slugs).not_to include("ignored")
    end
  end

  it "logs a warning the first time a non-mode subdirectory is encountered" do
    Dir.mktmpdir do |tmp|
      docs = Pathname.new(tmp)
      docs.join("api").mkpath
      docs.join("api", "ignored.md").write("# Ignored\n")

      Markdowndocs.config.docs_path = docs

      log_messages = []
      original_logger = Rails.logger
      Rails.logger = Logger.new(StringIO.new).tap do |l|
        l.formatter = ->(_sev, _t, _p, msg) { log_messages << msg.to_s; "" }
      end

      begin
        2.times { described_class.all }
      ensure
        Rails.logger = original_logger
      end

      api_warnings = log_messages.select { |m| m.include?("Ignoring subdirectory") && m.include?("api") }
      expect(api_warnings.size).to eq(1), "expected exactly one warning, got #{api_warnings.size}: #{api_warnings.inspect}"
    end
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "with files in mode-named subdirectories"`
Expected: FAIL. Errors should be of the form `expected to include "architecture"` (because `Dir.glob(docs_path.join("*.md"))` doesn't descend), `NoMethodError: undefined method path_slug` (the attribute doesn't exist yet), and the non-mode-subdirectory warning test fails because no warning is emitted today.

- [ ] **Step 3: Implement `path_slug` and subdirectory discovery**

Modify `app/models/markdowndocs/documentation.rb`. Replace the `attr_reader` line:

```ruby
attr_reader :slug, :path_slug, :title, :description, :category, :file_path, :keywords
```

Replace `initialize`:

```ruby
def initialize(file_path)
  @file_path = file_path
  @slug = derive_slug
  @path_slug = derive_path_slug
  extract_metadata
  @category = assign_category
end
```

Add the `derive_path_slug` method in the private section, right after `derive_slug`:

```ruby
def derive_path_slug
  docs_root = Markdowndocs.config.resolved_docs_path
  relative = file_path.relative_path_from(docs_root)
  relative.sub_ext("").to_s
end
```

Replace `self.all`:

```ruby
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
  Markdowndocs.config.non_mode_subdirs_warned ||= Set.new

  docs_path.children.each do |child|
    next unless child.directory?
    name = child.basename.to_s
    next if modes.include?(name)
    next if Markdowndocs.config.non_mode_subdirs_warned.include?(name)

    Markdowndocs.config.non_mode_subdirs_warned << name
    Rails.logger.warn(
      "[Markdowndocs] Ignoring subdirectory #{child}/ — name does not match " \
      "any configured mode (config.modes = #{modes.inspect}). Files inside " \
      "this subdirectory will not be discovered. Move them into #{docs_path}/ " \
      "or into a mode-named subdirectory."
    )
  end
rescue => e
  # Don't let a discovery-time warning failure break .all.
  Rails.logger.warn("[Markdowndocs] Could not scan for non-mode subdirectories: #{e.message}")
end
```

Note: sorting by `path_slug` groups files by audience scope. The pre-existing `.sort_by(&:slug)` would have placed `docs/billing.md` and `docs/technical/billing.md` adjacent (both `billing`), which is confusing. `path_slug` ordering puts root files first alphabetically, then each mode's subdirectory.

The `non_mode_subdirs_warned` Set lives on `Markdowndocs.config` so test teardown (via `Markdowndocs.reset_configuration!`) resets it between tests — same pattern used by the audience-deprecation tracking in Task 9. Add it to the Configuration in this task to keep the implementation self-contained:

Modify `lib/markdowndocs/configuration.rb`. Add `require "set"` at the top of the file (if not already present), then add an attribute and initializer assignment:

```ruby
attr_accessor :docs_path, :categories, :modes, :default_mode,
  :markdown_options, :rouge_theme, :cache_expiry,
  :user_mode_resolver, :user_mode_saver, :search_enabled,
  :layout, :non_mode_subdirs_warned
```

Inside `initialize`:

```ruby
@non_mode_subdirs_warned = Set.new
```

- [ ] **Step 4: Run tests, verify pass**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "with files in mode-named subdirectories"`
Expected: PASS.

Then run the full Documentation spec to catch regressions:

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb`
Expected: All previously passing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add app/models/markdowndocs/documentation.rb \
        spec/models/markdowndocs/documentation_spec.rb
git commit -m "feat: Documentation walks mode subdirectories and exposes path_slug"
```

---

## Task 3: Documentation derives audience from path

**Files:**

- Modify: `app/models/markdowndocs/documentation.rb`
- Test: `spec/models/markdowndocs/documentation_spec.rb`

When `audience:` frontmatter is absent, audience is derived from the parent directory:

- Root files (`docs/foo.md`) → `audience = config.modes.dup` (visible everywhere, identical to v0.6.x backward-compat behavior).
- Mode-subdirectory files (`docs/technical/foo.md`) → `audience = ["technical"]` (visible in technical mode only).

`audience:` frontmatter still wins when present.

- [ ] **Step 1: Write failing tests for audience derivation**

Add to `spec/models/markdowndocs/documentation_spec.rb`, near the existing `audience` tests (or create a new `describe "#audience"` block if none exists):

```ruby
describe "#audience (path-based)" do
  it "returns all configured modes for a root file with no frontmatter audience" do
    doc = described_class.find_by_slug("billing")
    expect(doc.audience).to match_array(Markdowndocs.config.modes)
  end

  it "returns a single-element array of the subdirectory name for a mode-scoped file" do
    doc = described_class.all.find { |d| d.path_slug == "technical/architecture" }
    expect(doc).not_to be_nil
    expect(doc.audience).to eq(["technical"])
  end

  it "lets `audience:` frontmatter override the path-derived value (backward compat)" do
    # admin-reference.md is at the root with `audience: technical` in frontmatter.
    doc = described_class.all.find { |d| d.slug == "admin-reference" }
    expect(doc.audience).to eq(["technical"])
  end
end

describe "#visible_to?" do
  it "returns true for a root file in any configured mode" do
    doc = described_class.find_by_slug("billing")
    expect(doc.visible_to?("guide")).to be true
    expect(doc.visible_to?("technical")).to be true
  end

  it "returns false for a mode-scoped file in a non-matching mode" do
    doc = described_class.all.find { |d| d.path_slug == "technical/architecture" }
    expect(doc.visible_to?("guide")).to be false
    expect(doc.visible_to?("technical")).to be true
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "path-based"`
Expected: FAIL. The mode-scoped file currently returns `config.modes.dup` (visible-everywhere default) instead of `["technical"]`.

- [ ] **Step 3: Implement path-based audience derivation**

Modify `app/models/markdowndocs/documentation.rb`. Replace the `audience` method:

```ruby
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
```

Add a private helper near `derive_path_slug`:

```ruby
def audience_from_path
  dir = file_path.dirname.basename.to_s
  Markdowndocs.config.modes.include?(dir) ? dir : nil
end
```

- [ ] **Step 4: Run tests, verify pass**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "path-based"`
Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "#visible_to?"`
Expected: PASS for both.

Then run the full Documentation spec:

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb`
Expected: All tests pass (including the pre-existing audience-frontmatter tests, which still work because frontmatter overrides path).

- [ ] **Step 5: Commit**

```bash
git add app/models/markdowndocs/documentation.rb \
        spec/models/markdowndocs/documentation_spec.rb
git commit -m "feat: derive Documentation#audience from parent directory when no frontmatter"
```

---

## Task 4: Documentation.find_by_slug resolves mode-scoped paths

**Files:**

- Modify: `app/models/markdowndocs/documentation.rb`
- Test: `spec/models/markdowndocs/documentation_spec.rb`

When `mode:` is non-nil, `find_by_slug` first looks for `docs/<mode>/<slug>.md` (the scoped file), then falls back to `docs/<slug>.md` (a shared file at root). With `mode: nil`, only the root is checked (matches v0.6.x semantics — used by search indexer / admin tools).

- [ ] **Step 1: Write failing tests**

Add to `spec/models/markdowndocs/documentation_spec.rb` inside the existing `describe ".find_by_slug"` block:

```ruby
context "with a mode subdirectory" do
  it "resolves to the mode-scoped file when mode is given and the file exists" do
    doc = described_class.find_by_slug("architecture", mode: "technical")
    expect(doc).not_to be_nil
    expect(doc.path_slug).to eq("technical/architecture")
  end

  it "falls back to the root file when no mode-scoped file exists" do
    # `welcome.md` is at root and has no `docs/technical/welcome.md`.
    doc = described_class.find_by_slug("welcome", mode: "technical")
    expect(doc).not_to be_nil
    expect(doc.path_slug).to eq("welcome")
  end

  it "returns nil when neither a mode-scoped nor a root file exists" do
    expect(described_class.find_by_slug("nonexistent", mode: "technical")).to be_nil
  end

  it "with mode: nil, only checks the root and ignores subdirectory files" do
    # `architecture` only exists at docs/technical/architecture.md, not root.
    expect(described_class.find_by_slug("architecture", mode: nil)).to be_nil
  end

  it "respects visible_to? on root fallback (audience:-deprecated root files)" do
    # admin-reference is at root with `audience: technical` frontmatter.
    expect(described_class.find_by_slug("admin-reference", mode: "guide")).to be_nil
    expect(described_class.find_by_slug("admin-reference", mode: "technical")).not_to be_nil
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "with a mode subdirectory"`
Expected: FAIL (the first test fails because `find_by_slug` builds `docs_path.join("architecture.md")` and that file doesn't exist at root).

- [ ] **Step 3: Implement mode-scoped resolution**

Modify `app/models/markdowndocs/documentation.rb`. Replace `self.find_by_slug`:

```ruby
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
```

- [ ] **Step 4: Run tests, verify pass**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "with a mode subdirectory"`
Expected: PASS for all five examples.

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/models/markdowndocs/documentation.rb \
        spec/models/markdowndocs/documentation_spec.rb
git commit -m "feat: find_by_slug resolves mode-scoped paths with root fallback"
```

---

## Task 5: assign_category matches path-prefixed slugs

**Files:**

- Modify: `app/models/markdowndocs/documentation.rb`
- Test: `spec/models/markdowndocs/documentation_spec.rb`

`config.categories` slugs now support a path prefix (`"technical/architecture"`). `assign_category` matches on `path_slug` instead of just `slug`, so bare entries (`"billing"`) match root files and prefixed entries (`"technical/architecture"`) match the scoped file.

- [ ] **Step 1: Write failing tests**

Add to `spec/models/markdowndocs/documentation_spec.rb` (new top-level describe block):

```ruby
describe "#category (path-prefixed slugs in config.categories)" do
  it "assigns the configured category to a root file via bare slug" do
    doc = described_class.find_by_slug("billing")
    expect(doc.category).to eq("Guides")
  end

  it "assigns the configured category to a mode-scoped file via path-prefixed slug" do
    doc = described_class.all.find { |d| d.path_slug == "technical/architecture" }
    expect(doc.category).to eq("Architecture")
  end

  it "assigns the configured category to a mode-scoped file with a same-named root sibling" do
    # Both docs/billing.md (Guides) and docs/technical/billing.md (Architecture) exist.
    root_billing = described_class.all.find { |d| d.path_slug == "billing" }
    scoped_billing = described_class.all.find { |d| d.path_slug == "technical/billing" }

    expect(root_billing.category).to eq("Guides")
    expect(scoped_billing.category).to eq("Architecture")
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "path-prefixed slugs"`
Expected: FAIL. The scoped billing assertion fails because `assign_category` matches `slug` (`"billing"`) against `config.categories["Architecture"]` which contains `"technical/billing"` — no match — so it returns `"Other"` instead of `"Architecture"`.

- [ ] **Step 3: Update assign_category to match on path_slug**

Modify `app/models/markdowndocs/documentation.rb`. Replace `assign_category`:

```ruby
def assign_category
  Markdowndocs.config.categories.each do |category, slugs|
    return category if slugs.include?(path_slug)
  end

  "Other"
end
```

This is a one-word change (`slug` → `path_slug`), but it's load-bearing.

- [ ] **Step 4: Run tests, verify pass**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "path-prefixed slugs"`
Expected: PASS.

Run the full Documentation spec:

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb`
Expected: All tests pass. Pre-existing categories tests still work because bare slugs (e.g., `"welcome"`) match a root file's `path_slug` (also `"welcome"`).

- [ ] **Step 5: Commit**

```bash
git add app/models/markdowndocs/documentation.rb \
        spec/models/markdowndocs/documentation_spec.rb
git commit -m "feat: config.categories supports path-prefixed slugs for mode-scoped docs"
```

---

## Task 6: Add `/:mode/:slug` route with regex constraint

**Files:**

- Modify: `config/routes.rb`
- Modify: `app/controllers/markdowndocs/docs_controller.rb`
- Test: `spec/requests/markdowndocs/docs_spec.rb`

A new route serves `/docs/:mode/:slug` where `:mode` is constrained to entries in `Markdowndocs.config.modes`. Both routes call `DocsController#show`, which reads `params[:mode]` and passes it through to `Documentation.find_by_slug`.

- [ ] **Step 1: Write failing request specs**

Add to `spec/requests/markdowndocs/docs_spec.rb` (inside the `RSpec.describe "Markdowndocs::Docs"` block):

```ruby
describe "GET /docs/:mode/:slug" do
  it "renders a mode-scoped document" do
    get "/docs/technical/architecture"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("System Architecture")
  end

  it "renders a mode-scoped doc independently of the current preference (URL determines content)" do
    get "/docs/technical/architecture", params: {mode: "guide"}
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("System Architecture")
  end

  it "returns 404 for an unknown mode segment" do
    get "/docs/notamode/architecture"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a mode-scoped slug that doesn't exist" do
    get "/docs/technical/nonexistent"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for directory traversal in slug" do
    get "/docs/technical/..%2F..%2Fetc%2Fpasswd"
    expect(response).to have_http_status(:not_found)
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "GET /docs/:mode/:slug"`
Expected: FAIL — all examples return 404 because no route matches `/docs/technical/architecture` (the existing `:slug` route doesn't accept two segments).

- [ ] **Step 3: Add the constrained route**

Modify `config/routes.rb`. Replace the file contents:

```ruby
# frozen_string_literal: true

Markdowndocs::Engine.routes.draw do
  root "docs#index"
  get "search_index", to: "docs#search_index", as: :search_index

  # Mode-scoped doc route: matches /<mode>/<slug> where <mode> is one of
  # the configured modes. Must come BEFORE the unconstrained :slug route
  # so the more specific match wins.
  mode_constraint = if Markdowndocs.config.modes.any?
    Regexp.new("\\A(?:#{Markdowndocs.config.modes.map { |m| Regexp.escape(m) }.join("|")})\\z")
  else
    /\Aimpossible\z/
  end
  get ":mode/:slug", to: "docs#show", as: :scoped_doc, constraints: {mode: mode_constraint}

  get ":slug", to: "docs#show", as: :doc
  resource :preference, only: [:update]
end
```

The `if Markdowndocs.config.modes.any?` guard prevents an empty alternation regex (which would match the empty string and produce unexpected routing). Hosts that empty their modes list disable scoped routing.

**Note on boot ordering:** The regex constraint is evaluated when the engine routes are drawn (at app boot). Hosts that set `config.modes` in `config/initializers/markdowndocs.rb` do so before route drawing — this is the typical and expected flow. Hosts that mutate `config.modes` after boot won't see their changes reflected in routes.

- [ ] **Step 4: Update the controller to pass `params[:mode]` through**

Modify `app/controllers/markdowndocs/docs_controller.rb`. The `show` method already references `@docs_mode` (the resolved current mode). With the new route, `params[:mode]` is now potentially the *path mode* (the subdirectory portion of the URL), distinct from the *current preference*. We need to look up the doc using the *path mode* when present, and fall back to `@docs_mode` (the preference) when the URL is unscoped.

Replace the `show` method:

```ruby
def show
  # `params[:mode]` here is the URL path segment (e.g. /docs/technical/foo → "technical")
  # if the request matched the scoped route. Otherwise, fall back to the resolved
  # current preference (@docs_mode) so root-mounted docs honor audience-frontmatter
  # filtering.
  lookup_mode = params[:mode].presence || @docs_mode
  @doc = Documentation.find_by_slug(params[:slug], mode: lookup_mode)

  if @doc.nil?
    render_not_found
    return
  end

  rendered_html = MarkdownRenderer.render(
    @doc.content,
    cache_key: @doc.cache_key,
    mode: @docs_mode
  )
  @rendered_content = helpers.add_heading_anchors(rendered_html)
  @related_docs = Documentation.by_category(@doc.category).reject { |d| d.slug == @doc.slug }
  @available_modes = @doc.available_modes
  @toc_items = helpers.generate_table_of_contents(@rendered_content)
end
```

**Important:** `set_docs_mode` (which builds `@docs_mode`) currently treats `params[:mode]` as a mode preference override. That breaks the moment `params[:mode]` carries a URL path segment. Update `determine_docs_mode` so it only treats `params[:mode]` as a preference when the request matched the unscoped route (i.e., when no `:slug` URL captured the mode).

Replace `determine_docs_mode`:

```ruby
def determine_docs_mode
  # Only treat params[:mode] as a preference override on the root-mounted
  # `/:slug` route. On the scoped `/:mode/:slug` route, params[:mode] is
  # the URL path segment and is consumed by `show` for doc lookup, not as
  # a preference override.
  preference_param = if path_mode_in_request?
    nil
  else
    params[:mode]
  end

  mode = preference_param ||
    resolve_user_mode ||
    cookies[:markdowndocs_mode] ||
    Markdowndocs.config.default_mode

  valid_modes = Markdowndocs.config.modes
  valid_modes.include?(mode) ? mode : Markdowndocs.config.default_mode
end

def path_mode_in_request?
  # The scoped route names `mode` as a path param. On the unscoped route,
  # `mode` (when present) comes from the query string.
  request.path_parameters[:mode].present?
end
```

- [ ] **Step 5: Run tests, verify pass**

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "GET /docs/:mode/:slug"`
Expected: PASS for all five examples.

Run the full request spec:

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb`
Expected: All tests pass, including the pre-existing "supports mode parameter" test (it passes `mode: "guide"` as a query param, which still works via the unscoped route).

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb \
        app/controllers/markdowndocs/docs_controller.rb \
        spec/requests/markdowndocs/docs_spec.rb
git commit -m "feat: add /docs/:mode/:slug route for path-based audience scoping"
```

---

## Task 7: PreferencesController computes smart-navigation target

**Files:**

- Create: `spec/requests/markdowndocs/preferences_spec.rb`
- Modify: `app/controllers/markdowndocs/preferences_controller.rb`

When the user submits a mode change, the controller computes the target URL using the unified lookup rule (target-mode-subdir file → root file → stay), and redirects there instead of `redirect_back`. The form must pass `current_path` as a hidden param (added in Task 8).

- [ ] **Step 1: Write failing request specs**

Create `spec/requests/markdowndocs/preferences_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Markdowndocs::Preferences", type: :request do
  describe "PATCH /docs/preference" do
    context "smart navigation" do
      it "redirects to /docs/<target>/<slug> when the scoped sibling exists" do
        # Sitting on shared /docs/billing, toggling to technical, technical/billing.md exists.
        patch "/docs/preference",
          params: {mode: "technical", current_path: "/docs/billing"}
        expect(response).to redirect_to("/docs/technical/billing")
      end

      it "redirects to /docs/<slug> (root) when toggling away from a mode-scoped doc whose shared sibling exists" do
        # Sitting on /docs/technical/billing, toggling to guide, docs/billing.md exists.
        patch "/docs/preference",
          params: {mode: "guide", current_path: "/docs/technical/billing"}
        expect(response).to redirect_to("/docs/billing")
      end

      it "stays on the current path when no sibling exists in the target mode and the current URL has no shared fallback" do
        # technical/architecture has no shared sibling.
        patch "/docs/preference",
          params: {mode: "guide", current_path: "/docs/technical/architecture"}
        expect(response).to redirect_to("/docs/technical/architecture")
      end

      it "stays on the current path when toggling and no scoped sibling exists for a shared doc" do
        # docs/welcome.md exists, but docs/technical/welcome.md does NOT.
        patch "/docs/preference",
          params: {mode: "technical", current_path: "/docs/welcome"}
        expect(response).to redirect_to("/docs/welcome")
      end

      it "stays on /docs (index) when current_path is the index" do
        patch "/docs/preference",
          params: {mode: "technical", current_path: "/docs"}
        expect(response).to redirect_to("/docs")
      end

      it "rejects an unknown mode with 422" do
        patch "/docs/preference",
          params: {mode: "notamode", current_path: "/docs/billing"}
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "persists the mode preference as a cookie" do
        patch "/docs/preference",
          params: {mode: "technical", current_path: "/docs/billing"}
        expect(cookies["markdowndocs_mode"]).to eq("technical")
      end

      it "falls back to /docs when current_path is missing" do
        # Backward-compat: forms from older deployments that don't pass current_path.
        patch "/docs/preference", params: {mode: "technical"}
        expect(response).to redirect_to("/docs")
      end
    end
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bundle exec rspec spec/requests/markdowndocs/preferences_spec.rb`
Expected: FAIL — current `redirect_back` does not honor `current_path`, and there's no smart-navigation logic.

- [ ] **Step 3: Implement smart-navigation in PreferencesController**

Replace the contents of `app/controllers/markdowndocs/preferences_controller.rb`:

```ruby
# frozen_string_literal: true

module Markdowndocs
  class PreferencesController < ApplicationController
    def update
      mode = params[:mode].to_s

      unless Markdowndocs.config.modes.include?(mode)
        head :unprocessable_entity
        return
      end

      saver = Markdowndocs.config.user_mode_saver
      if saver.respond_to?(:call)
        begin
          saver.call(self, mode)
        rescue => e
          Rails.logger.warn("Markdowndocs: user_mode_saver failed: #{e.message}")
        end
      end

      cookies[:markdowndocs_mode] = {
        value: mode,
        expires: 1.year.from_now,
        httponly: true
      }

      redirect_to(smart_nav_target(mode, params[:current_path]), status: :see_other)
    end

    private

    # Computes the post-toggle destination using the unified lookup rule:
    #   1. /docs/<target_mode>/<slug> if the scoped file exists and is not current
    #   2. /docs/<slug> (root) if it exists and is not current
    #   3. current path (stay put)
    # Falls back to the docs index when current_path is missing or doesn't
    # match a recognizable doc URL.
    def smart_nav_target(target_mode, current_path)
      index_path = markdowndocs.root_path
      return index_path if current_path.blank?

      slug = extract_slug_from_path(current_path)
      return current_path if slug.nil?

      docs_path = Markdowndocs.config.resolved_docs_path
      scoped_file = docs_path.join(target_mode, "#{slug}.md")
      root_file = docs_path.join("#{slug}.md")

      scoped_url = markdowndocs.scoped_doc_path(mode: target_mode, slug: slug)
      root_url = markdowndocs.doc_path(slug: slug)

      if scoped_file.exist? && current_path != scoped_url
        scoped_url
      elsif root_file.exist? && current_path != root_url
        root_url
      else
        current_path
      end
    end

    # Pulls the slug from a docs path. Returns nil if the path is the index
    # or doesn't match the docs URL shape. Recognizes both /docs/<slug> and
    # /docs/<mode>/<slug>.
    def extract_slug_from_path(path)
      # Strip query string and trailing slash.
      clean = path.split("?").first.to_s.chomp("/")
      base = markdowndocs.root_path.chomp("/")
      return nil unless clean.start_with?(base)

      remainder = clean[base.length..]
      return nil if remainder.blank? || remainder == "/"

      segments = remainder.sub(%r{\A/}, "").split("/")

      case segments.length
      when 1
        slug_candidate(segments.first)
      when 2
        # Could be /<mode>/<slug>. Only treat second segment as the slug
        # if the first is a configured mode.
        Markdowndocs.config.modes.include?(segments.first) ? slug_candidate(segments.last) : nil
      else
        nil
      end
    end

    def slug_candidate(segment)
      return nil if segment.blank?
      return nil if segment.include?("..") || segment.include?("/")
      segment
    end
  end
end
```

The `markdowndocs.root_path`, `markdowndocs.doc_path(slug:)`, and `markdowndocs.scoped_doc_path(mode:, slug:)` helpers are generated automatically from the engine routes added in Task 6 (`as: :doc` and `as: :scoped_doc`). Verify by running `bundle exec rails routes -g markdowndocs` if needed.

- [ ] **Step 4: Run tests, verify pass**

Run: `bundle exec rspec spec/requests/markdowndocs/preferences_spec.rb`
Expected: PASS for all eight examples.

Run the full request suite to catch regressions:

Run: `bundle exec rspec spec/requests`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/markdowndocs/preferences_controller.rb \
        spec/requests/markdowndocs/preferences_spec.rb
git commit -m "feat: PreferencesController does smart-navigation on mode toggle"
```

---

## Task 8: Mode switcher partial passes current_path

**Files:**

- Modify: `app/views/markdowndocs/docs/_mode_switcher.html.erb`
- Test: `spec/requests/markdowndocs/docs_spec.rb`

The mode switcher form must include `current_path` as a hidden field so the preferences controller can compute the smart-nav target. The value is `request.fullpath` (server-rendered, no JS required).

- [ ] **Step 1: Locate the form-builder block in the partial**

The partial at `app/views/markdowndocs/docs/_mode_switcher.html.erb` contains a per-mode `form_with` block. At time of writing (after the issue #20 fix in v0.6.1), the relevant chunk is at lines 37-43:

```erb
<%= form_with(
  url: markdowndocs.preference_path,
  method: :patch,
  data: {
    turbo_action: "replace"
  }
) do |f| %>
  <%= f.hidden_field :mode, value: mode %>
```

The new `current_path` hidden field goes immediately AFTER the `f.hidden_field :mode, ...` line — i.e., before the `<button type="submit">` that follows. If the line numbers have shifted since this plan was written, find the same anchor (`f.hidden_field :mode`) and insert immediately after.

- [ ] **Step 2: Write a failing test verifying the field is present**

Add to `spec/requests/markdowndocs/docs_spec.rb` (in the `describe "GET /docs/:slug"` block):

```ruby
it "renders the mode switcher with current_path as a hidden field" do
  get "/docs/welcome"
  expect(response.body).to include('name="current_path"')
  expect(response.body).to include('value="/docs/welcome"')
end

it "renders the mode switcher with current_path on a mode-scoped doc" do
  get "/docs/technical/architecture"
  expect(response.body).to include('name="current_path"')
  expect(response.body).to include('value="/docs/technical/architecture"')
end
```

- [ ] **Step 3: Run failing test**

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "current_path"`
Expected: FAIL — `current_path` field not yet present.

- [ ] **Step 4: Add the hidden field to the partial**

Open `app/views/markdowndocs/docs/_mode_switcher.html.erb` and find the `<%= form_with %>` (or `form_tag`) block that posts to the preferences endpoint. Inside it, add:

```erb
<%= hidden_field_tag :current_path, request.fullpath %>
```

Place it near the existing hidden mode/value fields. If the partial uses raw `<form>` HTML rather than Rails form helpers, add a corresponding `<input type="hidden" name="current_path" value="<%= request.fullpath %>">` line.

- [ ] **Step 5: Run tests, verify pass**

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "current_path"`
Expected: PASS.

Then run the full request spec:

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb`
Expected: All pass. The pre-existing duplicate-id test still passes (we did not add an id attribute).

- [ ] **Step 6: Commit**

```bash
git add app/views/markdowndocs/docs/_mode_switcher.html.erb \
        spec/requests/markdowndocs/docs_spec.rb
git commit -m "feat: mode switcher emits current_path for smart navigation"
```

---

## Task 9: Deprecate `audience:` frontmatter with a one-shot warning

**Files:**

- Modify: `lib/markdowndocs.rb` (add `deprecator` helper)
- Modify: `lib/markdowndocs/configuration.rb` (add `audience_deprecation_emitted` Set)
- Modify: `app/models/markdowndocs/documentation.rb` (emit warning when frontmatter `audience:` is present)
- Test: `spec/models/markdowndocs/documentation_spec.rb`

The warning fires once per file path per process boot. Tracking lives on `Markdowndocs.config` so `reset_configuration!` (called in test teardown) clears it between tests.

- [ ] **Step 1: Write failing tests**

Add to `spec/models/markdowndocs/documentation_spec.rb` (new top-level block):

```ruby
describe "audience: frontmatter deprecation" do
  before { Markdowndocs.reset_configuration! }

  it "emits a deprecation warning the first time a doc with audience: frontmatter is read" do
    warning_text = nil
    Markdowndocs.deprecator.behavior = ->(message, *) { warning_text = message }

    doc = described_class.find_by_slug("admin-reference", mode: "technical")
    doc.audience  # force evaluation

    expect(warning_text).to be_present
    expect(warning_text).to include("admin-reference.md")
    expect(warning_text).to include("audience:")
  end

  it "emits the warning at most once per file path" do
    call_count = 0
    Markdowndocs.deprecator.behavior = ->(_message, *) { call_count += 1 }

    3.times do
      doc = described_class.find_by_slug("admin-reference", mode: "technical")
      doc.audience
    end

    expect(call_count).to eq(1)
  end

  it "does NOT emit a warning for path-derived audience (no frontmatter)" do
    call_count = 0
    Markdowndocs.deprecator.behavior = ->(_message, *) { call_count += 1 }

    doc = described_class.find_by_slug("architecture", mode: "technical")
    doc.audience

    expect(call_count).to eq(0)
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "audience: frontmatter deprecation"`
Expected: FAIL — `Markdowndocs.deprecator` undefined.

- [ ] **Step 3: Add the deprecator and tracking Set**

Modify `lib/markdowndocs.rb`. Replace contents:

```ruby
# frozen_string_literal: true

require_relative "markdowndocs/version"
require_relative "markdowndocs/configuration"
require_relative "markdowndocs/engine"

module Markdowndocs
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    alias_method :config, :configuration

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Deprecation channel for the gem. Hosts can attach custom behaviors
    # (e.g., raise in test, silence in production) via:
    #   Markdowndocs.deprecator.behavior = :log
    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("1.0.0", "Markdowndocs")
    end
  end
end
```

Modify `lib/markdowndocs/configuration.rb`. Add `audience_deprecation_emitted` alongside the `non_mode_subdirs_warned` attribute added in Task 2. The full attribute set should look like:

```ruby
# frozen_string_literal: true

require "set"

module Markdowndocs
  class Configuration
    attr_accessor :docs_path, :categories, :modes, :default_mode,
      :markdown_options, :rouge_theme, :cache_expiry,
      :user_mode_resolver, :user_mode_saver, :search_enabled,
      :layout, :non_mode_subdirs_warned
    attr_reader :audience_deprecation_emitted

    def initialize
      @docs_path = nil
      @categories = {}
      @modes = %w[guide technical]
      @default_mode = "guide"
      @markdown_options = default_markdown_options
      @rouge_theme = "github"
      @cache_expiry = 1.hour
      @user_mode_resolver = nil
      @user_mode_saver = nil
      @search_enabled = false
      @layout = "markdowndocs/application"
      @non_mode_subdirs_warned = Set.new
      @audience_deprecation_emitted = Set.new
    end

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
```

- [ ] **Step 4: Emit the warning from Documentation#audience**

Modify `app/models/markdowndocs/documentation.rb`. Replace the `audience` method:

```ruby
def audience
  @audience ||= begin
    parsed = parse_frontmatter
    raw = parsed[:frontmatter]["audience"]

    if raw
      emit_audience_deprecation_warning_once
    end

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
```

Add the helper in the private section:

```ruby
def emit_audience_deprecation_warning_once
  path_str = file_path.to_s
  emitted = Markdowndocs.config.audience_deprecation_emitted
  return if emitted.include?(path_str)

  emitted << path_str

  suggested_target = suggest_migration_target
  Markdowndocs.deprecator.warn(
    "`audience:` frontmatter in #{path_str} is deprecated. " \
    "#{suggested_target} The `audience:` key will be removed in v1.0.0."
  )
end

def suggest_migration_target
  parsed = parse_frontmatter
  raw = parsed[:frontmatter]["audience"]

  case raw
  when String
    "Move the file to #{file_path.dirname.join(raw, file_path.basename)} instead and remove the `audience:` key."
  when Array
    if Array(raw).map(&:to_s).sort == Markdowndocs.config.modes.sort
      "This doc is already declared multi-audience; remove the `audience:` key (root files are visible in every mode)."
    else
      modes = Array(raw).map(&:to_s).join(", ")
      "This doc declares audience: [#{modes}]. Path-based routing supports only a single mode per file; either move the file to a single mode subdirectory or leave the file at root and remove `audience:` (root is shared)."
    end
  else
    "Move the file into the mode-named subdirectory matching its audience, or leave it at root and remove the key."
  end
end
```

- [ ] **Step 5: Run tests, verify pass**

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb -e "audience: frontmatter deprecation"`
Expected: PASS for all three examples.

Run the full Documentation spec:

Run: `bundle exec rspec spec/models/markdowndocs/documentation_spec.rb`
Expected: All pass. The pre-existing audience-frontmatter tests still pass (deprecation does not change behavior).

Run the full suite to confirm no regressions:

Run: `bundle exec rspec`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/markdowndocs.rb \
        lib/markdowndocs/configuration.rb \
        app/models/markdowndocs/documentation.rb \
        spec/models/markdowndocs/documentation_spec.rb
git commit -m "feat: deprecate audience: frontmatter in favor of path-based routing"
```

---

## Task 10: Update README with the new convention and migration guide

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Update the "Writing Documentation" section**

Open `README.md` and find the existing "Audience Filtering (whole-document)" subsection. Replace its contents with the new path-based convention. Mark the old frontmatter mechanism as deprecated.

Locate the "### Audience Filtering (whole-document)" heading and replace through (but not including) the "### Mode Blocks" heading with:

```markdown
### Audience Filtering by Filesystem Path

The recommended way to scope a whole document to a single audience is to
place it inside a subdirectory whose name matches an entry in
`config.modes`. Files at the docs root are *shared* — visible in every
mode.

```text
app/docs/
├── getting_started.md         → shared, visible in every mode
├── billing.md                 → shared
└── technical/
    ├── architecture.md        → technical mode only
    └── billing.md             → technical mode only
```

URLs follow the filesystem layout: `app/docs/billing.md` is served at
`/docs/billing`; `app/docs/technical/billing.md` is served at
`/docs/technical/billing`. Both URLs are stable and shareable.

Subdirectories whose name does not match a configured mode are ignored
by document discovery, with a one-line warning at boot.

### Audience Filtering by Frontmatter (deprecated)

The `audience:` frontmatter key from v0.6.0 still works in v0.7.x but is
deprecated. A warning is logged the first time each affected file is
read. Move the file into the matching mode subdirectory and remove the
`audience:` key. See the migration guide below.

```yaml
audience: technical          # deprecated — move to app/docs/technical/
audience: [guide, technical] # deprecated — keep at root, drop the key
# omit `audience:`           # still works for shared docs at root
```

The `audience:` key is scheduled for removal in v1.0.0.

```

Also update the categories example. Find the `config.categories =` block in the configuration section and update it:

```ruby
config.categories = {
  "Getting Started" => %w[welcome quickstart],
  "Guides" => %w[authentication billing],
  "Architecture" => %w[technical/architecture technical/billing]
}
```

Add a note immediately after the example:

> Bare slugs (e.g., `"welcome"`) match files at the docs root.
> Path-prefixed slugs (e.g., `"technical/architecture"`) match files
> inside the named mode subdirectory. The prefix segment must match
> an entry in `config.modes`.

- [ ] **Step 2: Add a "Migrating from v0.6.x" section**

Append before the final "## Contributing" section (or wherever the end of the body is) a new top-level section:

```markdown
## Migrating from v0.6.x to v0.7.0

**URL stability.** Every URL from v0.6.x continues to resolve. Hosts
that upgrade without moving files see zero URL changes. Path-based
routing only introduces *new* URLs (`/docs/<mode>/<slug>`) when you
explicitly relocate files into mode subdirectories.

### If you don't use `audience:` today

No action required. Adopt the new convention at your leisure.

### If you use `audience: <single-mode>`

For each affected doc:

```diff
- app/docs/foo.md
- ---
- audience: technical
- ---
+ app/docs/technical/foo.md
+ (no `audience:` key)
```

The deprecation warning surfaces the suggested target path.

### If you use `audience: [guide, technical]`

The doc is multi-audience — drop the key, the root file is shared:

```diff
  app/docs/foo.md
- ---
- audience: [guide, technical]
- ---
+ (no `audience:` key)
```

### `config.categories` for mode-scoped docs

Prefix slugs with the mode subdirectory:

```diff
  config.categories = {
-   "Architecture" => %w[architecture data_model]
+   "Architecture" => %w[technical/architecture data_model]
  }
```

Bare slugs continue to mean "the doc at the root with this name."
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README updates for path-based audience routing"
```

---

## Task 11: Add CHANGELOG entry for v0.7.0

**Files:**

- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add the new version section**

Open `CHANGELOG.md`. Insert a new section above the existing `## [0.6.1] - 2026-05-13` heading:

```markdown
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

```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog entry for v0.7.0"
```

---

## Task 12: Bump version to 0.7.0 and final verification

**Files:**

- Modify: `lib/markdowndocs/version.rb`

- [ ] **Step 1: Bump the version constant**

Open `lib/markdowndocs/version.rb`. Replace its contents:

```ruby
# frozen_string_literal: true

module Markdowndocs
  VERSION = "0.7.0"
end
```

- [ ] **Step 2: Run the full test suite and linter**

Run: `bundle exec rake`
Expected: RSpec passes (all green) and `standardrb` passes (no offenses). The default Rake task runs both.

If `standardrb` flags anything in the new code, fix it inline (typical issues: line length, single vs. double quotes per the project style). Re-run `bundle exec rake` until green.

- [ ] **Step 3: Commit the version bump**

```bash
git add lib/markdowndocs/version.rb
git commit -m "chore: bump version to 0.7.0"
```

- [ ] **Step 4: Final manual sanity check**

This step is **not** automated; run it as a human (or skip if the agent is running headless):

1. From the repo root, boot the dummy app and visit the docs in a browser.

```bash
cd spec/dummy && bin/rails server -p 3000 &
sleep 2
open http://localhost:3000/docs
```

2. Verify in the browser:
   - `/docs` shows the index with the configured categories. The "Architecture" category should appear when in technical mode and contain "System Architecture" and "Billing Internals".
   - `/docs/billing` shows the shared billing doc.
   - `/docs/technical/billing` shows the technical billing doc (different content).
   - Toggle the mode switcher from `/docs/billing` to technical — URL becomes `/docs/technical/billing`, content swaps.
   - Toggle back to guide — URL returns to `/docs/billing`.
   - Visit `/docs/technical/architecture`, toggle to guide — URL stays at `/docs/technical/architecture` (no shared sibling).
   - Visit `/docs/notamode/foo` — returns 404.

3. Stop the server: `kill %1` (or however you backgrounded it).

If anything visual looks off, capture the issue and either fix in a follow-up commit or roll back the version bump and address before tagging.

---

## Done

After Task 12, the v0.7.0 release is implementation-complete. The next step (outside this plan) is the gem release process — covered by the `.claude/skills/gem-release/` skill: tag, build, push to RubyGems. That's a separate operation and is not part of this plan.
