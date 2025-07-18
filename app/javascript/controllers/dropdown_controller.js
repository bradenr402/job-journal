import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ['menu'];
  static classes = ['showDropdown', 'hideDropdown'];

  connect() {
    this.outsideClickListener = this.handleOutsideClick.bind(this);
    if (this.menuTarget.classList.contains(this.hideDropdownClass)) this.menuTarget.inert = true;
  }

  toggle() {
    if (this.menuTarget.classList.contains(this.showDropdownClass)) this.close();
    else this.open();
  }

  handleKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') this.toggle();
  }

  open() {
    this.menuTarget.classList.add(this.showDropdownClass);
    this.menuTarget.classList.remove(this.hideDropdownClass);
    this.menuTarget.inert = false;

    document.addEventListener('mousedown', this.outsideClickListener);
    document.addEventListener('keydown', this.handleEscape);
  }

  close() {
    this.menuTarget.classList.add(this.hideDropdownClass);
    this.menuTarget.classList.remove(this.showDropdownClass);
    this.menuTarget.inert = true;

    document.removeEventListener('mousedown', this.outsideClickListener);
    document.removeEventListener('keydown', this.handleEscape);
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close();
  }

  handleEscape(event) {
    if (event.key === 'Escape') this.close();
  }
}
