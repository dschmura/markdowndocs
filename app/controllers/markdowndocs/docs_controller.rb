# frozen_string_literal: true

module Markdowndocs
  class DocsController < ApplicationController
    before_action :validate_slug, only: :show
    before_action :set_docs_mode
    helper Markdowndocs::DocsHelper

    SAFE_SLUG_PATTERN = /\A[a-zA-Z0-9_-]+\z/

    def index
      # Pass the resolved mode so docs whose `audience:` frontmatter
      # excludes it are hidden from the index. Categories with no
      # surviving docs are dropped (see Documentation.grouped_by_category).
      @docs_by_category = Documentation.grouped_by_category(mode: @docs_mode)
      @search_enabled = Markdowndocs.config.search_enabled
    end

    def search_index
      unless Markdowndocs.config.search_enabled
        render_not_found
        return
      end

      cache_key = "markdowndocs:search_index:#{Documentation.all.map(&:cache_key).join(",")}"
      json = Rails.cache.fetch(cache_key, expires_in: Markdowndocs.config.cache_expiry) do
        Documentation.all.map do |doc|
          {
            id: doc.path_slug,
            title: doc.title,
            description: doc.description,
            content: doc.plain_text_content,
            keywords: doc.keywords.join(" "),
            code: doc.code_content
          }
        end.to_json
      end

      response.headers["Cache-Control"] = "public, max-age=#{Markdowndocs.config.cache_expiry.to_i}"
      render json: json
    end

    def show
      # `params[:mode]` here is the URL path segment (e.g. /docs/technical/foo → "technical")
      # if the request matched the scoped route. Otherwise, fall back to the resolved
      # current preference (@docs_mode) so root-mounted docs honor audience-frontmatter
      # filtering.
      lookup_mode = params[:mode].presence || @docs_mode
      @doc = Documentation.find_by_slug(params[:slug], mode: lookup_mode)

      if @doc.nil?
        render_not_found
        return
      end

      # `mode:` here controls in-doc <!-- mode: X --> block stripping,
      # which should reflect the user's PREFERENCE (@docs_mode), not the
      # URL-path mode (lookup_mode). A /technical/foo URL does not force
      # guide-only blocks invisible.
      rendered_html = MarkdownRenderer.render(
        @doc.content,
        cache_key: @doc.cache_key,
        mode: @docs_mode
      )
      @rendered_content = helpers.add_heading_anchors(rendered_html)
      @related_docs = Documentation.by_category(@doc.category).reject { |d| d.path_slug == @doc.path_slug }
      @available_modes = @doc.available_modes
      @toc_items = helpers.generate_table_of_contents(@rendered_content)
    end

    private

    def validate_slug
      slug = params[:slug].to_s

      unless slug.match?(SAFE_SLUG_PATTERN)
        render_not_found
      end
    end

    def render_not_found
      file_404 = Rails.public_path.join("404.html")
      if file_404.exist?
        render file: file_404, status: :not_found, layout: false
      else
        head :not_found
      end
    end

    def set_docs_mode
      @docs_mode = determine_docs_mode
    end

    def determine_docs_mode
      # Only treat params[:mode] as a preference override on the root-mounted
      # `/:slug` route. On the scoped `/:mode/:slug` route, params[:mode] is
      # the URL path segment and is consumed by `show` for doc lookup, not as
      # a preference override.
      preference_param = if path_mode_in_request?
        nil
      else
        params[:mode]
      end

      mode = preference_param ||
        resolve_user_mode ||
        cookies[:markdowndocs_mode] ||
        Markdowndocs.config.default_mode

      valid_modes = Markdowndocs.config.modes
      valid_modes.include?(mode) ? mode : Markdowndocs.config.default_mode
    end

    def path_mode_in_request?
      # The scoped route names `mode` as a path param. On the unscoped route,
      # `mode` (when present) comes from the query string.
      request.path_parameters[:mode].present?
    end

    def resolve_user_mode
      resolver = Markdowndocs.config.user_mode_resolver
      return nil unless resolver.respond_to?(:call)

      resolver.call(self)
    rescue
      nil
    end
  end
end
