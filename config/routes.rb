# frozen_string_literal: true

Markdowndocs::Engine.routes.draw do
  root "docs#index"
  get "search_index", to: "docs#search_index", as: :search_index

  # Mode-scoped doc route: matches /<mode>/<slug> where <mode> is one of
  # the configured modes. Must come BEFORE the unconstrained :slug route
  # so the more specific match wins.
  mode_constraint = if Markdowndocs.config.modes.any?
    Regexp.new("(?:#{Markdowndocs.config.modes.map { |m| Regexp.escape(m) }.join("|")})")
  else
    /impossible/
  end
  get ":mode/:slug", to: "docs#show", as: :scoped_doc, constraints: {mode: mode_constraint}

  get ":slug", to: "docs#show", as: :doc
  resource :preference, only: [:update]
end
