import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="conditional-field"
export default class extends Controller {
  static targets = [];

  connect() {
    this.toggleAllFields();
  }

  toggleAllFields() {
    this.element.querySelectorAll('[data-conditional-field-checkbox]').forEach((checkbox) => {
      const fieldSelector = checkbox.dataset.conditionalFieldCheckbox;
      const field = this.element.querySelector(`[data-conditional-field-input='${fieldSelector}']`);
      if (field) {
        field.classList.toggle('hidden', !checkbox.checked);
      }
    });
  }

  toggleField(event) {
    const checkbox = event.target;
    const fieldSelector = checkbox.dataset.conditionalFieldCheckbox;
    const field = this.element.querySelector(`[data-conditional-field-input='${fieldSelector}']`);
    if (field) {
      field.classList.toggle('hidden', !checkbox.checked);
    }
  }
}
