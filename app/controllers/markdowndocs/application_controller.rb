# frozen_string_literal: true

module Markdowndocs
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    # Delegate unresolved route helpers to the host app via main_app.
    # isolate_namespace blocks host helpers by default, and the commonly-used
    # `helper Rails.application.routes.url_helpers` doesn't reliably win the
    # method-lookup race — so host-app links like about_path can resolve
    # against the engine's catch-all :slug route instead.  This delegation
    # ensures host app route helpers always work correctly in engine views.
    helper do
      # Explicitly delegate root_path/root_url to the host app.
      # The engine defines its own root route, so these helpers exist in the
      # engine scope and method_missing won't intercept them — but they resolve
      # to /docs/ instead of /. Engine views use markdowndocs.root_path directly.
      def root_path(*args)
        main_app.root_path(*args)
      end

      def root_url(*args)
        main_app.root_url(*args)
      end

      def method_missing(method, *args, &block)
        if main_app.respond_to?(method)
          main_app.send(method, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        main_app.respond_to?(method, include_private) || super
      end
    end

    # Support Rails 8 built-in authentication (allow_unauthenticated_access)
    # without requiring it — works with any auth system or none at all
    if respond_to?(:allow_unauthenticated_access)
      allow_unauthenticated_access
    end

    # Resume session if the host app supports it (Rails 8 auth)
    before_action :resume_session, if: -> { respond_to?(:resume_session, true) }
  end
end
