# frozen_string_literal: true

require_relative "lib/markdowndocs/version"

Gem::Specification.new do |spec|
  spec.name = "markdowndocs"
  spec.version = Markdowndocs::VERSION
  spec.authors = ["Dave Chmura"]
  spec.email = ["dschmura@humbledaisy.com"]

  spec.summary = "A drop-in markdown documentation site for Rails apps"
  spec.description = "Mountable Rails engine that renders markdown files as a browsable documentation site with syntax highlighting, TOC generation, category grouping, and mode-based content filtering."
  spec.homepage = "https://github.com/dschmura/markdowndocs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "commonmarker", ">= 1.0"
  spec.add_dependency "rouge", "~> 4.0"
  spec.add_dependency "rails-html-sanitizer", "~> 1.6"
end
