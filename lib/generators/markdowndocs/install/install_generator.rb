# frozen_string_literal: true

module Markdowndocs
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install Markdowndocs into your Rails application"

      def create_initializer
        template "initializer.rb", "config/initializers/markdowndocs.rb"
      end

      def create_docs_directory
        empty_directory "app/docs"
        create_file "app/docs/.keep"
      end

      def add_route
        route 'mount Markdowndocs::Engine, at: "/docs"'
      end

      def inject_tailwind_source
        css_file = find_tailwind_css_file
        return unless css_file

        gem_views_path = Markdowndocs::Engine.root.join("app", "views")
        source_line = %(@source "#{gem_views_path}/**/*.erb";)

        if File.read(css_file).include?(source_line)
          say_status :skip, "Tailwind @source for markdowndocs already present", :yellow
          return
        end

        inject_into_file css_file, after: %(@import "tailwindcss";\n) do
          "\n/* Markdowndocs gem views — required so Tailwind scans the gem's templates */\n#{source_line}\n"
        end

        say_status :inject, "Tailwind @source for markdowndocs views", :green
      end

      def show_post_install_message
        say ""
        say "Markdowndocs installed successfully!", :green
        say ""
        say "Next steps:"
        say "  1. Edit config/initializers/markdowndocs.rb to configure categories"
        say "  2. Add markdown files to app/docs/"
        say "  3. Visit /docs to see your documentation"
        say ""
        unless find_tailwind_css_file
          say "  NOTE: Could not find your Tailwind CSS file.", :yellow
          say "  Add this line after @import \"tailwindcss\" in your CSS:"
          say "    @source \"#{Markdowndocs::Engine.root.join("app", "views")}/**/*.erb\";"
          say ""
        end
      end

      private

      def find_tailwind_css_file
        candidates = [
          "app/assets/tailwind/application.css",
          "app/assets/stylesheets/application.tailwind.css"
        ]
        candidates.find { |f| File.exist?(Rails.root.join(f)) }&.then { |f| Rails.root.join(f).to_s }
      end
    end
  end
end
