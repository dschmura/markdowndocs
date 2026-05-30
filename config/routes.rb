# frozen_string_literal: true

Markdowndocs::Engine.routes.draw do
  root "docs#index"
  get "search_index", to: "docs#search_index", as: :search_index

  # Mode-scoped doc route: matches /<mode>/<slug> where <mode> is one of
  # the configured modes. Must come BEFORE the unconstrained :slug route
  # so the more specific match wins.
  #
  # The constraint reads live config so dev-reload edits to config.modes
  # take effect without a full server restart. Proc constraints apply only
  # to request recognition; URL generation remains permissive.
  mode_constraint = lambda do |request|
    mode = request.path_parameters[:mode]
    Array(Markdowndocs.config.modes).include?(mode)
  end
  get ":mode/:slug", to: "docs#show", as: :scoped_doc, constraints: mode_constraint

  get ":slug", to: "docs#show", as: :doc
  resource :preference, only: [:update]
end
