---
title: Quickstart Guide
description: Get up and running in 5 minutes
---

# Quickstart Guide

Get up and running in 5 minutes.

## Installation

Add the gem to your Gemfile:

```ruby
gem "markdowndocs"
```

## Mount the Engine

Add to your routes:

```ruby
mount Markdowndocs::Engine, at: "/docs"
```

## Configuration reference

| Option | Default | Description |
|---|---|---|
| `cache_expiry` | `1.hour` | How long rendered HTML is cached |
| `allow_svg` | `false` | Permit sanitized inline SVG in docs |
