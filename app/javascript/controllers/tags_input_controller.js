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
    const selectedTags = new Set(this.tags);
    document
      .querySelectorAll('[data-action="click->tags-input#addTagFromList"]')
      .forEach((chip) => {
        const value = chip.dataset.value?.toLowerCase();
        chip.classList.toggle('hidden', selectedTags.has(value));
      });

    // Remove all existing chips
    this.containerTarget.querySelectorAll('.tag-chip').forEach((el) => el.remove());

    // Render each tag as a chip before the input
    this.tags.forEach((tag) => {
      const chip = document.createElement('span');
      chip.className = 'tag-chip';
      chip.style.viewTransitionName = `tag-${this._parameterize(tag)}`;
      chip.dataset.action = 'click->tags-input#removeTag';
      chip.dataset.value = tag;

      const label = document.createElement('span');
      label.textContent = tag;

      const button = document.createElement('button');
      button.type = 'button';
      button.insertAdjacentHTML("beforeend", window.JobJournal.icons['x-mini'] || '');

      chip.insertAdjacentHTML("beforeend", window.JobJournal.icons['tag'] || '');
      chip.append(label, button);

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

  addTags(values) {
    const incoming = (Array.isArray(values) ? values : [values])
      .map((v) => String(v).trim().toLowerCase())
      .filter((v) => v.length > 0);

    let added = 0;
    incoming.forEach((value) => {
      if (!this.tags.includes(value)) {
        this.tags.push(value);
        added += 1;
      }
    });

    if (added > 0) this.renderTags();
    return added;
  }

  clearTags() {
    if (this.tags.length === 0) return;
    this.tags = [];
    this.renderTags();
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
