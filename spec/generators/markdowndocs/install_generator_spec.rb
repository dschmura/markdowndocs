# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "generators/markdowndocs/install/install_generator"

RSpec.describe Markdowndocs::Generators::InstallGenerator, type: :generator do
  let(:generator_class) { described_class }

  describe "public instance methods" do
    let(:instance_methods) { generator_class.public_instance_methods(false) }

    it "defines create_initializer" do
      expect(instance_methods).to include(:create_initializer)
    end

    it "defines create_docs_directory" do
      expect(instance_methods).to include(:create_docs_directory)
    end

    it "defines add_route" do
      expect(instance_methods).to include(:add_route)
    end

    it "defines add_markdowndocs_import instead of pin_importmap_assets" do
      expect(instance_methods).to include(:add_markdowndocs_import)
      expect(instance_methods).not_to include(:pin_importmap_assets)
    end

    it "defines inject_tailwind_source" do
      expect(instance_methods).to include(:inject_tailwind_source)
    end

    it "defines show_post_install_message" do
      expect(instance_methods).to include(:show_post_install_message)
    end
  end

  describe "generator source" do
    let(:source) { File.read(generator_class.instance_method(:add_markdowndocs_import).source_location.first) }

    it "adds import \"markdowndocs\" to application.js" do
      expect(source).to include('import "markdowndocs"')
    end

    it "checks for app/javascript/application.js" do
      expect(source).to include("app/javascript/application.js")
    end

    it "skips if import already present" do
      expect(source).to include("already present")
    end
  end
end
