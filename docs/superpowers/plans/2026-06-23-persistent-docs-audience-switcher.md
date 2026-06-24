# Persistent docs audience switcher — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the audience-mode switcher persistent — one instance in a top toolbar on both the docs index and every doc page — folding in the in-flight a11y fix as the base.

**Architecture:** A new `_docs_toolbar` partial renders the (reshaped, horizontal) `_mode_switcher` at the top of both `index.html.erb` and `show.html.erb`. The switcher is removed from the show-page `_navigation` sidebar (it rendered there twice). `DocsController#index` gains `@available_modes`. The topic-preserving switch (`smart_nav_target` + `current_path`) is unchanged.

**Tech Stack:** Rails engine (markdowndocs gem), ERB + Tailwind, Stimulus (`docs-mode` controller), RSpec request specs.

## Global Constraints

- **Branch:** `fix/mode-switcher-a11y` (already checked out; holds the uncommitted a11y WIP).
- **Gem test modes are `guide`/`technical`** (the dummy app's `config.modes`) — NOT `user`/`developer`. All test code uses `guide`/`technical` and the dummy fixtures (`welcome`, `quickstart`, `architecture`, `technical/architecture`, `billing`, `admin-reference`).
- **Preserve switcher a11y semantics:** `role="group"` + `aria-label`, `aria-pressed` per button (NOT radiogroup/radio/aria-checked), hidden `current_path: request.fullpath`, `data-controller="docs-mode"` + `data-action="click->docs-mode#rememberFocus"`, and `id: nil` on hidden fields (no duplicate ids).
- **One switcher instance per page** after this work (toolbar), not two (sidebars).
- Run the suite with `bundle exec rspec`. Don't bypass any git hooks.
- AAA contrast is the *host's* CI gate; the gem keeps its existing raw-Tailwind styling.

---

### Task 1: Commit the folded-in a11y fix (the base)

**Files (already modified, uncommitted):**
- `app/views/markdowndocs/docs/_mode_switcher.html.erb` (radiogroup→aria-pressed)
- `app/assets/javascripts/markdowndocs/controllers/docs_mode_controller.js` (+rememberFocus)
- `spec/requests/markdowndocs/docs_spec.rb`, `spec/requests/markdowndocs/preferences_spec.rb` (a11y assertions)
- `.gitignore`, `.tool-versions`, `mise.toml` (tooling)

- [ ] **Step 1: Run the full suite to confirm the WIP is green**

Run: `bundle exec rspec`
Expected: 0 failures (the WIP added the aria-pressed/current_path/rememberFocus assertions and the impl that satisfies them).

- [ ] **Step 2: Commit the a11y fix (code + specs)**

```bash
git add app/views/markdowndocs/docs/_mode_switcher.html.erb \
        app/assets/javascripts/markdowndocs/controllers/docs_mode_controller.js \
        spec/requests/markdowndocs/docs_spec.rb \
        spec/requests/markdowndocs/preferences_spec.rb
git commit -m "fix(a11y): mode switcher uses aria-pressed toggle group + focus restore"
```

- [ ] **Step 3: Commit the tooling files separately**

```bash
git add .gitignore .tool-versions mise.toml
git commit -m "chore: pin Ruby via .tool-versions/mise + gitignore updates"
```

---

### Task 2: Persistent switcher on the index (reshape + toolbar + controller)

**Files:**
- Modify: `app/views/markdowndocs/docs/_mode_switcher.html.erb` (vertical card → horizontal)
- Create: `app/views/markdowndocs/docs/_docs_toolbar.html.erb`
- Modify: `app/controllers/markdowndocs/docs_controller.rb` (`#index` sets `@available_modes`)
- Modify: `app/views/markdowndocs/docs/index.html.erb` (render the toolbar at top)
- Test: `spec/requests/markdowndocs/docs_spec.rb`

**Interfaces:**
- Produces: `_docs_toolbar` partial — locals `(current_mode:, available_modes:)`; renders the switcher when `available_modes.length > 1`, else nothing.
- Produces: `@available_modes` on the index action (= `Markdowndocs.config.modes`).

- [ ] **Step 1: Write failing index-switcher specs**

Add to `spec/requests/markdowndocs/docs_spec.rb` inside `describe "GET /docs"`:

```ruby
    it "renders the audience switcher on the index" do
      get "/docs"
      expect(response.body).to include('data-controller="docs-mode"')
      expect(response.body).to include('role="group"')
      expect(response.body).to include("aria-pressed=")
    end

    it "renders the switcher exactly once on the index" do
      get "/docs"
      expect(response.body.scan('data-controller="docs-mode"').length).to eq(1)
    end

    it "the index switcher carries current_path for topic-preserving switch" do
      get "/docs"
      expect(response.body).to include('name="current_path"')
      expect(response.body).to include('value="/docs"')
    end
```

- [ ] **Step 2: Run them — Expected: FAIL** (the index renders no switcher yet)

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "audience switcher on the index"`
Expected: FAIL (no `data-controller="docs-mode"` in the index body).

- [ ] **Step 3: Reshape `_mode_switcher.html.erb` to horizontal**

Replace the file with (horizontal layout; same a11y semantics; per-button description dropped for the compact header form):

```erb
<%# locals: (current_mode:, available_modes:) %>
<%# Horizontal audience toggle for the docs toolbar (rendered once per page).
    Toggle-button group, NOT a radiogroup: each option is its own form +
    submit button, so aria-pressed describes state. No element id — tests
    target [data-controller="docs-mode"]. %>
<div
  class="flex items-center gap-2"
  data-controller="docs-mode"
  data-docs-mode-current-value="<%= current_mode %>"
>
  <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
    <%= t("markdowndocs.viewing_mode") %>
  </span>
  <div class="inline-flex gap-1" role="group" aria-label="<%= t('markdowndocs.select_viewing_mode') %>">
    <% available_modes.each do |mode| %>
      <%= form_with(url: markdowndocs.preference_path, method: :patch, data: {turbo_action: "replace"}) do |f| %>
        <%= f.hidden_field :mode, value: mode, id: nil %>
        <%= f.hidden_field :current_path, value: request.fullpath, id: nil %>
        <button
          type="submit"
          aria-pressed="<%= current_mode == mode %>"
          data-mode="<%= mode %>"
          data-action="click->docs-mode#rememberFocus"
          class="px-3 py-1.5 text-sm font-medium rounded-md border transition-colors <%= (current_mode == mode) ? 'border-cyan-500 bg-cyan-50 text-cyan-900 dark:bg-cyan-900/40 dark:border-cyan-400 dark:text-cyan-100' : 'border-slate-200 text-slate-700 hover:bg-slate-50 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-700' %>"
        >
          <%= t("markdowndocs.modes.#{mode}", default: mode.titleize) %>
        </button>
      <% end %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Create `app/views/markdowndocs/docs/_docs_toolbar.html.erb`**

```erb
<%# locals: (current_mode:, available_modes:) %>
<%# Persistent docs toolbar: the audience switcher, shown at the top of both
    the index and every doc page. Renders nothing when only one mode exists. %>
<% if available_modes.length > 1 %>
  <div class="flex justify-end mb-6">
    <%= render "markdowndocs/docs/mode_switcher",
      current_mode: current_mode,
      available_modes: available_modes %>
  </div>
<% end %>
```

- [ ] **Step 5: Set `@available_modes` on `#index`**

In `app/controllers/markdowndocs/docs_controller.rb`, `#index` becomes:

```ruby
    def index
      @docs_by_category = Documentation.grouped_by_category(mode: @docs_mode)
      @search_enabled = Markdowndocs.config.search_enabled
      @available_modes = Markdowndocs.config.modes
    end
```

- [ ] **Step 6: Render the toolbar at the top of the index**

In `app/views/markdowndocs/docs/index.html.erb`, immediately after the inner container's opening `>` (the `data-controller="docs-search"` div) and before `<!-- Hero Section -->`, add:

```erb
    <%= render "markdowndocs/docs/docs_toolbar",
      current_mode: @docs_mode,
      available_modes: @available_modes %>
```

- [ ] **Step 7: Run the index specs — Expected: PASS**

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "GET /docs"`
Expected: the three new examples pass (switcher present, once, with `current_path` = `/docs`); the existing index examples still pass.

- [ ] **Step 8: Commit**

```bash
git add app/views/markdowndocs/docs/_mode_switcher.html.erb \
        app/views/markdowndocs/docs/_docs_toolbar.html.erb \
        app/controllers/markdowndocs/docs_controller.rb \
        app/views/markdowndocs/docs/index.html.erb \
        spec/requests/markdowndocs/docs_spec.rb
git commit -m "feat(docs): persistent audience switcher in a toolbar on the index"
```

---

### Task 3: Relocate the switcher on show pages (toolbar, not sidebar)

**Files:**
- Modify: `app/controllers/markdowndocs/docs_controller.rb` (`#show` sets `@available_modes` from config, not the doc)
- Modify: `app/views/markdowndocs/docs/show.html.erb` (render toolbar after breadcrumb; stop passing switcher locals to `_navigation`)
- Modify: `app/views/markdowndocs/docs/_navigation.html.erb` (remove the switcher block)
- Test: `spec/requests/markdowndocs/docs_spec.rb` (update the count assertion 2 → 1)

**Interfaces:**
- Consumes: `_docs_toolbar` (from Task 2). After this task, `_navigation` no longer renders the switcher and no longer needs `current_mode`/`available_modes`.
- Note: `#show` currently sets `@available_modes = @doc.available_modes` (the doc's own modes — used only by the sidebar switcher being removed). The persistent toggle must always offer all configured modes (the audience choice is independent of the current doc; `smart_nav_target` decides where the switch lands), so change it to `Markdowndocs.config.modes`, matching `#index`.

- [ ] **Step 1: Update the existing show-page count spec (it currently asserts 2)**

In `spec/requests/markdowndocs/docs_spec.rb`, the example "does not emit duplicate id ..." asserts `data-controller="docs-mode"` count `== 2` (mobile + desktop sidebars). After relocation the switcher renders once (toolbar). Replace that block's controller-count assertion with:

```ruby
    it "renders the audience switcher exactly once on a show page (toolbar, not duplicated in sidebars)" do
      get "/docs/welcome"
      expect(response.body.scan('data-controller="docs-mode"').length).to eq(1),
        "switcher now lives in the single top toolbar, not in both mobile + desktop sidebars"
    end
```

Keep the existing `aria-pressed`/`current_path`/`role="group"` show examples as-is — they still hold (the switcher is now in the toolbar, `current_path` is `/docs/welcome`).

- [ ] **Step 2: Run it — Expected: FAIL** (still 2: the sidebar renders the switcher twice)

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "exactly once on a show page"`
Expected: FAIL (count is 2).

- [ ] **Step 3: Remove the switcher block from `_navigation.html.erb`**

Delete lines 1–7's switcher render and update the locals comment. The file's top becomes:

```erb
<%# locals: (rendered_content:, related_docs:, toc_items:) %>
<aside class="sidebar space-y-6">
  <% if toc_items.length >= 3 %>
```

(Everything from the `toc_items` block down is unchanged.)

- [ ] **Step 4: Point `#show`'s `@available_modes` at the configured modes**

In `app/controllers/markdowndocs/docs_controller.rb`, change the `#show` line `@available_modes = @doc.available_modes` to:

```ruby
      @available_modes = Markdowndocs.config.modes
```

(So the show toolbar offers the same audience choices as the index; the switch destination is decided by `smart_nav_target`, not by which modes the current doc happens to exist in.)

- [ ] **Step 5: Render the toolbar on show + drop switcher locals from `_navigation` renders**

In `app/views/markdowndocs/docs/show.html.erb`, immediately after the breadcrumb render (`<%= render "markdowndocs/docs/breadcrumb", ... %>`), add:

```erb
    <%= render "markdowndocs/docs/docs_toolbar",
      current_mode: @docs_mode,
      available_modes: @available_modes %>
```

And in BOTH `_navigation` renders (the mobile `#mobile-sidebar` one and the desktop one), remove the now-unused `current_mode:` and `available_modes:` locals so each reads:

```erb
        <%= render "markdowndocs/docs/navigation",
          rendered_content: @rendered_content,
          related_docs: @related_docs,
          toc_items: @toc_items %>
```

- [ ] **Step 6: Run the show specs — Expected: PASS**

Run: `bundle exec rspec spec/requests/markdowndocs/docs_spec.rb -e "GET /docs/:slug"`
Expected: the count example passes (1), and the aria-pressed/current_path/title/autofocus examples still pass.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/markdowndocs/docs_controller.rb \
        app/views/markdowndocs/docs/show.html.erb \
        app/views/markdowndocs/docs/_navigation.html.erb \
        spec/requests/markdowndocs/docs_spec.rb
git commit -m "feat(docs): move audience switcher from sidebar to persistent toolbar on show"
```

---

### Task 4: Full verification + finish

- [ ] **Step 1: Full suite** — `bundle exec rspec` → 0 failures. (Confirms `preferences_spec` smart_nav/topic-preserving still passes, and no other spec regressed.)
- [ ] **Step 2: Manual render sanity** — start the dummy app if available (`bin/rails s` in `spec/dummy` or the gem's dev server) and confirm `/docs` and `/docs/welcome` both show one switcher at the top; switching `guide`⇄`technical` from `/docs/welcome` stays on `welcome` when a sibling exists, and the index reflects the new mode. (If no runnable dummy server, rely on the request specs.)
- [ ] **Step 3: Finish** — Use superpowers:finishing-a-development-branch (push `fix/mode-switcher-a11y` + open the gem PR). The PR covers: a11y fix + persistent toolbar switcher. Note in the PR body that host adoption (modelrails_base) follows after release.
