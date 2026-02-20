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
end
