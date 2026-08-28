import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="merge-confirm"
//
// Renaming a tag to a name another tag already uses merges the two and deletes
// this one. That is destructive and irreversible, so warn inline while typing
// and require a confirmation before the form is submitted.
export default class extends Controller {
  static targets = ['input', 'warning', 'targetName'];
  static values = { names: Array, currentName: String };

  connect() {
    this.update();
  }

  disconnect() {
    delete this.element.dataset.turboConfirm;
  }

  update() {
    const name = this._normalize(this.inputTarget.value);
    const merging = name.length > 0 && this.namesValue.includes(name);

    if (this.hasWarningTarget) this.warningTarget.classList.toggle('hidden', !merging);
    if (merging) this.targetNameTargets.forEach((el) => (el.textContent = name));

    if (merging) {
      this.element.dataset.turboConfirm = this._confirmMessage(name);
    } else {
      delete this.element.dataset.turboConfirm;
    }
  }

  _confirmMessage(name) {
    const current = this.currentNameValue;

    return (
      `Merge the '${current}' tag into '${name}'?\n\n` +
      `Every job lead tagged '${current}' will be tagged '${name}' instead, ` +
      `and the '${current}' tag will be deleted. This can't be undone.`
    );
  }

  /**
   * Mirrors the server-side normalization of tag names (Tag `normalizes :name`).
   */
  _normalize(value) {
    return value.replace(/\s+/g, ' ').trim().toLowerCase();
  }
}
