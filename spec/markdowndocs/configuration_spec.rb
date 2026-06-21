# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markdowndocs::Configuration do
  describe "#modes=" do
    let(:config) { described_class.new }

    it "accepts the default array of strings" do
      config.modes = %w[guide technical]
      expect(config.modes).to eq(%w[guide technical])
    end

    it "coerces nil to an empty array" do
      config.modes = nil
      expect(config.modes).to eq([])
    end

    it "removes duplicate entries" do
      config.modes = %w[guide technical guide]
      expect(config.modes).to eq(%w[guide technical])
    end

    it "strips surrounding whitespace from entries" do
      config.modes = [" guide ", "technical"]
      expect(config.modes).to eq(%w[guide technical])
    end

    it "raises when a mode name collides with the engine's reserved route segments" do
      expect { config.modes = %w[guide search_index] }
        .to raise_error(ArgumentError, /reserved/i)
      expect { config.modes = %w[guide preference] }
        .to raise_error(ArgumentError, /reserved/i)
      expect { config.modes = %w[guide preferences] }
        .to raise_error(ArgumentError, /reserved/i)
    end

    it "raises on entries containing path separators" do
      expect { config.modes = %w[guide foo/bar] }
        .to raise_error(ArgumentError, /invalid/i)
    end

    it "raises on entries containing URL-significant characters" do
      ["foo?bar", "foo#bar", "foo bar", "foo&bar"].each do |bad|
        expect { config.modes = ["guide", bad] }
          .to raise_error(ArgumentError, /invalid/i), "expected #{bad.inspect} to be rejected"
      end
    end

    it "raises on empty-string entries" do
      expect { config.modes = ["guide", ""] }
        .to raise_error(ArgumentError, /invalid/i)
    end

    it "raises on non-string entries" do
      expect { config.modes = ["guide", :technical] }
        .to raise_error(ArgumentError, /string/i)
    end

    it "accepts an empty array (mode-scoping disabled)" do
      config.modes = []
      expect(config.modes).to eq([])
    end
  end
end
