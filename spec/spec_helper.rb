# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require File.expand_path("dummy/config/environment", __dir__)
require "rspec/rails"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    Markdowndocs.configure do |c|
      c.categories = {
        "Getting Started" => %w[welcome quickstart],
        "Guides" => %w[authentication]
      }
    end
  end

  config.after do
    Markdowndocs.reset_configuration!
    Markdowndocs.configure do |c|
      c.categories = {
        "Getting Started" => %w[welcome quickstart],
        "Guides" => %w[authentication]
      }
    end
  end
end
