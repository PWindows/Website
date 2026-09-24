const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "../../assets/js/extra.js"), "utf8");
const flipSource = source.slice(0, source.indexOf("function setupArticleSorting()"));

function fixture(precise = true) {
  const deferred = [];
  const focusErrors = [];
  const document = { activeElement: null, listeners: {}, body: { dataset: { flipCardDetails: "Details for {title}" } } };
  document.addEventListener = (name, listener) => (document.listeners[name] ||= []).push(listener);

  class Element {
    constructor(name, parent = null) {
      this.name = name;
      this.parent = parent;
      this.attributes = new Map();
      this.listeners = {};
      this.classes = new Set();
      this.classList = {
        contains: (value) => this.classes.has(value),
        toggle: (value, enabled) => enabled ? this.classes.add(value) : this.classes.delete(value),
      };
    }
    contains(element) {
      return element === this || Boolean(element?.parent && this.contains(element.parent));
    }
    setAttribute(name, value) {
      if ((name === "inert" || (name === "aria-hidden" && value === "true")) && this.contains(document.activeElement)) {
        focusErrors.push(`Hid focused ${document.activeElement.name} inside ${this.name}`);
      }
      this.attributes.set(name, value);
    }
    getAttribute(name) { return this.attributes.get(name) ?? null; }
    removeAttribute(name) { this.attributes.delete(name); }
    get hidden() { return this.attributes.has("hidden"); }
    set hidden(value) { value ? this.setAttribute("hidden", "") : this.removeAttribute("hidden"); }
    get disabled() { return this.attributes.has("disabled"); }
    set disabled(value) { value ? this.setAttribute("disabled", "") : this.removeAttribute("disabled"); }
    get tabIndex() { return Number(this.getAttribute("tabindex") ?? -1); }
    set tabIndex(value) { this.setAttribute("tabindex", String(value)); }
    addEventListener(name, listener) { (this.listeners[name] ||= []).push(listener); }
    emit(name, event = {}) {
      for (const listener of this.listeners[name] || []) listener({ preventDefault() {}, ...event });
    }
    focus() {
      if (this.hidden || this.disabled) {
        focusErrors.push(`Tried to focus hidden or disabled ${this.name}`);
        return;
      }
      for (let element = this; element; element = element.parent) {
        if (element.attributes.has("inert")) {
          focusErrors.push(`Tried to focus ${this.name} inside inert ${element.name}`);
          return;
        }
      }
      const previous = document.activeElement;
      if (previous === this) return;
      document.activeElement = this;
      for (let element = previous; element; element = element.parent) element.emit("focusout");
      for (let element = this; element; element = element.parent) element.emit("focusin");
    }
  }

  const outside = new Element("outside");
  document.activeElement = outside;
  const card = new Element("card");
  const front = new Element("front", card);
  const back = new Element("back", card);
  const open = new Element("open", front);
  const close = new Element("close", back);
  const action = new Element("action", back);
  back.setAttribute("inert", "");
  const elements = {
    ".flip-card-front": front,
    ".flip-card-back": back,
    ".flip-card-toggle": open,
    ".flip-card-back-toggle": close,
    ".flip-card-title": { textContent: "Server address" },
  };
  card.querySelector = (selector) => elements[selector];
  document.querySelectorAll = () => [card];
  const media = { matches: precise, addEventListener: (_name, callback) => { media.change = callback; } };
  const window = { matchMedia: () => media, requestAnimationFrame: (callback) => deferred.push(callback) };
  const context = vm.createContext({ document, window });
  vm.runInContext(`${flipSource}\nsetupFlipCards();`, context);

  function input(name, event = {}) {
    for (const listener of document.listeners[name] || []) listener(event);
    card.emit(name, event);
  }
  function assertFace(flipped) {
    assert.equal(card.classList.contains("is-flipped"), flipped);
    assert.equal(front.getAttribute("aria-hidden"), String(flipped));
    assert.equal(back.getAttribute("aria-hidden"), String(!flipped));
    assert.equal(front.attributes.has("inert"), flipped);
    assert.equal(back.attributes.has("inert"), !flipped);
    assert.equal(open.getAttribute("aria-expanded"), String(flipped));
    assert.deepEqual(focusErrors, []);
  }
  return {
    card, front, back, open, close, action, outside, document, input, assertFace,
    resize(matches) { media.matches = matches; media.change(); },
    flush() { while (deferred.length) deferred.shift()(); },
  };
}

{
  const f = fixture();
  f.assertFace(false);
  assert.equal(f.open.hidden, true);
  assert.equal(f.close.hidden, true);
  assert.equal(f.close.disabled, true);
  assert.equal(f.card.getAttribute("aria-label"), "Details for Server address");
  f.input("keydown", { key: "Tab" });
  f.card.focus();
  f.assertFace(true);
  f.action.focus();
  f.input("keydown", { key: "Escape" });
  f.flush();
  f.assertFace(false);
  assert.equal(f.document.activeElement, f.card, "Escape restores focus before hiding the back face");
}

{
  const f = fixture(false);
  f.open.focus();
  f.open.emit("click");
  f.assertFace(true);
  assert.equal(f.document.activeElement, f.close);
  f.close.emit("click");
  f.assertFace(false);
  assert.equal(f.document.activeElement, f.open);
  f.input("pointerenter", { pointerType: "mouse" });
  f.assertFace(false);
  assert.equal(f.open.hidden, false, "A narrow viewport retains button-driven cards");
}

{
  const f = fixture();
  f.input("pointerenter", { pointerType: "mouse" });
  f.assertFace(true);
  f.input("pointerdown", { pointerType: "touch" });
  assert.equal(f.close.hidden, false);
  assert.equal(f.close.disabled, false);
  f.close.focus();
  f.close.emit("click");
  f.outside.focus();
  f.flush();
  f.resize(false);
  f.resize(true);
  f.assertFace(false);
  assert.equal(f.open.hidden, false, "Touch mode survives blur and breakpoint changes");
  f.input("pointerenter", { pointerType: "mouse" });
  f.assertFace(true);
  assert.equal(f.open.hidden, true, "Mouse input restores hover mode on a hybrid device");
}

{
  const f = fixture(false);
  f.open.focus();
  f.open.emit("click");
  f.resize(true);
  f.assertFace(false);
  assert.equal(f.document.activeElement, f.card);
  f.resize(false);
  f.assertFace(false);
  assert.equal(f.document.activeElement, f.open);
}

{
  const f = fixture();
  f.input("keydown", { key: "Tab" });
  f.card.focus();
  f.outside.focus();
  f.card.focus();
  f.flush();
  f.assertFace(true);
  f.outside.focus();
  f.flush();
  f.assertFace(false);
}

console.log("Flip-card focus, touch, hybrid input, and breakpoint tests passed.");
