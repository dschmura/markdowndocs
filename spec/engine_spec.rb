# frozen_string_literal: true

require "spec_helper"

RSpec.describe Markdowndocs::Engine do
  describe "initializers" do
    let(:initializers) { described_class.initializers.map(&:name) }

    it "registers the i18n initializer" do
      expect(initializers).to include("markdowndocs.i18n")
    end

    it "registers the assets initializer" do
      expect(initializers).to include("markdowndocs.assets")
    end

    it "registers the importmap initializer" do
      expect(initializers).to include("markdowndocs.importmap")
    end

    it "registers the stimulus initializer" do
      expect(initializers).to include("markdowndocs.stimulus")
    end
  end

  describe "asset paths" do
    it "includes the gem's javascripts directory" do
      js_path = described_class.root.join("app/assets/javascripts")
      expect(js_path).to be_directory
    end
  end

  describe "importmap configuration" do
    it "has an importmap.rb config file" do
      importmap_path = described_class.root.join("config/importmap.rb")
      expect(importmap_path).to be_file
    end

    it "pins the markdowndocs entry point" do
      content = File.read(described_class.root.join("config/importmap.rb"))
      expect(content).to include('pin "markdowndocs", to: "markdowndocs/application.js"')
    end

    it "pins individual controller modules" do
      content = File.read(described_class.root.join("config/importmap.rb"))
      expect(content).to include('pin "markdowndocs/controllers/docs_search_controller"')
      expect(content).to include('pin "markdowndocs/controllers/docs_mode_controller"')
    end

    it "pins minisearch" do
      content = File.read(described_class.root.join("config/importmap.rb"))
      expect(content).to include('pin "minisearch"')
    end
  end

  describe "javascript entry point" do
    let(:application_js) do
      File.read(described_class.root.join("app/assets/javascripts/markdowndocs/application.js"))
    end

    it "exists at app/assets/javascripts/markdowndocs/application.js" do
      expect(described_class.root.join("app/assets/javascripts/markdowndocs/application.js")).to be_file
    end

    it "imports DocsSearchController" do
      expect(application_js).to include('import DocsSearchController from "markdowndocs/controllers/docs_search_controller"')
    end

    it "imports DocsModeController" do
      expect(application_js).to include('import DocsModeController from "markdowndocs/controllers/docs_mode_controller"')
    end

    it "registers controllers with window.Stimulus when available" do
      expect(application_js).to include('window.Stimulus.register("docs-search", DocsSearchController)')
      expect(application_js).to include('window.Stimulus.register("docs-mode", DocsModeController)')
    end

    it "exports controllers for manual registration" do
      expect(application_js).to include("export { DocsSearchController, DocsModeController }")
    end
  end

  describe "stimulus controllers" do
    it "ships docs_search_controller.js" do
      expect(described_class.root.join("app/assets/javascripts/markdowndocs/controllers/docs_search_controller.js")).to be_file
    end

    it "ships docs_mode_controller.js" do
      expect(described_class.root.join("app/assets/javascripts/markdowndocs/controllers/docs_mode_controller.js")).to be_file
    end
  end
end
