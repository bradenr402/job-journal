import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="url-autofill"
export default class extends Controller {
  static targets = ["url", "submit", "status", "message"];
  static classes = ["error", "info"];
  static outlets = ["tags-input"];
  static values = {
    url: String,
    submitText: { type: String, default: "Autofill from URL" },
    workingText: { type: String, default: "Working…" },
  };

  async submit(event) {
    event?.preventDefault();

    const url = this.urlTarget.value.trim();
    if (!url) return;

    this._setBusy(true);
    this._showStatus("Fetching the page — please don’t navigate away…", "info");

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this._csrfToken(),
        },
        body: JSON.stringify({ url }),
      });

      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        this._showStatus(
          data.error || "Could not autofill from that URL.",
          "error",
        );
        return;
      }

      this._clearFields();
      const filled = this._applyFields(data.fields || {});
      this._showStatus(
        filled > 0
          ? `Filled ${filled} ${filled === 1 ? "field" : "fields"} from the page.`
          : "No matching fields found.",
        filled > 0 ? "info" : "error",
      );
    } catch (error) {
      console.error(error);
      this._showStatus("Network error — please try again.", "error");
    } finally {
      this._setBusy(false);
    }
  }

  // --- private ---------------------------------------------------------------

  _clearFields() {
    document
      .querySelectorAll('[name^="job_lead["]')
      .forEach((input) => {
        if (input.type === "checkbox" || input.type === "radio") {
          input.checked = false;
        } else {
          input.value = "";
        }
        input.dispatchEvent(new Event("input", { bubbles: true }));
        input.dispatchEvent(new Event("change", { bubbles: true }));
      });

    if (this.hasTagsInputOutlet) this.tagsInputOutlet.clearTags();
  }

  _applyFields(fields) {
    let filled = 0;
    for (const [key, value] of Object.entries(fields)) {
      if (value == null || value === "") continue;

      if (key === "tags" && this.hasTagsInputOutlet) {
        const added = this.tagsInputOutlet.addTags(value);
        if (added > 0) filled++;
        continue;
      }

      const input = document.querySelector(`[name="job_lead[${key}]"]`);
      if (!input) continue;

      input.value = value;
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
      filled += 1;
    }
    return filled;
  }

  _setBusy(busy) {
    if (!this.hasSubmitTarget) return;

    this.submitTarget.disabled = busy;
    this.submitTarget.setAttribute("aria-busy", busy.toString());
    this.submitTarget.textContent = busy
      ? this.workingTextValue
      : this.submitTextValue;
  }

  _showStatus(message, kind) {
    if (!this.hasStatusTarget) return;

    const isError = kind === "error";
    this.statusTarget.classList.remove("hidden");
    this.errorClasses.forEach((c) =>
      this.statusTarget.classList.toggle(c, isError),
    );
    this.infoClasses.forEach((c) =>
      this.statusTarget.classList.toggle(c, !isError),
    );

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = message;
    } else {
      this.statusTarget.textContent = message;
    }
  }

  _csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || "";
  }
}
