import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="tags-input"
export default class extends Controller {
  static targets = ['container', 'input', 'hiddenField'];

  connect() {
    // Initialize tags from the hidden field value
    this.tags = this.hiddenFieldTarget.value
      .split(',')
      .map((tag) => tag.trim())
      .filter((tag) => tag.length > 0);
    this.renderTags();
  }

  /**
   * Handles keydown events in the input.
   * - Enter or comma: adds the tag if valid and not a duplicate.
   * - Backspace on empty input: removes the last tag.
   */
  handleKeydown(event) {
    if (event.key === 'Enter' || event.key === ',' || event.key === 'Tab') {
      event.preventDefault();
      const value = this.inputTarget.value.trim().toLowerCase();
      if (value && !this.tags.includes(value)) {
        this.tags.push(value);
        this.renderTags();
      }
      this.inputTarget.value = '';
    } else if (event.key === 'Backspace' && this.inputTarget.value === '') {
      // Remove last tag on backspace when input is empty
      this.tags.pop();
      this.renderTags();
    }
  }

  /**
   * Removes a tag when the 'x' button is clicked.
   */
  removeTag(event) {
    const value = event.currentTarget.dataset.value;
    this.tags = this.tags.filter((tag) => tag !== value);
    this.renderTags();
  }

  /**
   * Renders the tags as chips and updates the hidden field.
   */
  renderTags() {
    if (!document.startViewTransition) return this._renderTagsContents();
    document.startViewTransition(() => this._renderTagsContents());
  }

  _renderTagsContents() {
    // Show all suggested chips before rendering
    document
      .querySelectorAll('[data-action="click->tags-input#addTagFromList"]')
      .forEach((chip) => {
        chip.classList.remove('hidden');
      });

    // Hide suggested chips corresponding to current tags
    this.tags.forEach((tag) => {
      const suggestedChip = document.querySelector(
        `[data-action="click->tags-input#addTagFromList"][data-value="${tag}"]`,
      );
      if (suggestedChip) suggestedChip.classList.add('hidden');
    });

    // Remove all existing chips
    this.containerTarget.querySelectorAll('.tag-chip').forEach((el) => el.remove());
    // Render each tag as a chip before the input
    this.tags.forEach((tag) => {
      const chip = document.createElement('span');
      chip.className = 'tag-chip';
      chip.style.viewTransitionName = this._parameterize(tag);
      chip.dataset.action = 'click->tags-input#removeTag';
      chip.dataset.value = tag;

      chip.innerHTML = `
        <span>${tag}</span>
        <button type="button">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor">
            <path
              d="M5.28 4.22a.75.75 0 0 0-1.06 1.06L6.94 8l-2.72 2.72a.75.75 0 1 0 1.06 1.06L8 9.06l2.72 2.72a.75.75 0 1 0 1.06-1.06L9.06 8l2.72-2.72a.75.75 0 0 0-1.06-1.06L8 6.94 5.28 4.22Z"
            />
          </svg>
        </button>
      `;

      this.containerTarget.insertBefore(chip, this.inputTarget);
    });

    // Update the hidden field value as a comma-separated list
    this.hiddenFieldTarget.value = this.tags.join(', ');
  }

  addTagFromList(event) {
    const value = event.currentTarget.dataset.value.toLowerCase();
    if (value && !this.tags.includes(value)) {
      this.tags.push(value);
      this.renderTags();
    }
  }

  focusTextBox() {
    this.inputTarget.focus();
  }

  /**
   * Converts a string to a URL-friendly parameterized slug.
   * @param {string} str - The input string.
   * @param {string} [separator='-'] - The word separator.
   * @returns {string} The parameterized string.
   */
  _parameterize(str, separator = '-') {
    if (typeof str !== 'string') return '';

    // 1. Normalize to NFD and remove diacritics (accents)
    let slug = str.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

    // 2. Replace non-alphanumeric characters with the separator
    slug = slug.replace(/[^a-zA-Z0-9]+/g, separator);

    // 3. Remove leading/trailing separators
    slug = slug.replace(new RegExp(`^${separator}+|${separator}+$`, 'g'), '');

    // 4. Convert to lowercase
    return slug.toLowerCase();
  }
}
