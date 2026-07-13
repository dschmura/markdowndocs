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
      expect(html).to include("<table")
      expect(html).to include("</table>")
    end

    describe "table keyboard accessibility (WCAG 2.1.1)" do
      it "makes each table focusable so a keyboard user can scroll it" do
        markdown = "| A | B |\n|---|---|\n| 1 | 2 |"
        html = described_class.render(markdown)
        expect(html).to match(/<table[^>]*tabindex="0"/)
      end

      it "does NOT override the table role (no role=region on the table itself)" do
        markdown = "| A | B |\n|---|---|\n| 1 | 2 |"
        html = described_class.render(markdown)
        expect(html).not_to match(/<table[^>]*role=/)
      end

      it "names an un-captioned table with a minimal aria-label" do
        markdown = "| A | B |\n|---|---|\n| 1 | 2 |"
        html = described_class.render(markdown)
        expect(html).to match(/<table[^>]*aria-label="Table"/)
      end

      it "keeps tabindex through the sanitizer" do
        # tabindex is added AFTER parse but must survive SafeListSanitizer —
        # it lives in BASE_SANITIZE_ATTRS for exactly this reason.
        markdown = "| A |\n|---|\n| 1 |"
        html = described_class.render(markdown)
        expect(html).to include('tabindex="0"')
      end

      it "makes every table in a multi-table document focusable" do
        markdown = "| A |\n|---|\n| 1 |\n\ntext\n\n| B |\n|---|\n| 2 |"
        html = described_class.render(markdown)
        expect(html.scan(/<table[^>]*tabindex="0"/).length).to eq(2)
      end
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

      it "preserves ARIA labelling attributes so inline diagrams have accessible names" do
        Markdowndocs.config.allow_svg = true
        html = described_class.render(
          %(<svg role="img" aria-label="System diagram" aria-describedby="d1" focusable="false">) +
            %(<desc id="d1">A high-level system overview.</desc><circle cx="1" cy="1" r="1"/></svg>)
        )
        expect(html).to include('role="img"')
        expect(html).to include('aria-label="System diagram"')
        expect(html).to include('aria-describedby="d1"')
        expect(html).to include('focusable="false"')
        expect(html).to include("<desc")
      end

      it "preserves aria-hidden on decorative inline SVGs" do
        Markdowndocs.config.allow_svg = true
        html = described_class.render(
          %(<svg aria-hidden="true"><circle cx="1" cy="1" r="1"/></svg>)
        )
        expect(html).to include('aria-hidden="true"')
      end

      it "preserves xmlns so downstream XML consumers can re-parse the snippet" do
        Markdowndocs.config.allow_svg = true
        html = described_class.render(
          %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><circle cx="1" cy="1" r="1"/></svg>)
        )
        expect(html).to include('xmlns="http://www.w3.org/2000/svg"')
      end

      after { Markdowndocs.config.allow_svg = false }
    end

    context "collapsible disclosure (<details>/<summary>)" do
      # Disclosure is raw HTML, so it rides the same curated raw-HTML passthrough
      # as inline SVG (config.allow_svg flips commonmarker to unsafe so the markup
      # reaches the sanitizer — the security boundary — instead of being escaped).
      before { Markdowndocs.config.allow_svg = true }
      after { Markdowndocs.config.allow_svg = false }

      it "preserves <details> and <summary> so docs can collapse sections" do
        html = described_class.render("<details>\n<summary>Why</summary>\n\nBecause reasons.\n</details>")
        expect(html).to include("<details")
        expect(html).to include("<summary>")
        expect(html).to include("Because reasons.")
      end

      it "preserves the open attribute so a section can default to expanded" do
        html = described_class.render("<details open>\n<summary>S</summary>\n\nBody.\n</details>")
        expect(html).to match(/<details[^>]*\sopen/)
      end

      it "still strips scripts and event handlers inside a disclosure" do
        html = described_class.render(%(<details onclick="x()"><summary>S</summary><script>alert(1)</script></details>))
        expect(html).to include("<details")
        expect(html).not_to include("<script")
        expect(html).not_to include("onclick")
      end
    end

    context "when the rendering pipeline raises" do
      it "falls back to an escaped pre block instead of returning empty" do
        # Force any downstream failure (parse, sanitize, highlight) to fire.
        allow(Commonmarker).to receive(:parse).and_raise(RuntimeError, "boom")

        result = described_class.render("# Hello\n\nThis is **bold**.\n")

        # Page is not silently wiped — the user sees their content as text,
        # preserved verbatim in a code block.
        expect(result).not_to eq("")
        expect(result).to include("Hello")
        expect(result).to include("bold")
        # The fallback escapes — no live HTML element renders from the markdown.
        expect(result).not_to include("<strong>")
        # And the fallback is wrapped recognizably so hosts can style it.
        expect(result).to include("markdowndocs-render-error")
      end
    end
  end
end
