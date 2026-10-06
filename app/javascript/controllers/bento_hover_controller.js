import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="bento-hover"
//
// Plays a tile's `bento-hover-*` animations on hover and lets them finish even
// if the pointer leaves first. Tiles with `bento-leave-*` animations hold the
// hover animation's end state until the pointer leaves, then play those.
export default class extends Controller {
  static classes = ['playing', 'leaving'];

  async play({ currentTarget: tile, pointerType }) {
    // Taps fire pointer events too; animations are a hover nicety only
    if (pointerType !== 'mouse' || tile.dataset.bentoBusy) return;
    tile.dataset.bentoBusy = 'true';

    tile.classList.add(this.playingClass);
    await this.#finished(tile);

    if (tile.querySelector('[class*="bento-leave-"]')) {
      if (tile.matches(':hover')) {
        await new Promise((resolve) => tile.addEventListener('mouseleave', resolve, { once: true }));
      }

      tile.classList.replace(this.playingClass, this.leavingClass);
      await this.#finished(tile);
      tile.classList.remove(this.leavingClass);
    } else {
      tile.classList.remove(this.playingClass);
    }

    delete tile.dataset.bentoBusy;
  }

  // Only wait on our own finite animations; hover transitions inside real partials and
  // `bento-while-hover-*` loops can outlive the hover
  #finished(tile) {
    const animations = tile.getAnimations({ subtree: true }).filter((animation) =>
      animation.animationName?.startsWith('bento-') && animation.effect.getComputedTiming().iterations !== Infinity
    );
    return Promise.allSettled(animations.map((animation) => animation.finished));
  }
}
