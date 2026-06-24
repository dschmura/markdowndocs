# Persistent docs audience switcher — Design

**Date:** 2026-06-23
**Repo:** markdowndocs (gem)
**Branch:** `fix/mode-switcher-a11y` (folds the in-flight a11y fix + the new persistent placement into one feature)

## Goal

Make the audience-mode switcher (e.g. User ⇄ Developer) **persistent**: always visible, in one consistent location, on the docs **landing/index** *and* every doc **show** page — styled like a light/dark toggle. Switching must stay on the current **topic** (load the target audience's version of the same doc), not bounce to the index.

## Context / current state

- **Topic-preserving switch already exists.** `PreferencesController#smart_nav_target` resolves the post-switch destination: scoped sibling (`/docs/<target_mode>/<slug>`) if it exists → else root sibling → else *stay put* → else docs index (only when `current_path` is blank/unrecognized). The switcher form already submits `current_path: request.fullpath`. So a 1:1 pair like `notifications` (`user/notifications` ↔ `developer/notifications`) already stays on topic today.
- **The switcher is mounted show-only.** It renders inside `_navigation` (the show-page sidebar), which `show.html.erb` renders **twice** (mobile + desktop), so the partial had to drop its element `id` to avoid duplicate-id WCAG violations. The **index renders no switcher at all** — the gap this feature closes.
- **In-flight a11y fix (uncommitted on this branch), folded in as the base:** `_mode_switcher` converted from `role="radiogroup"`/`role="radio"`/`aria-checked` (implied arrow-key radio behavior the UI doesn't implement) to a `role="group"` of `aria-pressed` toggle buttons; `docs_mode_controller.js` gained focus-restore (`rememberFocus`) so focus returns to the chosen button across the Turbo `replace`; request specs assert the new semantics. Plus `.tool-versions`/`mise.toml`/`.gitignore`.
- **Host apps override the gem layout.** modelrails_base's `layouts/markdowndocs/application.html.erb` renders its own `shared/header`/`shared/footer` and ignores `yield :docs_header`. So a layout-mounted switcher would not reach overriding hosts — placement must be in the views, not the layout.

## Design

### 1. A shared toolbar partial rendered by both views
New partial `markdowndocs/docs/_docs_toolbar` renders a slim bar at the top of the docs content area carrying the switcher (right-aligned). It is rendered as the first element inside **both** `index.html.erb` and `show.html.erb`. The switcher is **removed** from `_navigation` (the sidebar), giving exactly one instance per page (so it can carry a proper `id`/labelled control again).

### 2. Switcher reshaped to a horizontal segmented control
`_mode_switcher` becomes a compact horizontal control (light/dark style) instead of a vertical sidebar card. It **preserves** all behavior from the folded-in a11y fix: one `form_with` per mode (`method: :patch` → `preference_path`), `current_path: request.fullpath` (so `smart_nav_target` preserves topic), `role="group"` + `aria-label`, `aria-pressed` per button, and the `docs-mode` Stimulus controller (focus restore). Gem default uses the gem's existing raw-Tailwind styling; downstream hosts override with their own tokens.

### 3. Controller wiring
`DocsController#index` must expose what the toolbar needs: `current_mode` (already `@docs_mode`) and `available_modes`. Today only `#show` sets `@available_modes` (from `@doc`); set it on `#index` from `Markdowndocs.config.modes`. No change to `smart_nav_target` or the switch flow. When only one mode is configured, the toolbar renders no switcher (existing `available_modes.length > 1` guard).

### 4. Split topics
Per decision: **convention, not mechanism.** Topics that deserve both audiences are authored as 1:1 counterparts (same slug under each mode dir); the existing scoped-sibling logic then keeps the switch on-topic. Genuinely single-audience docs simply have no counterpart and fall back to "stay put." **No new gem mechanism** (no frontmatter counterpart pointer). Authoring specific counterparts (e.g. a `developer/authentication`) is downstream host content work, out of scope here.

## Testing
- Request/system specs: the switcher renders on **the index** and on a **show** page; switching from the index lands on the index in the new mode; `smart_nav_target` topic-preservation still holds for a 1:1 pair; the sidebar no longer renders a second switcher.
- A11y: single labelled `role="group"`, `aria-pressed` reflects current mode, focus restored after switch (the folded-in a11y specs continue to pass against the relocated control).
- Host adoption re-verifies AAA in CI (gem CI is AA/structural; host CI is the AAA gate).

## Scope & sequencing
- **One gem PR** on `fix/mode-switcher-a11y`: commit the a11y fix (verify gem tests green first), add `_docs_toolbar`, reshape `_mode_switcher` to horizontal, render the toolbar in `index`/`show`, drop the sidebar switcher, wire `index` `available_modes`, specs.
- → **user releases** the gem to RubyGems (their credential).
- → **host app adopts**: re-pin, mirror the toolbar into its `index`/`show` overrides with semantic tokens, drop the sidebar switcher from its `_navigation` override, slim its `_mode_switcher` override to the horizontal form; AAA-verify in CI. Host's overridden docs views net shrink.

## Out of scope (separate follow-ups)
- Authoring 1:1 counterpart docs in the host (content).
- Bare-slug cross-mode URL fallback (so old `/docs/<slug>` resolve cross-mode instead of 404).
- Audience-filtering the "Related Documentation" sidebar.
