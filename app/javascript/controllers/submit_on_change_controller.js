import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="submit-on-change"
//
// Resubmits the form through a specific submit button whenever a field changes,
// shows a busy state while the server responds (queuing any new submission and
// sending it once the current response lands, so responses can't arrive out of
// order), and restores focus to the row that was being edited after a morph.
export default class extends Controller {
  static targets = ['submitter'];

  connect() {
    this.element.addEventListener('submit', this.queueWhileBusy);
    this.element.addEventListener('submit', this.scopeToRow);
    this.element.addEventListener('keydown', this.submitRowOnEnter);
    this.element.addEventListener('turbo:submit-start', this.start);
    this.element.addEventListener('turbo:submit-end', this.end);
    document.addEventListener('turbo:before-stream-render', this.queueFocus);
    this.element.addEventListener('pointerdown', this.notePointer);
    this.element.addEventListener('keydown', this.noteKeyboard);
  }

  disconnect() {
    this.element.removeEventListener('pointerdown', this.notePointer);
    this.element.removeEventListener('keydown', this.noteKeyboard);
    this.element.removeEventListener('submit', this.queueWhileBusy);
    this.element.removeEventListener('submit', this.scopeToRow);
    this.element.removeEventListener('keydown', this.submitRowOnEnter);
    this.element.removeEventListener('turbo:submit-start', this.start);
    this.element.removeEventListener('turbo:submit-end', this.end);
    document.removeEventListener('turbo:before-stream-render', this.queueFocus);
  }

  notePointer = () => (this.viaKeyboard = false);
  noteKeyboard = () => (this.viaKeyboard = true);

  rememberOpen(event) {
    const input = document.getElementById('show_unmatched');
    if (input) input.value = event.target.open ? '1' : '0';
  }

  submit() {
    this.element.requestSubmit(this.submitterTarget);
  }

  // A column can feed only one field (and a field can come from only one column),
  // so clear the same choice from any other select in the same view.
  exclusive(event) {
    const select = event.target;
    if (select.value === '') return;

    const prefix = select.name.slice(0, select.name.indexOf('['));
    // Matches both native selects and the dropdown component's hidden inputs.
    this.element
      .querySelectorAll(`select[name^='${prefix}['], input[type=hidden][name^='${prefix}[']`)
      .forEach((other) => {
        if (other !== select && other.value === select.value) other.value = '';
      });
  }

  // While a refresh is running, hold the newest submission and send it once the
  // response lands, so no change is lost and responses can't arrive out of order.
  // Enter in a row's fix field submits that row only, through its own primary button.
  submitRowOnEnter = (event) => {
    if (event.key !== 'Enter' || event.target.tagName !== 'INPUT') return;

    const row = event.target.closest("li[id^='import-row-']");
    if (!row) return;

    event.preventDefault();
    const button = row.querySelector('button.btn-primary[type=submit]');
    this.element.requestSubmit(button || this.submitterTarget);
  };

  // A button inside a row sends only that row's fields, so half-typed fixes in
  // other rows aren't applied. Turbo reads the form right after this listener runs.
  scopeToRow = (event) => {
    const row = event.submitter?.closest("li[id^='import-row-']");
    if (!row || event.defaultPrevented) return;

    const others = [...this.element.querySelectorAll("[name^='rows[']")].filter(
      (field) => !row.contains(field) && !field.disabled
    );
    others.forEach((field) => (field.disabled = true));
    setTimeout(() => others.forEach((field) => (field.disabled = false)));
  };

  queueWhileBusy = (event) => {
    if (this.element.getAttribute('aria-busy') !== 'true') return;

    event.preventDefault();
    event.stopImmediatePropagation();

    // An import is already on its way; a second one would only find it finished.
    if (this.inFlight?.value === 'import') return;

    // Keep the button's name and value too, since the refresh may remove the button.
    const submitter = event.submitter || this.submitterTarget;
    this.pending = { element: submitter, name: submitter.name, value: submitter.value };
  };

  start = (event) => {
    clearTimeout(this.clearTimer);
    this.inFlight = event.detail.formSubmission?.submitter;
    const source = event.detail.formSubmission?.submitter || document.activeElement;
    this.focusRowId = source?.closest?.("li[id^='import-row-']")?.id;
    this.focusFieldId = document.activeElement?.id || null;
    this.element.setAttribute('aria-busy', 'true');

    const status = document.getElementById('import-status');
    if (status) status.textContent = '';
  };

  end = (event) => {
    this.element.removeAttribute('aria-busy');
    this.inFlight = null;

    // The page is about to change (or the request failed), so drop anything queued.
    if (!event.detail.success || event.detail.fetchResponse?.redirected) this.pending = null;
    // Fallback for responses that don't render a stream (e.g. redirects).
    this.clearTimer = setTimeout(() => (this.focusRowId = this.focusFieldId = null), 1000);

    if (this.pending) {
      const pending = this.pending;
      this.pending = null;
      requestAnimationFrame(() => this.#resubmit(pending));
    }
  };

  #resubmit({ element, name, value }) {
    if (element.isConnected && element.form === this.element) return this.element.requestSubmit(element);

    const input = name && Object.assign(document.createElement('input'), { type: 'hidden', name, value });
    if (input) this.element.append(input);
    this.element.requestSubmit(this.submitterTarget);
    input?.remove();
  }

  // Turbo renders stream actions a frame after this event, so wrap the render
  // and move focus only once the last action in the response has been applied.
  queueFocus = (event) => {
    if (!['import-body', 'import-columns', 'import-footer'].includes(event.target.target)) return;

    const render = event.detail.render;
    // Animate the main content so named rows slide when they move, collapse, or expand.
    // Large files skip it, since snapshotting hundreds of named rows is slow.
    const animate =
      event.target.target !== 'import-footer' &&
      document.startViewTransition &&
      document.querySelectorAll('[id^="import-row-"], [style*="import-column-"]').length <= 200 &&
      !matchMedia('(prefers-reduced-motion: reduce)').matches;

    event.detail.render = async (element) => {
      if (animate) await document.startViewTransition(() => render(element)).updateCallbackDone;
      else await render(element);
      cancelAnimationFrame(this.focusFrame);
      this.focusFrame = requestAnimationFrame(() => this.restoreFocus());
    };
  };

  // Put focus back where the user was: the same field, else the row (it may have
  // moved to Ready to Import), else the summary heading.
  restoreFocus() {
    const fieldId = this.focusFieldId;
    const rowId = this.focusRowId;
    this.focusRowId = this.focusFieldId = null;

    if (!fieldId && !rowId) return;
    if (document.activeElement && document.activeElement !== document.body) return;

    let target = (fieldId && document.getElementById(fieldId)) || (rowId && document.getElementById(rowId));
    target?.closest('details')?.setAttribute('open', '');
    if (!target || !target.checkVisibility?.()) target = document.getElementById('import-summary-heading');

    // Only show a ring on the restored element for keyboard users.
    target?.focus({ focusVisible: !!this.viaKeyboard });
  }
}
