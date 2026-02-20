# frozen_string_literal: true

module Markdowndocs
  class PreferencesController < ApplicationController
    def update
      mode = params[:mode].to_s

      unless Markdowndocs.config.modes.include?(mode)
        head :unprocessable_entity
        return
      end

      # Save to database via host app's lambda (if configured)
      saver = Markdowndocs.config.user_mode_saver
      if saver.respond_to?(:call)
        begin
          saver.call(self, mode)
        rescue => e
          Rails.logger.warn("Markdowndocs: user_mode_saver failed: #{e.message}")
        end
      end

      # Always set cookie as fallback
      cookies[:markdowndocs_mode] = {
        value: mode,
        expires: 1.year.from_now,
        httponly: true
      }

      redirect_back(fallback_location: markdowndocs.root_path, status: :see_other)
    end
  end
end
