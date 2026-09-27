import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../../agent-marketplace/packages/utils-agent/skills/browser/scripts/fill-input.js', import.meta.url), 'utf8');

function page({ nested = true, type = 'text' } = {}) {
  const events = [];
  let result = '';
  class Input {
    constructor() { this.type = type; this._value = ''; this.disabled = false; this.readOnly = false; }
    get value() { return this._value; }
    set value(value) { this._value = value; }
    matches(selector) { return selector === '#field'; }
    focus() { events.push('focus'); document.activeElement = nested ? host : input; if (nested) shadow.activeElement = input; }
    dispatchEvent(event) {
      events.push(event.type);
      if (event.type === 'keyup' && event.key === 'Enter' && this.value === 'Kitchen') result = 'Kitchen selected';
    }
  }
  const input = new Input();
  const shadow = { querySelectorAll: () => [input], activeElement: null };
  const host = { matches: () => false, shadowRoot: nested ? shadow : null };
  const document = { querySelectorAll: () => nested ? [host] : [input], activeElement: null };
  class Event { constructor(type) { this.type = type; } }
  class KeyboardEvent extends Event { constructor(type, options) { super(type); this.key = options.key; } }
  const context = vm.createContext({ location: { origin: 'https://example.test' }, document, HTMLInputElement: Input, Event, KeyboardEvent, TextEncoder, crypto: webcrypto });
  vm.runInContext(source, context);
  return { context, input, events, get result() { return result; } };
}

test('nested shadow input checks focus and digest before Enter for app state', async () => {
  const app = page();
  assert.equal(vm.runInContext('prepareInput("https://example.test", "#field", "text")', app.context), true);
  app.input.value = 'Kitchen';
  assert.equal(await vm.runInContext('inputDigest("https://example.test", "#field", "text", "salt")', app.context), createHash('sha256').update('saltKitchen').digest('hex'));
  assert.equal(vm.runInContext('finishInput("https://example.test", "#field", "text", true)', app.context), true);
  assert.equal(app.input.value, 'Kitchen');
  assert.equal(app.result, 'Kitchen selected');
  assert.deepEqual(app.events, ['focus', 'input', 'change', 'keyup']);
});

test('password preparation leaves submission to caller and checks origin and type', () => {
  const app = page({ type: 'password' });
  assert.equal(vm.runInContext('prepareInput("https://example.test", "#field", "password")', app.context), true);
  assert.deepEqual(app.events, ['focus']);
  assert.equal(vm.runInContext('prepareInput("https://wrong.test", "#field", "password")', app.context), false);
  assert.equal(vm.runInContext('prepareInput("https://example.test", "#field", "text")', app.context), false);
});
