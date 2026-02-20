# frozen_string_literal: true

module Markdowndocs
  class Engine < ::Rails::Engine
    isolate_namespace Markdowndocs

    initializer "markdowndocs.i18n" do
      config.i18n.load_path += Dir[root.join("config/locales/**/*.yml")]
    end
  end
end
