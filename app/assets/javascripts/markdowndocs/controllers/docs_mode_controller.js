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
  static FOCUS_KEY = "markdowndocs_focus_mode"

  connect() {
    if (!this.isAuthenticated()) {
      this.restoreGuestMode()
    }
    this.restoreFocusAfterToggle()
  }

  rememberFocus(event) {
    // Save the mode the user just pressed so we can restore focus to the
    // matching button after Turbo replaces the page (a11y: keep focus on
    // the control the user actuated, not on the article wrapper).
    try {
      const mode = event.currentTarget.dataset.mode
      if (mode) {
        sessionStorage.setItem(this.constructor.FOCUS_KEY, mode)
      }
    } catch (e) {
      // sessionStorage unavailable — accept the focus loss gracefully.
    }
  }

  restoreFocusAfterToggle() {
    let pendingMode
    try {
      pendingMode = sessionStorage.getItem(this.constructor.FOCUS_KEY)
      if (pendingMode) sessionStorage.removeItem(this.constructor.FOCUS_KEY)
    } catch (e) {
      return
    }
    if (!pendingMode) return

    const button = this.element.querySelector(`button[data-mode="${pendingMode}"]`)
    if (button) {
      // Defer past the Turbo render + autofocus on the article wrapper so
      // we steal focus from it; otherwise autofocus would win the race.
      window.requestAnimationFrame(() => button.focus())
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
