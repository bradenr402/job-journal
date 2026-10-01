import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="search-clear"
//
// Clears a search input and notifies its `input` listeners.
export default class extends Controller {
  static targets = ['input'];

  clear() {
    this.inputTarget.value = '';
    this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }));
    this.inputTarget.focus();
  }
}
