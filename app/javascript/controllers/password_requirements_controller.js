import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="password-requirements"
//
// Live feedback for a new password: minimum length and confirmation match.
export default class extends Controller {
  static targets = ['password', 'confirmation', 'length', 'match'];
  static values = { minLength: { type: Number, default: 6 } };

  connect() {
    this.update();
  }

  update() {
    const password = this.passwordTarget.value;
    const confirmation = this.hasConfirmationTarget ? this.confirmationTarget.value : '';

    if (this.hasLengthTarget) {
      this.#mark(this.lengthTarget, password.length >= this.minLengthValue);
    }

    if (this.hasMatchTarget) {
      this.matchTarget.hidden = confirmation === '';
      this.#mark(this.matchTarget, confirmation !== '' && confirmation === password);
    }
  }

  #mark(element, met) {
    element.classList.toggle('form-requirement-met', met);
    element.querySelectorAll('[data-met]').forEach((el) => (el.hidden = el.dataset.met !== String(met)));
  }
}
