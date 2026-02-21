# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markdowndocs do
  it "has a version number" do
    expect(Markdowndocs::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "yields a configuration object" do
      described_class.configure do |config|
        expect(config).to be_a(Markdowndocs::Configuration)
      end
    end

    it "allows setting custom docs_path" do
      described_class.configure do |config|
        config.docs_path = "/custom/path"
      end
      expect(described_class.config.docs_path).to eq("/custom/path")
    end

    it "allows setting categories" do
      described_class.configure do |config|
        config.categories = {"Test" => %w[one two]}
      end
      expect(described_class.config.categories).to eq({"Test" => %w[one two]})
    end

    it "allows setting modes" do
      described_class.configure do |config|
        config.modes = %w[beginner advanced]
      end
      expect(described_class.config.modes).to eq(%w[beginner advanced])
    end

    it "allows setting user_mode_resolver lambda" do
      resolver = ->(_controller) { "custom" }
      described_class.configure do |config|
        config.user_mode_resolver = resolver
      end
      expect(described_class.config.user_mode_resolver).to eq(resolver)
    end
  end

  describe ".reset_configuration!" do
    it "resets to defaults" do
      described_class.configure { |c| c.rouge_theme = "monokai" }
      described_class.reset_configuration!
      expect(described_class.config.rouge_theme).to eq("github")
    end
  end

  describe "Configuration defaults" do
    before { described_class.reset_configuration! }

    it "defaults modes to guide and technical" do
      expect(described_class.config.modes).to eq(%w[guide technical])
    end

    it "defaults default_mode to guide" do
      expect(described_class.config.default_mode).to eq("guide")
    end

    it "defaults rouge_theme to github" do
      expect(described_class.config.rouge_theme).to eq("github")
    end

    it "defaults cache_expiry to 1 hour" do
      expect(described_class.config.cache_expiry).to eq(1.hour)
    end

    it "defaults user_mode_resolver to nil" do
      expect(described_class.config.user_mode_resolver).to be_nil
    end

    it "defaults user_mode_saver to nil" do
      expect(described_class.config.user_mode_saver).to be_nil
    end

    it "defaults resolved_docs_path to Rails.root/app/docs" do
      expect(described_class.config.resolved_docs_path).to eq(Rails.root.join("app", "docs"))
    end

    it "defaults search_enabled to false" do
      expect(described_class.config.search_enabled).to be false
    end
  end
end
