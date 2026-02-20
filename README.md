# Markdowndocs

A drop-in mountable Rails engine that turns a folder of markdown files into a browsable documentation site with syntax highlighting, category grouping, and mode-based content filtering.

## Features

- **GitHub Flavored Markdown** — Tables, task lists, strikethrough, footnotes, autolinks, and more via [Commonmarker](https://github.com/gjtorikian/commonmarker)
- **Syntax highlighting** — Code blocks highlighted with [Rouge](https://github.com/rouge-ruby/rouge) (configurable theme)
- **Category organization** — Group docs into named categories for the index page
- **Mode-based content filtering** — Show different content to different audiences (e.g., "User Guide" vs "Developer Guide")
- **Table of contents** — Auto-generated from H2/H3 headings with anchor links
- **YAML front matter** — Set title, description, and mode availability per document
- **Breadcrumb navigation** — Category-aware breadcrumbs on each doc page
- **Related documents** — Sidebar links to other docs in the same category
- **Responsive design** — Tailwind CSS with mobile support
- **Security** — HTML sanitization, slug validation, directory traversal prevention
- **Caching** — Rendered markdown is cached with file-mtime-based invalidation
- **i18n support** — All UI strings are translatable

## Requirements

- Ruby >= 3.2
- Rails >= 7.1

## Installation

Add the gem to your application's Gemfile:

```ruby
gem "markdowndocs"
```

Then run:

```bash
bundle install
rails generate markdowndocs:install
```

The generator will:

1. Create `config/initializers/markdowndocs.rb` with default configuration
2. Create the `app/docs/` directory for your markdown files
3. Mount the engine at `/docs` in your routes

## Configuration

Edit `config/initializers/markdowndocs.rb` to customize behavior:

```ruby
Markdowndocs.configure do |config|
  # Path to markdown files (default: Rails.root.join("app/docs"))
  # config.docs_path = Rails.root.join("app", "docs")

  # Category → slug mapping
  config.categories = {
    "Getting Started" => %w[welcome quickstart],
    "Guides" => %w[authentication deployment],
    "Reference" => %w[api-reference configuration]
  }

  # Available documentation modes (default: %w[guide technical])
  # config.modes = %w[guide technical]

  # Default mode (default: "guide")
  # config.default_mode = "guide"

  # Rouge syntax highlighting theme (default: "github")
  # config.rouge_theme = "github"

  # Cache expiry for rendered markdown (default: 1.hour)
  # config.cache_expiry = 1.hour

  # Optional: Resolve current user's mode preference from database
  # config.user_mode_resolver = ->(controller) {
  #   controller.send(:current_user)&.preferences&.docs_mode
  # }

  # Optional: Save user's mode preference to database
  # config.user_mode_saver = ->(controller, mode) {
  #   controller.send(:current_user)&.preferences&.update!(docs_mode: mode)
  # }
end
```

### Configuration Options

| Option               | Default                        | Description                                                    |
| -------------------- | ------------------------------ | -------------------------------------------------------------- |
| `docs_path`          | `Rails.root.join("app/docs")`  | Directory containing your markdown files                       |
| `categories`         | `{}`                           | Maps category names to arrays of document slugs                |
| `modes`              | `%w[guide technical]`          | Available viewing modes                                        |
| `default_mode`       | `"guide"`                      | Mode shown by default                                          |
| `rouge_theme`        | `"github"`                     | Syntax highlighting color scheme                               |
| `cache_expiry`       | `1.hour`                       | Cache duration for rendered markdown                           |
| `user_mode_resolver` | `nil`                          | Lambda to load a user's mode preference from the database      |
| `user_mode_saver`    | `nil`                          | Lambda to persist a user's mode preference to the database     |

## Writing Documentation

Create markdown files in `app/docs/`. The filename (without `.md`) becomes the URL slug — `app/docs/quickstart.md` is served at `/docs/quickstart`.

### Front Matter

Add optional YAML front matter to set metadata:

```markdown
---
title: "Quick Start Guide"
description: "Get up and running in five minutes"
modes:
  - guide
  - technical
default_mode: guide
---

# Quick Start Guide

Your content here...
```

If front matter is omitted, the title is extracted from the first H1 heading and the description from the first paragraph.

### Mode Blocks

Use HTML comments to show content only in specific modes:

```markdown
## Setup

This paragraph appears in all modes.

<!-- mode: guide -->
Follow these steps to get started:
1. Click the "Install" button
2. Follow the on-screen prompts
<!-- /mode -->

<!-- mode: technical -->
Add the dependency to your Gemfile and run the install generator:
\`\`\`bash
bundle add markdowndocs
rails generate markdowndocs:install
\`\`\`
<!-- /mode -->
```

### Syntax Highlighting

Code blocks are automatically syntax-highlighted. Specify the language after the opening fence:

````markdown
```ruby
def hello
  puts "Hello, world!"
end
```

```javascript
function hello() {
  console.log("Hello, world!");
}
```
````

Supported languages include Ruby, JavaScript, Python, Bash, YAML, JSON, HTML, CSS, SQL, and [many more](https://github.com/rouge-ruby/rouge/wiki/List-of-supported-languages-and-lexers).

### Categories

To organize docs on the index page, map category names to slugs in your configuration:

```ruby
config.categories = {
  "Getting Started" => %w[welcome quickstart],
  "Guides" => %w[authentication deployment]
}
```

Documents not assigned to a category will appear in an "Uncategorized" group.

## Rendering Pipeline

When a documentation page is requested, the markdown goes through these stages:

1. **File reading** — Load raw markdown from `app/docs/`
2. **Mode filtering** — Strip content blocks not matching the current viewing mode
3. **Commonmarker parsing** — Parse with GFM extensions (tables, strikethrough, autolinks, footnotes, task lists)
4. **Syntax highlighting** — Apply Rouge highlighting to fenced code blocks
5. **HTML sanitization** — Whitelist-based sanitization strips dangerous tags and attributes
6. **Heading anchors** — Inject `id` attributes on H2/H3 headings for TOC linking
7. **Caching** — Store rendered HTML keyed by file path, mtime, and mode

## Caching

Rendered HTML is cached using `Rails.cache` with a composite cache key based on file path, file modification time, and viewing mode. Cache is automatically invalidated when file content changes.

To manually clear documentation caches:

```ruby
# In Rails console
Rails.cache.clear

# Or delete matched keys
Rails.cache.delete_matched("markdown_*")
```

The default cache expiry is 1 hour, configurable via `config.cache_expiry`.

## Security

### Directory Traversal Prevention

Slugs are validated to contain only alphanumeric characters, hyphens, and underscores. Patterns like `../` and `/` are rejected, ensuring only files within `app/docs/` are accessible.

### HTML Sanitization

All rendered HTML is passed through a whitelist-based sanitizer. Safe tags (headings, paragraphs, code blocks, lists, links, images, tables) are allowed. Script tags, event handlers, and dangerous attributes are stripped.

### YAML Parsing

Front matter is parsed with `YAML.safe_load` to prevent code execution.

## Best Practices

1. **Start with H1** — Every document should have exactly one H1 heading at the top
2. **Write descriptive first paragraphs** — The first paragraph becomes the card description on the index page
3. **Use meaningful filenames** — The filename becomes the URL slug; use kebab-case (e.g., `api-reference.md`)
4. **Include code examples** — Use fenced code blocks with a language specifier for syntax highlighting
5. **Link between docs** — Reference other docs with relative links: `[See authentication](/docs/authentication)`
6. **Keep files focused** — Break large topics into multiple documents
7. **Use sequential headings** — Don't skip levels (e.g., H1 to H3); this ensures proper TOC generation

## Troubleshooting

### Document Not Appearing

1. Check the filename matches the slug in your category mapping
2. Verify the file has a `.md` extension
3. Ensure the file is in the `app/docs/` directory
4. Restart the server if you modified the initializer

### Syntax Highlighting Not Working

1. Verify the code fence has a language specified (e.g., `` ```ruby ``)
2. Check the Rouge theme is configured in the initializer
3. Clear the cache: `Rails.cache.clear`

### 404 Errors

1. Verify the slug matches the filename (use kebab-case)
2. Check the file exists in `app/docs/`
3. Look for typos in the slug or filename

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run the tests:

```bash
bundle exec rspec
```

## Releasing

1. Update `CHANGELOG.md` with a new `## [x.y.z] - YYYY-MM-DD` section and add a comparison link at the bottom.

2. Bump the version in `lib/markdowndocs/version.rb`:

   ```ruby
   module Markdowndocs
     VERSION = "x.y.z"
   end
   ```

3. Commit and tag the release:

   ```bash
   git add lib/markdowndocs/version.rb CHANGELOG.md
   git commit -m "Release vx.y.z"
   git tag vx.y.z
   git push origin main --tags
   ```

   Pushing the tag triggers the GitHub Actions release workflow, which builds and publishes the gem to RubyGems automatically.

## Contributing

Bug reports and pull requests are welcome on GitHub at [github.com/dschmura/markdowndocs](https://github.com/dschmura/markdowndocs).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
