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

      it "sets a flash notice announcing the new mode for screen readers" do
        # Live-region announcement: the layout renders flash[:notice] inside
        # role=status aria-live=polite, which screen readers read on the
        # next page load. Without this, mode toggles are silent in SR.
        patch "/docs/preference",
          params: {mode: "technical", current_path: "/docs/billing"}
        follow_redirect!
        expect(response.body).to include('aria-live="polite"')
        expect(response.body).to include("Developer Guide")
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

      it "redirects to the docs index when current_path is an external URL (open-redirect protection)" do
        patch "/docs/preference",
          params: {mode: "guide", current_path: "https://evil.com/"}
        expect(response).to redirect_to("/docs")
      end

      it "redirects to the docs index when current_path is a protocol-relative URL (open-redirect protection)" do
        patch "/docs/preference",
          params: {mode: "guide", current_path: "//evil.com/"}
        expect(response).to redirect_to("/docs")
      end

      it "redirects to the docs index when current_path is outside the docs mount" do
        patch "/docs/preference",
          params: {mode: "guide", current_path: "/admin/secret"}
        expect(response).to redirect_to("/docs")
      end

      it "treats a symlinked-escape sibling file as nonexistent (would 404 if followed)" do
        # If app/docs/technical/foo.md is a symlink to a file OUTSIDE docs_path,
        # find_by_slug rejects it on the show action. Smart-nav must apply the
        # same reachability check, otherwise the redirect lands on a 404.
        Dir.mktmpdir do |docs_tmp|
          Dir.mktmpdir do |outside_tmp|
            outside_file = Pathname.new(outside_tmp).join("foo.md")
            outside_file.write("# Escaped\n")

            docs_path = Pathname.new(docs_tmp)
            docs_path.join("foo.md").write("# Shared\n")
            Dir.mkdir(docs_path.join("technical"))
            File.symlink(outside_file.to_s, docs_path.join("technical", "foo.md").to_s)

            Markdowndocs.config.docs_path = docs_path

            patch "/docs/preference",
              params: {mode: "technical", current_path: "/docs/foo"}

            # Should NOT redirect to the escaped scoped URL (which 404s).
            expect(response).not_to redirect_to("/docs/technical/foo")
            # Should stay on the shared root path.
            expect(response).to redirect_to("/docs/foo")
          end
        end
      end
    end
  end
end
