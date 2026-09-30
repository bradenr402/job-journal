import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="number-field"
export default class extends Controller {
  static targets = ['input'];
  static values = { step: { type: Number, default: 1 }, precision: { type: Number, default: 0 } };

  connect() {
    this.holdInterval = null;
    this.holdTimeout = null;
    this.incrementButton = this.element.querySelector('.form-number-increment');
    this.decrementButton = this.element.querySelector('.form-number-decrement');
    this.updateButtons = this.updateButtons.bind(this);

    this.addHoldListeners();
    this.inputTarget.addEventListener('input', this.updateButtons);
    this.updateButtons();
  }

  disconnect() {
    this.stopHold();
    this.inputTarget.removeEventListener('input', this.updateButtons);
  }

  addHoldListeners() {
    if (this.incrementButton) {
      this.incrementButton.addEventListener('pointerdown', () => this.startIncrement());
      this.incrementButton.addEventListener('pointerup', () => this.stopHold());
      this.incrementButton.addEventListener('pointerleave', () => this.stopHold());
      this.incrementButton.addEventListener('touchend', () => this.stopHold());
    }

    if (this.decrementButton) {
      this.decrementButton.addEventListener('pointerdown', () => this.startDecrement());
      this.decrementButton.addEventListener('pointerup', () => this.stopHold());
      this.decrementButton.addEventListener('pointerleave', () => this.stopHold());
      this.decrementButton.addEventListener('touchend', () => this.stopHold());
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

  // Disables the decrement button at `min` and the increment button at `max`.
  // A disabled button stops firing pointer events, so any hold in progress is stopped too.
  updateButtons() {
    const { value, min, max } = this.inputTarget;
    const number = parseFloat(value);
    const hasValue = value !== '' && !isNaN(number);

    const atMin = hasValue && min !== '' && number <= parseFloat(min);
    const atMax = hasValue && max !== '' && number >= parseFloat(max);

    if (this.decrementButton) this.decrementButton.disabled = atMin;
    if (this.incrementButton) this.incrementButton.disabled = atMax;
    if (atMin || atMax) this.stopHold();
  }
}
