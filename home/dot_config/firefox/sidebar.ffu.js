// ==UserScript==
// @pref personal.dotfiles.sidebar
// @name Dotfiles Sidebery layout
// @include main
// ==/UserScript==
(() => {
  const { AddonManager } = ChromeUtils.importESModule('resource://gre/modules/AddonManager.sys.mjs');
  const id = '{3c078156-979c-498b-8990-85f7987dd929}';
  const root = document.documentElement;
  async function update() {
    const addon = await AddonManager.getAddonByID(id);
    root.toggleAttribute('data-dotfiles-sidebery', Boolean(addon?.isActive));
    if (addon?.isActive) root.setAttribute('data-dotfiles-sidebery', 'true');
  }
  const listener = { onEnabled: update, onDisabled: update, onInstalled: update, onUninstalled: update };
  AddonManager.addAddonListener(listener);
  update();
  const cleanup = () => {
    AddonManager.removeAddonListener(listener);
    root.removeAttribute('data-dotfiles-sidebery');
  };
  window.ffuDisableScript?.(cleanup);
  window.addEventListener('unload', cleanup, { once: true });
})();
