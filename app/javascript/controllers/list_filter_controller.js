import { Controller } from "@hotwired/stimulus"

// Filters a list of items client-side by matching the input value against
// each item's `data-list-filter-key` attribute. The query is mirrored to the
// URL so filtered views can be reloaded and shared.
export default class extends Controller {
  static targets = ["input", "item", "count"]
  static values = { singular: String, plural: String, param: { type: String, default: "q" } }

  connect() {
    if (this.hasInputTarget && this.inputTarget.value) this.filter()
  }

  filter() {
    const rawQuery = this.inputTarget.value.trim()
    const query = rawQuery.toLowerCase()
    let visibleCount = 0

    this.itemTargets.forEach((item) => {
      const match = item.dataset.listFilterKey.toLowerCase().includes(query)
      item.hidden = !match
      if (match) visibleCount++
    })

    if (this.hasCountTarget) this.#renderCount(visibleCount, rawQuery)
    this.#updateUrl(rawQuery)
  }

  #renderCount(count, query) {
    const noun = count === 1 ? this.singularValue : this.pluralValue
    this.countTarget.textContent = `${count === 0 ? "No" : count} ${noun}`

    if (query) {
      const match = document.createElement("span")
      match.className = "font-semibold text-light"
      match.textContent = `“${query}”`
      this.countTarget.append(" matching ", match)
    }
  }

  #updateUrl(query) {
    const url = new URL(window.location.href)
    if (query) {
      url.searchParams.set(this.paramValue, query)
    } else {
      url.searchParams.delete(this.paramValue)
    }
    if (url.href === window.location.href) return

    if (window.Turbo) {
      window.Turbo.navigator.history.replace(url)
    } else {
      history.replaceState(history.state, "", url)
    }
  }
}
