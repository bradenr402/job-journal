import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="credentials-confirm"
//
// Reveals the current password field only when the email address or password
// is being changed, since those are the only edits that require it.
export default class extends Controller {
  static targets = ['email', 'password', 'confirmation', 'currentPassword'];
  static values = { savedEmail: String, forceVisible: Boolean };

  connect() {
    this.update();
  }

  update() {
    const emailChanged = this.emailTarget.value.trim().toLowerCase() !== this.savedEmailValue.toLowerCase();
    const passwordChanged = this.passwordTarget.value !== '';
    const needed = emailChanged || passwordChanged || this.forceVisibleValue;

    this.confirmationTarget.hidden = !needed;
    this.currentPasswordTarget.required = needed;
  }
}
