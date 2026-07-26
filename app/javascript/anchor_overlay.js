// Injects the hover highlight (`.anchor-overlay`) into `anchor-highlight`
// containers on first hover.

// Keep in sync with the utilities that apply `anchor-highlight-base` in
// app/assets/stylesheets/custom/components.css.
const CONTAINERS = ".minimal-item-list, .nav-link-list, .tab-link-list, .dropdown-menu";

document.addEventListener("mouseover", (event) => {
  const container = event.target.closest(CONTAINERS);
  if (!container || container.querySelector(":scope > .anchor-overlay")) return;

  const overlay = document.createElement("span");
  overlay.className = "anchor-overlay";
  overlay.setAttribute("aria-hidden", "true");
  overlay.setAttribute("data-turbo-temporary", "");
  container.prepend(overlay);
});
