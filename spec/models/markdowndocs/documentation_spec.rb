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

    # Audience filtering: docs declare `audience:` in their frontmatter.
    # When the controller passes a mode, the grouped result hides any doc
    # whose audience excludes that mode. Docs WITHOUT an `audience:` key
    # default to "visible in all modes" — backward compatible.
    context "with a mode: argument" do
      it "hides docs whose audience excludes the given mode (technical-only doc disappears in guide mode)" do
        grouped = described_class.grouped_by_category(mode: "guide")
        slugs = grouped.values.flatten.map(&:slug)
        expect(slugs).to include("welcome", "quickstart", "authentication")
        expect(slugs).not_to include("admin-reference")
      end

      it "shows technical-only docs in technical mode" do
        grouped = described_class.grouped_by_category(mode: "technical")
        slugs = grouped.values.flatten.map(&:slug)
        expect(slugs).to include("admin-reference")
      end

      it "shows multi-audience docs in either mode" do
        # welcome.md declares `audience: [guide, technical]`.
        expect(described_class.grouped_by_category(mode: "guide").values.flatten.map(&:slug)).to include("welcome")
        expect(described_class.grouped_by_category(mode: "technical").values.flatten.map(&:slug)).to include("welcome")
      end

      it "shows docs WITHOUT audience frontmatter in every mode (backward compat)" do
        # quickstart.md and authentication.md have no `audience:` key.
        guide_slugs = described_class.grouped_by_category(mode: "guide").values.flatten.map(&:slug)
        technical_slugs = described_class.grouped_by_category(mode: "technical").values.flatten.map(&:slug)
        expect(guide_slugs).to include("quickstart", "authentication")
        expect(technical_slugs).to include("quickstart", "authentication")
      end

      it "drops empty categories when no docs match the mode" do
        # "Administrator Reference" holds only `admin-reference` (technical).
        # In guide mode the category itself should disappear, not surface as
        # an empty header.
        grouped = described_class.grouped_by_category(mode: "guide")
        expect(grouped.keys).not_to include("Administrator Reference")
      end
    end

    it "behaves identically when mode is nil (no filter)" do
      unfiltered = described_class.grouped_by_category.values.flatten.map(&:slug).sort
      explicitly_nil = described_class.grouped_by_category(mode: nil).values.flatten.map(&:slug).sort
      expect(unfiltered).to eq(explicitly_nil)
    end
  end

  describe "#audience" do
    it "returns the array from frontmatter when present" do
      doc = described_class.find_by_slug("welcome")
      expect(doc.audience).to eq(%w[guide technical])
    end

    it "coerces a single string value into a single-element array" do
      doc = described_class.find_by_slug("admin-reference")
      expect(doc.audience).to eq(%w[technical])
    end

    it "defaults to ALL configured modes when frontmatter has no audience key" do
      doc = described_class.find_by_slug("quickstart")
      expect(doc.audience).to eq(Markdowndocs.config.modes)
    end
  end

  describe "#visible_to?(mode)" do
    it "is true when audience includes the mode" do
      expect(described_class.find_by_slug("admin-reference").visible_to?("technical")).to be true
      expect(described_class.find_by_slug("welcome").visible_to?("guide")).to be true
      expect(described_class.find_by_slug("welcome").visible_to?("technical")).to be true
    end

    it "is false when audience excludes the mode" do
      expect(described_class.find_by_slug("admin-reference").visible_to?("guide")).to be false
    end

    it "is true for any mode when audience is unset (backward compat)" do
      doc = described_class.find_by_slug("quickstart")
      expect(doc.visible_to?("guide")).to be true
      expect(doc.visible_to?("technical")).to be true
    end

    it "is true when mode is nil (no filter)" do
      expect(described_class.find_by_slug("admin-reference").visible_to?(nil)).to be true
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

  describe "#plain_text_content" do
    it "strips frontmatter and markdown syntax" do
      doc = described_class.find_by_slug("welcome")
      text = doc.plain_text_content
      expect(text).not_to include("---")
      expect(text).not_to include("# ")
      expect(text).not_to include("**")
    end

    it "returns searchable plain text" do
      doc = described_class.find_by_slug("welcome")
      text = doc.plain_text_content
      expect(text).to be_present
      expect(text.length).to be > 0
    end
  end

  describe "#keywords" do
    it "returns array from frontmatter" do
      doc = described_class.find_by_slug("authentication")
      expect(doc.keywords).to eq(%w[login signin password session])
    end

    it "returns empty array when not present" do
      doc = described_class.find_by_slug("quickstart")
      expect(doc.keywords).to eq([])
    end
  end

  describe "#code_content" do
    it "extracts text from fenced code blocks" do
      doc = described_class.find_by_slug("quickstart")
      code = doc.code_content
      expect(code).to include("gem \"markdowndocs\"")
      expect(code).to include("Markdowndocs::Engine")
    end

    it "returns empty string when no code blocks exist" do
      doc = described_class.find_by_slug("authentication")
      expect(doc.code_content).to eq("")
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
