import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="delete-confirm"
//
// Live feedback for the typed account-deletion confirmation. The server
// enforces the same rules, so the submit button stays enabled.
export default class extends Controller {
  static targets = ['password', 'phrase', 'status', 'message'];
  static values = { phrase: { type: String, default: 'DELETE' } };

  connect() {
    this.update();
  }

  update() {
    const passwordEntered = this.passwordTarget.value !== '';
    const phraseMatches = this.phraseTarget.value.trim() === this.phraseValue;
    const met = passwordEntered && phraseMatches;

    this.statusTarget.classList.toggle('form-requirement-met', met);
    this.statusTarget.querySelectorAll('[data-met]').forEach((el) => (el.hidden = el.dataset.met !== String(met)));
    this.messageTarget.textContent = met ? 'Ready to delete' : 'Enter your password and type DELETE';
  }
}
