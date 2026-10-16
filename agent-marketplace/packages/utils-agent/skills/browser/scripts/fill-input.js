function findInput(origin, selector, expectedType) {
  if (location.origin !== origin) return null;
  const matches = [];
  function visit(root) {
    for (const node of root.querySelectorAll('*')) {
      if (node.matches(selector)) matches.push(node);
      if (node.shadowRoot) visit(node.shadowRoot);
    }
  }
  visit(document);
  if (matches.length !== 1) return null;
  const input = matches[0];
  if (!(input instanceof HTMLInputElement) || input.type !== expectedType || input.disabled || input.readOnly) return null;
  return input;
}

function activeInput(input) {
  let active = document.activeElement;
  while (active?.shadowRoot?.activeElement) active = active.shadowRoot.activeElement;
  return active === input;
}

function prepareInput(origin, selector, expectedType) {
  const input = findInput(origin, selector, expectedType);
  if (!input) return false;
  const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  setter.call(input, '');
  input.focus();
  return activeInput(input) && input.value === '';
}

async function saltedDigest(salt, value) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(salt + value));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
}

async function inputDigest(origin, selector, expectedType, salt) {
  const input = findInput(origin, selector, expectedType);
  if (!input || !activeInput(input)) return null;
  return saltedDigest(salt, input.value);
}

// Clears every element, including shadow hosts given a stray `value` property, that holds the value.
async function scrubValue(salt, expected) {
  const nodes = [];
  (function visit(root) {
    for (const node of root.querySelectorAll('*')) {
      nodes.push(node);
      if (node.shadowRoot) visit(node.shadowRoot);
    }
  })(document);
  let cleared = 0;
  for (const node of nodes) {
    if (typeof node.value !== 'string' || node.value === '') continue;
    if (await saltedDigest(salt, node.value) !== expected) continue;
    const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(node), 'value')?.set;
    if (setter) {
      setter.call(node, '');
      node.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
      node.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
    } else {
      delete node.value;
    }
    cleared++;
  }
  return cleared;
}

function finishInput(origin, selector, expectedType, enter) {
  const input = findInput(origin, selector, expectedType);
  if (!input || !activeInput(input)) return false;
  // browser.fill already dispatched input and change.
  if (enter) input.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', bubbles: true, composed: true }));
  return true;
}
