# frozen_string_literal: true

Markdowndocs::Engine.routes.draw do
  root "docs#index"
  get ":slug", to: "docs#show", as: :doc
  resource :preference, only: [:update]
end
