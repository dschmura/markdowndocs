# frozen_string_literal: true

Markdowndocs::Engine.routes.draw do
  root "docs#index"
  get "search_index", to: "docs#search_index", as: :search_index
  get ":slug", to: "docs#show", as: :doc
  resource :preference, only: [:update]
end
