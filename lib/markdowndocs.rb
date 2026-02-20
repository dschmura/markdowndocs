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
  end
end
