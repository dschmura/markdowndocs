# frozen_string_literal: true

# Importmap pins for Markdowndocs engine.
# These are automatically registered with the host app when importmap-rails is present.

pin "markdowndocs/controllers/docs_search_controller", to: "markdowndocs/controllers/docs_search_controller.js"
pin "markdowndocs/controllers/docs_mode_controller", to: "markdowndocs/controllers/docs_mode_controller.js"
pin "minisearch", to: "markdowndocs/vendor/minisearch.min.js"
