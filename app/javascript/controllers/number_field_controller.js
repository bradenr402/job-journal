import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="number-field"
export default class extends Controller {
  static targets = ['input'];
  static values = { step: { type: Number, default: 1 }, precision: { type: Number, default: 0 } };

  connect() {
    this.holdInterval = null;
    this.holdTimeout = null;
    this.addHoldListeners();
  }

  addHoldListeners() {
    const incrementButton = this.element.querySelector('.form-number-increment');
    const decrementButton = this.element.querySelector('.form-number-decrement');

    if (incrementButton) {
      incrementButton.addEventListener('pointerdown', () => this.startIncrement());
      incrementButton.addEventListener('pointerup', () => this.stopHold());
      incrementButton.addEventListener('pointerleave', () => this.stopHold());
      incrementButton.addEventListener('touchend', () => this.stopHold());
    }

    if (decrementButton) {
      decrementButton.addEventListener('pointerdown', () => this.startDecrement());
      decrementButton.addEventListener('pointerup', () => this.stopHold());
      decrementButton.addEventListener('pointerleave', () => this.stopHold());
      decrementButton.addEventListener('touchend', () => this.stopHold());
    }
  }

  startIncrement() {
    this.increment();
    this.holdTimeout = setTimeout(() => {
      this.holdInterval = setInterval(() => this.increment(), 60);
    }, 400);
  }

  startDecrement() {
    this.decrement();
    this.holdTimeout = setTimeout(() => {
      this.holdInterval = setInterval(() => this.decrement(), 60);
    }, 400);
  }

  stopHold() {
    clearTimeout(this.holdTimeout);
    clearInterval(this.holdInterval);
  }

  increment() {
    const input = this.inputTarget;
    input.stepUp(this.stepValue);
    this.formatInputValue();
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }

  decrement() {
    const input = this.inputTarget;
    input.stepDown(this.stepValue);
    this.formatInputValue();
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }

  formatInputValue() {
    const input = this.inputTarget;
    if (!input.value || isNaN(input.value)) return;
    if (this.precisionValue > 0) input.value = Number(input.value).toFixed(this.precisionValue);
  }
}
