import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="auto-submit"
export default class extends Controller {
  static targets = ['form']

  submit() {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit();
    }, 200);
  }
}
