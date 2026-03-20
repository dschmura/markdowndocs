import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "category", "card", "noResults"]
  static values = { indexUrl: String }

  connect() {
    this.miniSearch = null
    this.debounceTimer = null
    this.loadIndex()
  }

  disconnect() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  async loadIndex() {
    try {
      const response = await fetch(this.indexUrlValue)
      if (!response.ok) return

      const docs = await response.json()
      const MiniSearch = (await this.loadMiniSearch()).default || (await this.loadMiniSearch())

      this.miniSearch = new MiniSearch({
        fields: ["title", "description", "content", "keywords", "code"],
        storeFields: ["title", "description"],
        searchOptions: {
          boost: { title: 3, description: 2, keywords: 4, code: 0.5 },
          fuzzy: 0.2,
          prefix: true
        }
      })
      this.miniSearch.addAll(docs)
    } catch (e) {
      console.warn("Markdowndocs: failed to load search index", e)
    }
  }

  async loadMiniSearch() {
    // MiniSearch may already be loaded as a global (UMD)
    if (typeof MiniSearch !== "undefined") return MiniSearch

    // Try dynamic import for ES module environments
    try {
      return await import("minisearch")
    } catch {
      // Fallback: load the vendored UMD script
      return new Promise((resolve, reject) => {
        const script = document.createElement("script")
        script.src = this.element.dataset.minisearchUrl || "/assets/markdowndocs/vendor/minisearch.min.js"
        script.onload = () => resolve(window.MiniSearch)
        script.onerror = reject
        document.head.appendChild(script)
      })
    }
  }

  search() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.performSearch(), 50)
  }

  performSearch() {
    const query = this.inputTarget.value.trim()

    if (!query || !this.miniSearch) {
      this.showAll()
      return
    }

    const results = this.miniSearch.search(query)
    const matchingSlugs = new Set(results.map(r => r.id))
    const scoreBySlug = new Map(results.map(r => [r.id, r.score]))

    // Reorder cards within each category by relevance score
    this.categoryTargets.forEach(section => {
      const cards = Array.from(section.querySelectorAll("[data-docs-search-target='card']"))
      cards.forEach(card => {
        const slug = card.dataset.slug
        card.classList.toggle("hidden", !matchingSlugs.has(slug))
      })

      const visibleCards = cards.filter(c => !c.classList.contains("hidden"))
      visibleCards.sort((a, b) => (scoreBySlug.get(b.dataset.slug) || 0) - (scoreBySlug.get(a.dataset.slug) || 0))
      visibleCards.forEach(card => card.parentElement.appendChild(card))

      section.classList.toggle("hidden", visibleCards.length === 0)
    })

    const hasResults = matchingSlugs.size > 0
    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.toggle("hidden", hasResults)
    }
  }

  showAll() {
    this.cardTargets.forEach(card => card.classList.remove("hidden"))
    this.categoryTargets.forEach(section => {
      section.classList.remove("hidden")
      // Restore original order by slug
      const cards = Array.from(section.querySelectorAll("[data-docs-search-target='card']"))
      cards.sort((a, b) => a.dataset.slug.localeCompare(b.dataset.slug))
      cards.forEach(card => card.parentElement.appendChild(card))
    })
    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.add("hidden")
    }
  }
}
