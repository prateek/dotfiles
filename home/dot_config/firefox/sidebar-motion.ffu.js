// ==UserScript==
// @pref personal.sidebar.manualMotion
// @name Manual Sidebery slide
// @description Animate manual open and close without enabling hover autohide.
// @include main
// ==/UserScript==
(() => {
  const controller = SidebarController;
  const box = document.getElementById('sidebar-box');
  const sidebarId = '_3c078156-979c-498b-8990-85f7987dd929_-sidebar-action';
  const original = { show: controller._show, hide: controller.hide, toggle: controller.toggle };
  let motion;
  const enabled = () => !matchMedia('(prefers-reduced-motion: reduce)').matches;
  function stop() {
    if (!motion) return;
    const current = motion;
    motion = null;
    current.animation.cancel();
    current.restore();
  }
  function animate(opening, onFinish, fromWidth) {
    const visibleWidth = fromWidth ?? box.getBoundingClientRect().width;
    stop();
    const width = box.getBoundingClientRect().width;
    box.setAttribute("data-manual-motion", "true");
    const browser = controller.browser;
    const saved = [[box, 'min-width'], [box, 'overflow'], [browser, 'min-width']].map(([el, key]) => [el, key, el.style.getPropertyValue(key), el.style.getPropertyPriority(key)]);
    box.style.setProperty('min-width', '0px', 'important');
    box.style.setProperty('overflow', 'clip', 'important');
    browser.style.setProperty('min-width', width + 'px', 'important');
    const restore = () => { box.removeAttribute('data-manual-motion'); saved.forEach(([el, key, value, priority]) => value ? el.style.setProperty(key, value, priority) : el.style.removeProperty(key)); };
    const animation = box.animate({width: [visibleWidth + 'px', opening ? width + 'px' : '0px']}, {duration: opening ? 200 : 180, easing: 'cubic-bezier(.2,.7,.2,1)', fill: 'both'});
    const current = motion = {animation, restore, opening};
    animation.finished.then(() => {
      if (motion !== current) return;
      onFinish?.();
      stop();
    }).catch(() => {});
  }
  controller._show = function(commandId) {
    stop();
    const wasOpen = this.isOpen;
    const result = original.show.call(this, commandId);
    if (!wasOpen && commandId === sidebarId && enabled()) animate(true, undefined, 0);
    return result;
  };
  controller.hide = function(options) {
    if (!this.isOpen || this.currentID !== sidebarId || !enabled()) {
      stop();
      return original.hide.call(this, options);
    }
    if (!motion || motion.opening) animate(false, () => original.hide.call(this, options));
  };
  controller.toggle = function(...args) {
    if (motion && !motion.opening) {
      animate(true);
      return Promise.resolve();
    }
    return original.toggle.apply(this, args);
  };
  const cleanup = () => {
    stop();
    controller._show = original.show;
    controller.hide = original.hide;
    controller.toggle = original.toggle;
  };
  window.ffuDisableScript?.(cleanup);
  window.addEventListener('unload', cleanup, {once:true});
})();
