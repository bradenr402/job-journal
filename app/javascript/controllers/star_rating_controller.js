import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="star-rating"
export default class extends Controller {
  static targets = ['star', 'label', 'radio'];

  static values = {
    initial: Number,
  };

  connect() {
    console.log('connect');
    

    this.selected = this.initialValue || 0;
    this.highlight(this.selected);
  }

  select(event) {
    const value = parseInt(event.target.value, 10);
    this.selected = value;
    this.highlight(this.selected);
  }

  clear() {
    this.selected = 0;
    this.highlight(this.selected);

    const radioButtons = this.radioTargets;
    radioButtons.forEach(radio => {
      radio.checked = false;
    });
  }

  highlight(upto, hover = false) {
    this.starTargets.forEach((star, i) => {
      if (i < upto) {
        star.classList.add('text-yellow-400', 'fill-yellow-400');
        star.classList.remove('text-muted', 'fill-transparent');
      } else {
        star.classList.add('text-muted', 'fill-transparent');
        star.classList.remove('text-yellow-400', 'fill-yellow-400');
      }
    });
  }

  hoverIn(event) {
    const index = this.labelTargets.indexOf(event.currentTarget);
    this.highlight(index + 1, true);
  }

  hoverOut() {
    this.highlight(this.selected);
  }
}
