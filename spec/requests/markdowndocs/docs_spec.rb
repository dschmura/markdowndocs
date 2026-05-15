# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Markdowndocs::Docs", type: :request do
  let(:engine_routes) { Markdowndocs::Engine.routes.url_helpers }

  describe "GET /docs" do
    it "renders the index page" do
      get "/docs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Documentation")
    end

    it "lists categorized documents" do
      get "/docs"
      expect(response.body).to include("Getting Started")
      expect(response.body).to include("Welcome")
      expect(response.body).to include("Quickstart Guide")
    end

    it "renders mode-scoped docs in their configured categories when in technical mode" do
      get "/docs", params: {mode: "technical"}
      expect(response.body).to include("Architecture")
      expect(response.body).to include("System Architecture")
      expect(response.body).to include("Billing Internals")
    end

    it "drops the Architecture category in guide mode (no visible docs)" do
      get "/docs", params: {mode: "guide"}
      expect(response.body).not_to include("Architecture")
    end
  end

  describe "GET /docs/:slug" do
    it "renders a documentation page" do
      get "/docs/welcome"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Welcome")
    end

    it "renders markdown content as HTML" do
      get "/docs/quickstart"
      expect(response.body).to include("Installation")
    end

    it "returns 404 for nonexistent slug" do
      get "/docs/nonexistent"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for directory traversal attempts" do
      get "/docs/..%2F..%2Fetc%2Fpasswd"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for invalid slug characters" do
      get "/docs/foo%3Cscript%3E"
      expect(response).to have_http_status(:not_found)
    end

    it "supports mode parameter" do
      get "/docs/welcome", params: {mode: "guide"}
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("step-by-step")
      expect(response.body).not_to include("gem install")
    end

    # Issue #20 (WCAG 4.1.1): show.html.erb renders _navigation twice (mobile +
    # desktop sidebars), which embeds _mode_switcher twice. The switcher must
    # not declare a hardcoded id — Stimulus already scopes itself via
    # data-controller="docs-mode", which can appear N times without colliding.
    it "does not emit duplicate id=\"docs-mode-switcher\" in the rendered HTML" do
      get "/docs/welcome"
      duplicate_count = response.body.scan('id="docs-mode-switcher"').length
      expect(duplicate_count).to eq(0),
        "show page must not emit any id=\"docs-mode-switcher\" — Stimulus's data-controller is the unique-scoping mechanism, and the partial renders twice (mobile + desktop sidebars)"

      # Sanity: the switcher IS in the DOM, just identified by data-controller.
      controller_count = response.body.scan('data-controller="docs-mode"').length
      expect(controller_count).to eq(2),
        "expected two docs-mode controller instances (mobile + desktop sidebars)"
    end

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
  end

  describe "GET /docs/search_index" do
    context "when search is disabled" do
      before { Markdowndocs.config.search_enabled = false }

      it "returns 404" do
        get "/docs/search_index"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when search is enabled" do
      before { Markdowndocs.config.search_enabled = true }
      after { Markdowndocs.config.search_enabled = false }

      it "returns JSON" do
        get "/docs/search_index"
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")
      end

      it "includes document data" do
        get "/docs/search_index"
        json = JSON.parse(response.body)
        slugs = json.map { |d| d["id"] }
        expect(slugs).to include("welcome")
        expect(slugs).to include("quickstart")
      end

      it "includes all search fields" do
        get "/docs/search_index"
        json = JSON.parse(response.body)
        doc = json.find { |d| d["id"] == "welcome" }
        expect(doc).to have_key("title")
        expect(doc).to have_key("description")
        expect(doc).to have_key("content")
        expect(doc).to have_key("keywords")
        expect(doc).to have_key("code")
      end

      it "includes code block content" do
        get "/docs/search_index"
        json = JSON.parse(response.body)
        doc = json.find { |d| d["id"] == "quickstart" }
        expect(doc["code"]).to include("markdowndocs")
      end

      it "includes keywords as space-separated string" do
        get "/docs/search_index"
        json = JSON.parse(response.body)
        doc = json.find { |d| d["id"] == "authentication" }
        expect(doc["keywords"]).to eq("login signin password session")
      end
    end
  end

  describe "PATCH /docs/preference" do
    it "sets mode cookie and redirects" do
      patch "/docs/preference", params: {mode: "technical"}, headers: {"HTTP_REFERER" => "/docs"}
      expect(response).to have_http_status(:see_other)
      expect(cookies[:markdowndocs_mode]).to eq("technical")
    end

    it "rejects invalid modes" do
      patch "/docs/preference", params: {mode: "invalid"}
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

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

  # Audience-frontmatter filtering: docs declare `audience:` in their
  # frontmatter and the controller honors it via Documentation's mode:
  # kwarg on both .grouped_by_category (index) and .find_by_slug (show).
  describe "audience filtering" do
    describe "GET /docs?mode=guide" do
      it "hides technical-only docs from the index" do
        get "/docs", params: {mode: "guide"}
        expect(response.body).not_to include("Admin Reference")
      end

      it "drops empty categories from the index" do
        get "/docs", params: {mode: "guide"}
        expect(response.body).not_to include("Administrator Reference")
      end
    end

    describe "GET /docs?mode=technical" do
      it "shows technical-only docs in the index" do
        get "/docs", params: {mode: "technical"}
        expect(response.body).to include("Admin Reference")
      end
    end

    describe "GET /docs/:slug honors the audience filter" do
      it "404s a technical-only doc when mode is guide" do
        get "/docs/admin-reference", params: {mode: "guide"}
        expect(response).to have_http_status(:not_found)
      end

      it "renders a technical-only doc when mode is technical" do
        get "/docs/admin-reference", params: {mode: "technical"}
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Admin Reference")
      end

      it "renders a multi-audience doc in either mode" do
        get "/docs/welcome", params: {mode: "guide"}
        expect(response).to have_http_status(:ok)

        get "/docs/welcome", params: {mode: "technical"}
        expect(response).to have_http_status(:ok)
      end

      it "renders an audience-unset doc in either mode (backward compat)" do
        # quickstart.md has no `audience:` key.
        get "/docs/quickstart", params: {mode: "guide"}
        expect(response).to have_http_status(:ok)

        get "/docs/quickstart", params: {mode: "technical"}
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
