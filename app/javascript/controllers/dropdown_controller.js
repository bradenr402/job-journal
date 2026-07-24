import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ['menu', 'trigger'];
  static classes = ['showDropdown', 'hideDropdown'];

  connect() {
    this.outsideClickListener = this.handleOutsideClick.bind(this);
    this.menuKeydownListener = this.handleMenuKeydown.bind(this);

    if (this.menuTarget.classList.contains(this.hideDropdownClass)) {
      this.menuTarget.inert = true;
    }
  }

  toggle() {
    if (this.menuTarget.classList.contains(this.showDropdownClass)) this.close();
    else this.open();
  }

  open() {
    this.menuTarget.classList.add(this.showDropdownClass);
    this.menuTarget.classList.remove(this.hideDropdownClass);
    this.menuTarget.inert = false;

    document.addEventListener('mousedown', this.outsideClickListener);
    document.addEventListener('keydown', this.menuKeydownListener);

    this.options = [...this.menuTarget.querySelectorAll('.dropdown-option')];
    this.selectedIndex = 0;
    this.focusOption();
  }

  close() {
    this.menuTarget.classList.add(this.hideDropdownClass);
    this.menuTarget.classList.remove(this.showDropdownClass);
    this.menuTarget.inert = true;

    document.removeEventListener('mousedown', this.outsideClickListener);
    document.removeEventListener('keydown', this.menuKeydownListener);

    this.selectedIndex = null;
  }

  handleKeydown(event) {
    switch (event.key) {
      case 'Enter':
      case ' ':
        event.preventDefault();
        this.toggle();
        break;
    }
  }

  handleMenuKeydown(event) {
    if (!this.menuTarget.classList.contains(this.showDropdownClass)) return;

    switch (event.key) {
      case 'Escape':
        this.close();
        this.triggerTarget.focus();
        break;
      case 'ArrowDown':
        event.preventDefault();
        this.moveSelection(1);
        break;
      case 'ArrowUp':
        event.preventDefault();
        this.moveSelection(-1);
        break;
      case 'Tab':
      event.preventDefault();
        if (event.shiftKey) this.moveSelection(-1);
        else this.moveSelection(1);
        break;
    }
  }

  moveSelection(direction) {
    this.selectedIndex = Math.min(
      Math.max(this.selectedIndex + direction, 0),
      this.options.length - 1
    );

    this.focusOption();
  }

  focusOption() {
    this.options[this.selectedIndex]?.focus();
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close();
  }
}
