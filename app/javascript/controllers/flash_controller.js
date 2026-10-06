import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="flash"
//
// Auto-dismisses a flash toast. Hovering or focusing it stops the timer, and
// leaving restarts the full timeout so the reader always gets the whole time.
export default class extends Controller {
  static values = { timeout: Number };

  connect() {
    this.resume();
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  pause() {
    clearTimeout(this.timer);
    this.timer = null;
  }

  resume() {
    if (this.timer || this.element.matches(':hover, :focus-within')) return;

    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue);
  }

  dismiss() {
    clearTimeout(this.timer);
    this.element.classList.add('flash-leaving');

    const animations = this.element.getAnimations();
    if (animations.length === 0) return this.element.remove();

    Promise.all(animations.map(animation => animation.finished)).then(() => this.element.remove());
  }
}
