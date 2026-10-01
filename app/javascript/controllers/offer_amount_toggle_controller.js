import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="offer-amount-toggle"
export default class extends Controller {
  static targets = ['status', 'amount'];

  connect() {
    this.update();
  }

  update() {
    if (!this.hasStatusTarget || !this.hasAmountTarget) return;

    const offer = this.statusTarget.value === 'offer';
    this.amountTarget.hidden = !offer;
    this.amountTarget.querySelectorAll('input').forEach((input) => (input.disabled = !offer));
  }
}
