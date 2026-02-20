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

      def show_post_install_message
        say ""
        say "Markdowndocs installed successfully!", :green
        say ""
        say "Next steps:"
        say "  1. Edit config/initializers/markdowndocs.rb to configure categories"
        say "  2. Add markdown files to app/docs/"
        say "  3. Visit /docs to see your documentation"
        say ""
      end
    end
  end
end
