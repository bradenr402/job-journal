import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="password-visibility"
export default class extends Controller {
  static targets = ['input', 'button', 'showIcon', 'hideIcon'];

  toggle() {
    const reveal = this.inputTarget.type === 'password';

    this.inputTarget.type = reveal ? 'text' : 'password';
    this.buttonTarget.setAttribute('aria-pressed', reveal);
    this.buttonTarget.setAttribute('aria-label', reveal ? 'Hide password' : 'Show password');
    this.showIconTarget.hidden = reveal;
    this.hideIconTarget.hidden = !reveal;
  }
}
