import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="email-handoff"
//
// Carries the typed email address to linked auth pages so it isn't typed twice.
export default class extends Controller {
  static targets = ['email'];

  carry(event) {
    const email = this.emailTarget.value.trim();
    if (email === '') return;

    const url = new URL(event.currentTarget.href);
    url.searchParams.set('email_address', email);
    event.currentTarget.href = url.toString();
  }
}
