import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="amount-preview"
//
// Echoes a number input as formatted currency (with a monthly estimate), since
// number inputs can't display thousands separators.
export default class extends Controller {
  static targets = ['input', 'output'];

  connect() {
    this.formatter = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
    this.update();
  }

  update() {
    const amount = parseFloat(this.inputTarget.value);

    this.outputTarget.textContent =
      amount > 0 ? `${this.formatter.format(amount)} / year ≈ ${this.formatter.format(amount / 12)} / month` : '';
  }
}
