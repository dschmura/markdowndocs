import DocsSearchController from "markdowndocs/controllers/docs_search_controller"
import DocsModeController from "markdowndocs/controllers/docs_mode_controller"

// Auto-register if Stimulus application exists on window, otherwise
// the host app can import and register these controllers manually.
if (window.Stimulus) {
  window.Stimulus.register("docs-search", DocsSearchController)
  window.Stimulus.register("docs-mode", DocsModeController)
}

export { DocsSearchController, DocsModeController }
