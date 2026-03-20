# frozen_string_literal: true

module Markdowndocs
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    # Fix route helper isolation caused by isolate_namespace.
    #
    # The problem: host app route helpers (about_path, contact_path, etc.)
    # exist in the view context but resolve against the engine's namespace,
    # so about_path returns "/docs/about" instead of "/about".
    #
    # method_missing doesn't help because the methods already exist —
    # they just resolve wrong. We need to override them explicitly.
    #
    # This before_action builds a helper module on first request (when
    # routes are fully loaded) that defines every host app route helper
    # as a delegation to main_app.
    before_action :ensure_host_route_helpers

    # Support Rails 8 built-in authentication (allow_unauthenticated_access)
    # without requiring it — works with any auth system or none at all
    if respond_to?(:allow_unauthenticated_access)
      allow_unauthenticated_access
    end

    # Resume session if the host app supports it (Rails 8 auth)
    before_action :resume_session, if: -> { respond_to?(:resume_session, true) }

    private

    def ensure_host_route_helpers
      return if self.class.instance_variable_get(:@host_routes_delegated)

      helper_module = Module.new do
        Rails.application.routes.named_routes.names.each do |name|
          define_method(:"#{name}_path") { |*args, **kwargs| main_app.send(:"#{name}_path", *args, **kwargs) }
          define_method(:"#{name}_url") { |*args, **kwargs| main_app.send(:"#{name}_url", *args, **kwargs) }
        end
      end

      self.class.helper(helper_module)
      self.class.instance_variable_set(:@host_routes_delegated, true)
    end
  end
end
