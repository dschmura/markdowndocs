# frozen_string_literal: true

module Markdowndocs
  class PreferencesController < ApplicationController
    def update
      mode = params[:mode].to_s

      unless Markdowndocs.config.modes.include?(mode)
        head :unprocessable_entity
        return
      end

      saver = Markdowndocs.config.user_mode_saver
      if saver.respond_to?(:call)
        begin
          saver.call(self, mode)
        rescue => e
          Rails.logger.warn("Markdowndocs: user_mode_saver failed: #{e.message}")
        end
      end

      cookies[:markdowndocs_mode] = {
        value: mode,
        expires: 1.year.from_now,
        httponly: true
      }

      flash[:notice] = I18n.t(
        "markdowndocs.mode_announcement",
        mode: I18n.t("markdowndocs.modes.#{mode}", default: mode.titleize),
        default: "Now viewing %{mode}."
      )

      redirect_to(smart_nav_target(mode, params[:current_path]), status: :see_other)
    end

    private

    # Computes the post-toggle destination using the unified lookup rule:
    #   1. /docs/<target_mode>/<slug> if the scoped file exists and is not current
    #   2. /docs/<slug> (root) if it exists and is not current
    #   3. current path (stay put)
    # Falls back to the docs index when current_path is missing or doesn't
    # match a recognizable doc URL.
    def smart_nav_target(target_mode, current_path)
      index_path = markdowndocs.root_path.chomp("/")
      return index_path if current_path.blank?

      slug = extract_slug_from_path(current_path)
      return index_path if slug.nil?

      scoped_url = markdowndocs.scoped_doc_path(mode: target_mode, slug: slug)
      root_url = markdowndocs.doc_path(slug: slug)

      # Use Documentation.find_by_slug for existence so symlink-escape
      # rejection (and any other reachability rules) match what the show
      # action would actually serve. Bypassing this — e.g. with raw
      # File.exist? — can redirect the user into a 404.
      if scoped_sibling_reachable?(slug, target_mode) && current_path != scoped_url
        scoped_url
      elsif root_sibling_reachable?(slug) && current_path != root_url
        root_url
      else
        current_path
      end
    end

    def scoped_sibling_reachable?(slug, target_mode)
      docs_path = Markdowndocs.config.resolved_docs_path
      scoped_file = docs_path.join(target_mode, "#{slug}.md")
      return false unless scoped_file.exist?
      Documentation.inside_docs_path?(scoped_file, docs_path.realpath)
    end

    def root_sibling_reachable?(slug)
      docs_path = Markdowndocs.config.resolved_docs_path
      root_file = docs_path.join("#{slug}.md")
      return false unless root_file.exist?
      Documentation.inside_docs_path?(root_file, docs_path.realpath)
    end

    # Pulls the slug from a docs path. Returns nil if the path is the index
    # or doesn't match the docs URL shape. Recognizes both /docs/<slug> and
    # /docs/<mode>/<slug>.
    def extract_slug_from_path(path)
      # Strip query string and trailing slash.
      clean = path.split("?").first.to_s.chomp("/")
      base = markdowndocs.root_path.chomp("/")
      return nil unless clean.start_with?(base)

      remainder = clean[base.length..]
      return nil if remainder.blank? || remainder == "/"

      segments = remainder.sub(%r{\A/}, "").split("/")

      case segments.length
      when 1
        slug_candidate(segments.first)
      when 2
        # Could be /<mode>/<slug>. Only treat second segment as the slug
        # if the first is a configured mode.
        Markdowndocs.config.modes.include?(segments.first) ? slug_candidate(segments.last) : nil
      end
    end

    def slug_candidate(segment)
      return nil if segment.blank?
      return nil if segment.include?("..") || segment.include?("/")
      segment
    end
  end
end
