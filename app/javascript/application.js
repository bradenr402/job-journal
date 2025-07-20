// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import '@hotwired/turbo-rails';
import 'controllers';

import LocalTime from 'local-time';
LocalTime.start();
document.addEventListener('turbo:morph', () => {
  LocalTime.run();
});

// Temporarily disables all transitions
const disableTransitionsTemporarily = () => {
  const css = document.createElement('style');
  css.appendChild(
    document.createTextNode(
      `* {
        -webkit-transition: none !important;
        -moz-transition: none !important;
        -o-transition: none !important;
        -ms-transition: none !important;
        transition: none !important;
      }`,
    ),
  );
  document.head.appendChild(css);

  // Force browser to apply the style
  const _ = window.getComputedStyle(css).opacity;

  // Remove the style after the theme has changed
  document.head.removeChild(css);
};

// Listen for system theme changes and disable transitions during the theme switch
window
  .matchMedia('(prefers-color-scheme: dark)')
  .addEventListener('change', () => disableTransitionsTemporarily());
