# frozen_string_literal: true

module Markdowndocs
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    # Support Rails 8 built-in authentication (allow_unauthenticated_access)
    # without requiring it — works with any auth system or none at all
    if respond_to?(:allow_unauthenticated_access)
      allow_unauthenticated_access
    end

    # Resume session if the host app supports it (Rails 8 auth)
    before_action :resume_session, if: -> { respond_to?(:resume_session, true) }
  end
end
