import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="select-dropdown"
//
// Turns the dropdown component into a form field: choosing an option stores its
// value in a hidden input and fires `change`, like a native <select>.
export default class extends Controller {
  static targets = ['input', 'label'];

  choose(event) {
    const option = event.currentTarget;
    if (this.inputTarget.value === option.dataset.value) return;

    this.inputTarget.value = option.dataset.value;
    this.labelTarget.innerHTML = option.querySelector('[data-select-dropdown-content]').innerHTML;
    this.labelTarget.classList.toggle('text-muted', option.dataset.value === '');

    this.element.querySelectorAll('[role=option]').forEach((other) => {
      const on = other === option;
      other.setAttribute('aria-selected', on);
      other.classList.toggle('dropdown-option-selected', on);
    });

    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }));
  }
}
