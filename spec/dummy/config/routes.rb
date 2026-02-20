# frozen_string_literal: true

Rails.application.routes.draw do
  mount Markdowndocs::Engine, at: "/docs"
end
