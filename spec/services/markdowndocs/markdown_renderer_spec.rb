# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markdowndocs::MarkdownRenderer do
  describe ".render" do
    it "renders markdown to HTML" do
      html = described_class.render("# Hello\n\nWorld")
      expect(html).to include("Hello</h1>")
      expect(html).to include("<p>World</p>")
    end

    it "returns empty string for blank input" do
      expect(described_class.render("")).to eq("")
      expect(described_class.render(nil)).to eq("")
    end

    it "applies syntax highlighting to code blocks" do
      markdown = "```ruby\nputs 'hello'\n```"
      html = described_class.render(markdown)
      expect(html).to include("highlight")
    end

    it "sanitizes dangerous HTML" do
      markdown = "<script>alert('xss')</script>"
      html = described_class.render(markdown)
      expect(html).not_to include("<script>")
    end

    it "renders tables" do
      markdown = "| A | B |\n|---|---|\n| 1 | 2 |"
      html = described_class.render(markdown)
      expect(html).to include("<table>")
    end

    context "with mode filtering" do
      let(:markdown) do
        <<~MD
          Always visible.

          <!-- mode: guide -->
          Guide content.
          <!-- /mode -->

          <!-- mode: technical -->
          Technical content.
          <!-- /mode -->
        MD
      end

      it "shows guide content in guide mode" do
        html = described_class.render(markdown, mode: "guide")
        expect(html).to include("Guide content")
        expect(html).not_to include("Technical content")
      end

      it "shows technical content in technical mode" do
        html = described_class.render(markdown, mode: "technical")
        expect(html).to include("Technical content")
        expect(html).not_to include("Guide content")
      end

      it "shows all content with no mode" do
        html = described_class.render(markdown)
        expect(html).to include("Guide content")
        expect(html).to include("Technical content")
      end
    end

    context "with caching" do
      it "caches rendered output when cache_key is provided" do
        markdown = "# Cached"
        first = described_class.render(markdown, cache_key: "test-cache")
        second = described_class.render(markdown, cache_key: "test-cache")
        expect(first).to eq(second)
      end
    end

    context "inline SVG (config.allow_svg)" do
      let(:svg) { %(<svg viewBox="0 0 10 10"><circle cx="1" cy="1" r="1"></circle></svg>) }

      it "strips <svg> by default (allow_svg off)" do
        html = described_class.render(svg)
        expect(html).not_to include("<svg")
      end

      it "renders inline <svg> with camelCase attributes preserved when enabled" do
        Markdowndocs.config.allow_svg = true
        html = described_class.render("# Heading\n\n#{svg}")
        expect(html).to include("<svg")
        expect(html).to include('viewBox="0 0 10 10"')
        expect(html).to include("<circle")
      end

      it "still strips <script> and event handlers inside SVG when enabled" do
        Markdowndocs.config.allow_svg = true
        html = described_class.render(%(<svg onload="x()"><script>alert(1)</script><circle cx="1" cy="1" r="1"></circle></svg>))
        expect(html).to include("<svg")
        expect(html).not_to include("<script")
        expect(html).not_to include("onload")
      end
    end
  end
end
