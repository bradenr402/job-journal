import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['tab', 'panel'];
  static values = { active: String, param: { type: String, default: 'tab' } };

  connect() {
    if (!this.activeValue && this.hasTabTarget) this.activeValue = this.tabTargets[0].dataset.tabsId;
    this.initialized = true;
  }

  select(event) {
    this.activeValue = event.currentTarget.dataset.tabsId;
  }

  navigate(event) {
    const handledKeys = ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End'];
    if (!handledKeys.includes(event.key)) return;
    event.preventDefault();

    const tabs = this.tabTargets;
    const currentIndex = tabs.findIndex((tab) => tab.dataset.tabsId === this.activeValue);
    let nextIndex;

    if (event.key === 'Home') nextIndex = 0;
    else if (event.key === 'End') nextIndex = tabs.length - 1;
    else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') nextIndex = (currentIndex - 1 + tabs.length) % tabs.length;
    else nextIndex = (currentIndex + 1) % tabs.length;

    this.activeValue = tabs[nextIndex].dataset.tabsId;
    tabs[nextIndex].focus();
  }

  activeValueChanged() {
    if (!this.activeValue) return;

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabsId === this.activeValue;
      tab.setAttribute('aria-selected', active);
      tab.tabIndex = active ? 0 : -1;
    });

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle('hidden', panel.dataset.tabsId !== this.activeValue);
    });

    if (this.initialized) this.updateUrl();
  }

  updateUrl() {
    const url = new URL(window.location);
    url.searchParams.set(this.paramValue, this.activeValue);
    history.replaceState({}, '', url);
  }
}
