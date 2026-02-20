# frozen_string_literal: true

module Markdowndocs
  class Engine < ::Rails::Engine
    isolate_namespace Markdowndocs

    initializer "markdowndocs.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/assets/javascripts")
      end
    end

    initializer "markdowndocs.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb") if root.join("config/importmap.rb").exist?
      end
    end
  end
end
