import { randomUUID } from "node:crypto";

export function browserError(code) {
  return Object.assign(new Error(code), { code });
}

function observeDocument(request) {
  let truncated = false;
  const bounded = (value, max = 500) => {
    const text = String(value ?? "").replace(/\s+/g, " ").trim();
    if (text.length > max) truncated = true;
    return text.slice(0, max);
  };
  const rawValue = (value) => {
    const text = String(value ?? "");
    if (text.length > 1000) truncated = true;
    return text.slice(0, 1000);
  };
  const empty = (blocked) => ({
    url: location.href, documentId: "", text: "", truncated: false, blocked, focused: false,
    controls: [], checks: [], scroll: { x: 0, y: 0, maxX: 0, maxY: 0 },
  });
  if (!request.origins.includes(location.origin)) return empty("origin_mismatch");
  const visible = (node) => {
    if (!(node instanceof Element) || !node.isConnected || node.closest("[hidden],[inert]")) return false;
    const style = getComputedStyle(node);
    return style.display !== "none" && style.visibility !== "hidden"
      && style.visibility !== "collapse" && node.getClientRects().length > 0;
  };
  const sensitive = (node) => /^(password|email|tel|file|hidden)$/i.test(node.type ?? "")
    || /(?:password|one-time-code|cc-|webauthn)/i.test(node.getAttribute("autocomplete") ?? "");
  if ([...document.querySelectorAll('input[type="password"],input[autocomplete="one-time-code"]')].some(visible)) {
    return empty("login_required");
  }
  if ([...document.querySelectorAll('iframe[src*="recaptcha"],iframe[src*="hcaptcha"],iframe[src*="challenges.cloudflare"],.g-recaptcha,.h-captcha')].some(visible)) {
    return empty("captcha_required");
  }
  const key = Symbol.for(request.stateKey);
  let state = globalThis[key];
  if (!state) {
    state = { document, id: request.documentNonce, nodes: new WeakMap(), next: 0 };
    Object.defineProperty(globalThis, key, { value: state, configurable: true });
  }
  if (state.document !== document || !(state.nodes instanceof WeakMap) || typeof state.id !== "string") {
    return empty("observer_state_invalid");
  }
  const tokenFor = (node) => {
    if (!state.nodes.has(node)) state.nodes.set(node, `${state.id}:${++state.next}`);
    return state.nodes.get(node);
  };
  const labelFor = (node) => {
    const labelledBy = (node.getAttribute("aria-labelledby") ?? "").split(/\s+/)
      .map((id) => document.getElementById(id)?.textContent ?? "").join(" ").trim();
    return bounded(node.getAttribute("aria-label") || labelledBy
      || [...(node.labels ?? [])].map((label) => label.textContent).join(" ")
      || (node.matches("input,textarea,select") ? node.getAttribute("placeholder") : node.textContent)
      || node.getAttribute("title") || "");
  };
  const controlState = (node, tag) => {
    const options = tag === "select" ? [...node.options].map(option => ({
      value: rawValue(option.value), label: bounded(option.label),
      disabled: Boolean(option.disabled || option.parentElement?.disabled), selected: option.selected,
    })) : [];
    if (options.length > 100) truncated = true;
    return {
      options: options.slice(0, 100),
      value: /^(input|textarea|select)$/.test(tag) ? rawValue(node.value) : "",
      checked: typeof node.checked === "boolean" ? node.checked : null,
      href: tag === "a" ? bounded(node.href, 2048) : "",
    };
  };
  const controls = [];
  const explicitNodes = new Set();
  try {
    for (const [scopeIndex, spec] of request.controls.entries()) {
      const matches = document.querySelectorAll(spec.selector);
      if (matches.length > 1) return empty("ambiguous_target");
      if (!matches.length) continue;
      const node = matches[0];
      explicitNodes.add(node);
      if (sensitive(node)) return empty("sensitive_field");
      const tag = node.tagName.toLowerCase();
      const type = String(node.type ?? "").toLowerCase();
      if (node.isContentEditable || tag === "iframe" || node.shadowRoot
          || (spec.operations.includes("FILL") && (!/^(input|textarea)$/.test(tag)
            || (tag === "input" && !/^(text|search|url|number|date|datetime-local|month|week|time|color|range)$/.test(type))))
          || (spec.operations.includes("CHECK") && !(tag === "input" && /^(checkbox|radio)$/.test(type)))
          || (spec.operations.includes("SELECT") && tag !== "select")) return empty("unsupported_control");
      const label = labelFor(node);
      const role = bounded(node.getAttribute("role") || ({ a: "link", button: "button", select: "combobox", textarea: "textbox" }[tag])
        || (tag === "input" ? (/^(checkbox|radio)$/.test(type) ? type : "textbox") : tag), 100);
      const { options, value, checked, href } = controlState(node, tag);
      const descriptor = {
        tag, type, role, label, href, id: bounded(node.id), name: bounded(node.getAttribute("name")),
        formAction: bounded(node.form?.action ?? "", 2048), formMethod: bounded(node.form?.method ?? ""),
        readOnly: Boolean(node.readOnly), multiple: Boolean(node.multiple),
      };
      controls.push({
        scopeIndex, selector: spec.selector, token: tokenFor(node),
        fingerprint: JSON.stringify({ ...descriptor, value, checked, options }),
        visible: visible(node), disabled: Boolean(node.disabled || node.readOnly || node.closest('[aria-disabled="true"],fieldset[disabled]')),
        tag, type, role, label, href,
        value, checked,
        options,
      });
    }
    if (request.discover) {
      const selectorFor = (node) => {
        if (node.id && /^[a-zA-Z][a-zA-Z0-9_-]*$/.test(node.id)) {
          const idSelector = `#${node.id}`;
          if (document.querySelectorAll(idSelector).length === 1) return idSelector;
        }
        const parts = [];
        for (let element = node; element && element instanceof Element; element = element.parentElement) {
          const tag = element.tagName.toLowerCase();
          const siblings = element.parentElement
            ? [...element.parentElement.children].filter(sibling => sibling.tagName === element.tagName) : [element];
          parts.unshift(`${tag}:nth-of-type(${siblings.indexOf(element) + 1})`);
        }
        return parts.join(" > ");
      };
      const safeButton = (node, label) => {
        if (node.form) return null;
        if (/^(?:show |hide |open )?filters?(?: results)?$/i.test(label)) return "disclosure";
        if (/^(?:next|previous) page$/i.test(label)) return "pagination";
        return null;
      };
      const candidates = document.querySelectorAll("a[href],button,input,textarea,select");
      if (candidates.length > 240) return empty("discovery_limit");
      for (const node of candidates) {
        if (explicitNodes.has(node) || !visible(node) || sensitive(node)) continue;
        const tag = node.tagName.toLowerCase();
        const type = String(node.type ?? "").toLowerCase();
        const label = labelFor(node);
        let discoveryKind;
        if (node.isContentEditable || node.shadowRoot) continue;
        if (tag === "a" && node.href && !node.hasAttribute("download")
          && (!node.target || node.target === "_self")) discoveryKind = "link";
        else if (tag === "button") discoveryKind = safeButton(node, label);
        else if (tag === "input" && ["checkbox", "radio"].includes(type)) discoveryKind = type;
        else if (tag === "input" && ["text", "search", "url"].includes(type)) discoveryKind = "fill";
        else if (tag === "textarea") discoveryKind = "fill";
        else if (tag === "select") discoveryKind = "select";
        if (!discoveryKind || node.disabled || node.readOnly || node.closest('[aria-disabled="true"],fieldset[disabled]')) continue;
        const selector = selectorFor(node);
        if (!selector || document.querySelectorAll(selector).length !== 1 || document.querySelector(selector) !== node) continue;
        const token = tokenFor(node);
        const { options, value, checked, href } = controlState(node, tag);
        const id = bounded(node.id);
        const name = bounded(node.getAttribute("name"));
        const placeholder = bounded(node.getAttribute("placeholder"));
        const expandedValue = node.getAttribute("aria-expanded");
        const expanded = expandedValue === null ? null : bounded(expandedValue, 20);
        controls.push({
          scopeIndex: 1000 + Number(token.split(":").at(-1)), selector, token,
          fingerprint: JSON.stringify({ tag, type, label, href, id, name, placeholder, expanded, value, checked, options }),
          discoveryKind, visible: true, disabled: false, tag, type,
          role: { a: "link", button: "button", select: "combobox", textarea: "textbox" }[tag]
            || (discoveryKind === "fill" ? "textbox" : discoveryKind),
          label, href, id, name, placeholder, expanded, value, checked, options,
        });
        if (controls.length > 120) return empty("discovery_limit");
      }
    }
    const checks = request.checks.map((check, index) => {
      if (check.property === "url") return { index, matched: location.href === check.equals };
      const matches = document.querySelectorAll(check.selector);
      if (matches.length !== 1) return { index, matched: matches.length === 0 && check.property === "visible" && check.equals === false };
      const node = matches[0];
      if (sensitive(node)) return { index, matched: false };
      if (check.property !== "visible" && !visible(node)) return { index, matched: false };
      let value;
      if (check.property === "visible") value = visible(node);
      else if (check.property === "text") value = bounded(node.innerText ?? node.textContent, 12000);
      else if (check.property === "value") value = String(node.value ?? "");
      else if (check.property === "checked") value = node.checked;
      return { index, matched: value === check.equals };
    });
    let text = "";
    const walker = document.createTreeWalker(document.body ?? document.documentElement, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const parent = walker.currentNode.parentElement;
      if (!parent || parent.closest("script,style,noscript,input,textarea,select,[contenteditable]") || !visible(parent)) continue;
      const fragment = walker.currentNode.textContent.replace(/\s+/g, " ").trim();
      if (!fragment) continue;
      text += `${text ? " " : ""}${fragment}`;
      if (text.length > 12000) { truncated = true; text = text.slice(0, 12000); break; }
    }
    const scrolling = document.scrollingElement ?? document.documentElement;
    return {
      url: location.href, documentId: state.id, text, truncated, controls, checks, focused: document.hasFocus(),
      scroll: { x: scrollX, y: scrollY, maxX: Math.max(0, scrolling.scrollWidth - innerWidth), maxY: Math.max(0, scrolling.scrollHeight - innerHeight) },
    };
  } catch {
    return empty("invalid_selector");
  }
}

export function createObserver() {
  const stateKey = `browser-jev:${randomUUID()}`;
  return (job) => `(${observeDocument.toString()})(${JSON.stringify({
    stateKey, documentNonce: randomUUID(), origins: job.scope.origins,
    controls: job.scope.controls.map(({ selector, operations }) => ({ selector, operations })),
    discover: job.scope.discover === true,
    checks: job.checks,
  })})`;
}

export function decodeObservation(value) {
  if (typeof value === "string") {
    try { value = JSON.parse(value); } catch { throw browserError("browser_payload_invalid"); }
  }
  if (!value || typeof value !== "object" || typeof value.url !== "string"
      || typeof value.documentId !== "string" || typeof value.text !== "string"
      || typeof value.truncated !== "boolean" || typeof value.focused !== "boolean"
      || !Array.isArray(value.controls) || !Array.isArray(value.checks)
      || !value.scroll || !["x", "y", "maxX", "maxY"].every((key) => Number.isFinite(value.scroll[key]))
      || (value.blocked !== undefined && !/^[a-z_]+$/.test(value.blocked))) throw browserError("browser_payload_invalid");
  for (const control of value.controls) {
    if (!Number.isInteger(control.scopeIndex) || control.scopeIndex < 0
        || !["selector", "token", "fingerprint", "tag", "type", "role", "label", "value", "href"].every((key) => typeof control[key] === "string")
        || typeof control.visible !== "boolean" || typeof control.disabled !== "boolean"
        || !(control.checked === null || typeof control.checked === "boolean") || !Array.isArray(control.options)) throw browserError("browser_payload_invalid");
    if (control.discoveryKind !== undefined && (!["link", "disclosure", "pagination", "checkbox", "radio", "fill", "select"].includes(control.discoveryKind)
      || control.scopeIndex < 1000 || !["id", "name", "placeholder"].every(key => typeof control[key] === "string")
      || !(control.expanded === null || typeof control.expanded === "string"))) throw browserError("browser_payload_invalid");
    for (const option of control.options) {
      if (!option || typeof option.value !== "string" || typeof option.label !== "string"
          || typeof option.disabled !== "boolean" || typeof option.selected !== "boolean") throw browserError("browser_payload_invalid");
    }
  }
  for (const check of value.checks) {
    if (!Number.isInteger(check.index) || typeof check.matched !== "boolean") throw browserError("browser_payload_invalid");
  }
  return value;
}

export function actionArguments(action, orca) {
  const target = action.nativeTarget ?? action.selector;
  switch (action.operation) {
    case "CLICK": return orca ? ["click", "--element", target] : ["click", target];
    case "CHECK": return orca ? ["check", "--element", target] : ["check", target];
    case "FILL": return orca ? ["fill", "--element", target, "--value", action.value] : ["fill", target, action.value];
    case "SELECT": return orca ? ["select", "--element", target, "--value", action.value] : ["select", target, action.value];
    case "SCROLL": return orca
      ? ["scroll", "--direction", action.direction, "--amount", String(action.amount)]
      : ["scroll", action.direction, String(action.amount)];
    default: throw browserError("unsupported_operation");
  }
}
