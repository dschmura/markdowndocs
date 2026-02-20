# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markdowndocs::Documentation do
  describe ".all" do
    it "returns all documentation files sorted by slug" do
      docs = described_class.all
      expect(docs).to be_an(Array)
      expect(docs.map(&:slug)).to eq(docs.map(&:slug).sort)
    end

    it "returns Documentation instances" do
      docs = described_class.all
      expect(docs).to all(be_a(described_class))
    end

    it "returns empty array when docs path does not exist" do
      Markdowndocs.config.docs_path = Rails.root.join("nonexistent")
      expect(described_class.all).to eq([])
    end
  end

  describe ".find_by_slug" do
    it "finds a document by slug" do
      doc = described_class.find_by_slug("welcome")
      expect(doc).to be_a(described_class)
      expect(doc.slug).to eq("welcome")
    end

    it "returns nil for nonexistent slug" do
      expect(described_class.find_by_slug("nonexistent")).to be_nil
    end

    it "returns nil for blank slug" do
      expect(described_class.find_by_slug("")).to be_nil
      expect(described_class.find_by_slug(nil)).to be_nil
    end

    it "prevents directory traversal" do
      expect(described_class.find_by_slug("../../../etc/passwd")).to be_nil
      expect(described_class.find_by_slug("foo/bar")).to be_nil
    end
  end

  describe ".grouped_by_category" do
    it "groups documents by configured categories" do
      grouped = described_class.grouped_by_category
      expect(grouped.keys).to include("Getting Started", "Guides")
      expect(grouped["Getting Started"].map(&:slug)).to include("welcome", "quickstart")
      expect(grouped["Guides"].map(&:slug)).to include("authentication")
    end
  end

  describe "#title" do
    it "extracts title from frontmatter" do
      doc = described_class.find_by_slug("welcome")
      expect(doc.title).to eq("Welcome")
    end
  end

  describe "#description" do
    it "extracts description from frontmatter" do
      doc = described_class.find_by_slug("welcome")
      expect(doc.description).to eq("Welcome to the documentation")
    end
  end

  describe "#content" do
    it "returns the raw markdown content" do
      doc = described_class.find_by_slug("welcome")
      expect(doc.content).to include("# Welcome")
    end
  end

  describe "#cache_key" do
    it "includes slug and mtime" do
      doc = described_class.find_by_slug("welcome")
      expect(doc.cache_key).to match(/\Awelcome-\d+\z/)
    end
  end

  describe "#available_modes" do
    it "returns modes from frontmatter" do
      doc = described_class.find_by_slug("welcome")
      expect(doc.available_modes).to eq(%w[guide technical])
    end

    it "falls back to configured defaults" do
      doc = described_class.find_by_slug("quickstart")
      expect(doc.available_modes).to eq(Markdowndocs.config.modes)
    end
  end

  describe "#category" do
    it "assigns category from configuration" do
      doc = described_class.find_by_slug("welcome")
      expect(doc.category).to eq("Getting Started")
    end

    it "assigns Other for uncategorized docs" do
      Markdowndocs.config.categories = {}
      doc = described_class.find_by_slug("welcome")
      expect(doc.category).to eq("Other")
    end
  end
end
