import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="file-drop"
//
// A large drop area wrapping a transparent file input. The input covers the
// whole area, so clicking and native drag and drop both work; this controller
// adds the drag highlight and shows the chosen file.
export default class extends Controller {
  static targets = ['input', 'empty', 'selected', 'name', 'size'];
  static classes = ['dragging'];
  static values = { autoSubmit: Boolean };

  connect() {
    this.update();
  }

  dragenter() {
    this.element.classList.add(...this.draggingClasses);
  }

  dragleave(event) {
    if (!this.element.contains(event.relatedTarget)) this.element.classList.remove(...this.draggingClasses);
  }

  drop() {
    this.element.classList.remove(...this.draggingClasses);
  }

  update() {
    const file = this.inputTarget.files[0];

    this.emptyTarget.hidden = !!file;
    this.selectedTarget.hidden = !file;
    if (!file) return;

    this.nameTarget.textContent = file.name;
    this.sizeTarget.textContent = `${this.#formatSize(file.size)} · Reading…`;
    if (this.autoSubmitValue) this.inputTarget.form.requestSubmit();
  }

  clear(event) {
    event.preventDefault();
    this.inputTarget.value = '';
    this.update();
  }

  #formatSize(bytes) {
    return bytes < 1024
      ? `${bytes} B`
      : bytes < 1024 ** 2
        ? `${(bytes / 1024).toFixed(1)} KB`
        : `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  }
}
