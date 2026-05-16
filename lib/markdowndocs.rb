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
