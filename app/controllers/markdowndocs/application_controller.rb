# frozen_string_literal: true

module Markdowndocs
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    # Use the engine's own layout to avoid route helper conflicts.
    # Host apps that shared their application layout with the engine
    # would see route helpers (about_path, signout_path, etc.) resolve
    # against the engine's namespace instead of the main app.
    #
    # Host apps can customize by overriding this layout at:
    #   app/views/layouts/markdowndocs/application.html.erb
    #
    # The layout provides content_for blocks:
    #   :docs_header — rendered above main content (for nav/header)
    #   :docs_footer — rendered below main content (for footer)
    #   :head        — injected into <head> (for extra stylesheets/scripts)
    #   :title       — page title (defaults to "Documentation")
    layout -> { Markdowndocs.config.layout }

    # Support Rails 8 built-in authentication (allow_unauthenticated_access)
    # without requiring it — works with any auth system or none at all
    if respond_to?(:allow_unauthenticated_access)
      allow_unauthenticated_access
    end

    # Resume session if the host app supports it (Rails 8 auth)
    before_action :resume_session, if: -> { respond_to?(:resume_session, true) }
  end
end
