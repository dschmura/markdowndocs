import { Controller } from "@hotwired/stimulus"

/**
 * Documentation Mode Controller
 *
 * Handles localStorage persistence for guest users and provides
 * optimistic UI updates for the documentation mode switcher.
 *
 * For authenticated users, the preference is stored in the database
 * via the PreferencesController. For guests, we use localStorage
 * as a fallback to persist their preference across sessions.
 */
export default class extends Controller {
  static values = {
    current: { type: String, default: "guide" }
  }

  static STORAGE_KEY = "markdowndocs_mode"

  connect() {
    if (!this.isAuthenticated()) {
      this.restoreGuestMode()
    }
  }

  isAuthenticated() {
    const meta = document.querySelector('meta[name="user-authenticated"]')
    return meta?.content === "true"
  }

  restoreGuestMode() {
    try {
      const savedMode = localStorage.getItem(this.constructor.STORAGE_KEY)

      if (savedMode && savedMode !== this.currentValue) {
        const url = new URL(window.location)
        url.searchParams.set("mode", savedMode)
        window.location.replace(url)
      }
    } catch (e) {
      console.debug("localStorage unavailable for docs mode persistence")
    }
  }

  saveGuestMode(mode) {
    try {
      localStorage.setItem(this.constructor.STORAGE_KEY, mode)
    } catch (e) {
      console.debug("localStorage unavailable for docs mode persistence")
    }
  }

  currentValueChanged() {
    if (!this.isAuthenticated()) {
      this.saveGuestMode(this.currentValue)
    }
  }
}
