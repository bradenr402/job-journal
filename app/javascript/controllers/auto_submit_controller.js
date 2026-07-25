import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="auto-submit"
export default class extends Controller {
  static targets = ['form']

  submit() {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit();
      this.updateUrl();
    }, 200);
  }

  // Reflects the submitted form data in the address bar, since the Turbo
  // Stream response never performs a visit that would advance the URL.
  updateUrl() {
    const url = new URL(this.formTarget.action);

    for (const [key, value] of new FormData(this.formTarget)) {
      if (value) url.searchParams.append(key, value);
    }

    history.replaceState(history.state, '', url);
  }
}
