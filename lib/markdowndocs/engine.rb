# frozen_string_literal: true

module Markdowndocs
  class Engine < ::Rails::Engine
    isolate_namespace Markdowndocs

    initializer "markdowndocs.i18n" do
      config.i18n.load_path += Dir[root.join("config/locales/**/*.yml")]
    end

    initializer "markdowndocs.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/assets/javascripts")
      end
    end

    initializer "markdowndocs.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end

    initializer "markdowndocs.stimulus" do
      Rails.application.config.after_initialize do
        if defined?(Importmap)
          # The pin is already added via importmap.rb
          # Host app just needs: import "markdowndocs" in their application.js
        end
      end
    end
  end
end
