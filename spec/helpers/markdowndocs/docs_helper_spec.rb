# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markdowndocs::DocsHelper, type: :helper do
  describe "#generate_table_of_contents" do
    it "extracts H2 and H3 headings" do
      html = '<h2 id="intro">Introduction</h2><h3 id="sub">Subsection</h3>'
      toc = helper.generate_table_of_contents(html)
      expect(toc.length).to eq(2)
      expect(toc[0]).to eq({text: "Introduction", slug: "intro", level: 2})
      expect(toc[1]).to eq({text: "Subsection", slug: "sub", level: 3})
    end

    it "returns empty array for blank HTML" do
      expect(helper.generate_table_of_contents("")).to eq([])
      expect(helper.generate_table_of_contents(nil)).to eq([])
    end

    it "slugifies headings without IDs" do
      html = "<h2>Hello World</h2>"
      toc = helper.generate_table_of_contents(html)
      expect(toc[0][:slug]).to eq("hello-world")
    end
  end

  describe "#slugify_heading" do
    it "converts text to URL-safe slug" do
      expect(helper.slugify_heading("Hello World")).to eq("hello-world")
      expect(helper.slugify_heading("What's New?")).to eq("whats-new")
      expect(helper.slugify_heading("  Extra  Spaces  ")).to eq("extra-spaces")
    end
  end

  describe "#add_heading_anchors" do
    it "adds IDs to headings" do
      html = "<h2>Introduction</h2>"
      result = helper.add_heading_anchors(html)
      expect(result).to include('id="introduction"')
    end

    it "preserves existing IDs" do
      html = '<h2 id="custom">Title</h2>'
      result = helper.add_heading_anchors(html)
      expect(result).to include('id="custom"')
    end

    it "removes empty anchor tags" do
      html = '<h2><a class="anchor" href="#"></a>Title</h2>'
      result = helper.add_heading_anchors(html)
      expect(result).not_to include('class="anchor"')
    end

    it "returns blank HTML unchanged" do
      expect(helper.add_heading_anchors("")).to eq("")
      expect(helper.add_heading_anchors(nil)).to be_nil
    end
  end
end
