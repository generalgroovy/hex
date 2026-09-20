"use strict";
// Deterministic DOM/canvas test double, NOT a browser or rendered visual QA.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const D = require("./study-data.js"), M = require("./study-model.js");
let checks = 0;
function equal(actual, expected) { assert.deepEqual(actual, expected); checks++; }
function ok(value) { assert.ok(value); checks++; }

function launch(metadataAvailable = true) {
  let now = 0, animation = null, sandbox;
  const pending = [], requests = [], draws = [], ids = new Map(), keyListeners = [];
  class Element {
    constructor(tag = "div") {
      this.tagName = tag.toUpperCase(); this.children = []; this.attributes = {};
      this.textContent = ""; this.value = ""; this.classList = {toggle: () => {}};
    }
    append(...items) {
      this.children.push(...items);
      for (const item of items) if (item.tagName === "SCRIPT") pending.push(() => {
        if (!metadataAvailable) { item.onerror(); return; }
        const scriptPath = path.resolve(__dirname, item.src.split("?")[0]);
        vm.runInContext(fs.readFileSync(scriptPath, "utf8"), sandbox);
        item.onload();
      });
    }
    replaceChildren(...items) { this.children = items; }
    setAttribute(name, value) { this.attributes[name] = value; }
    remove() {}
    getContext() {
      return new Proxy({}, {get: (target, key) => target[key] || (key === "drawImage" ? (...args) => draws.push(args) : () => {}), set: (target, key, value) => { target[key] = value; return true; }});
    }
  }
  const document = {
    head: new Element("head"),
    getElementById(id) { if (!ids.has(id)) ids.set(id, new Element()); return ids.get(id); },
    createElement(tag) { return new Element(tag); },
    addEventListener(name, callback) { if (name === "keydown") keyListeners.push(callback); }
  };
  class LocalImage {
    set src(url) {
      requests.push(url);
      pending.push(() => {
        try {
          const file = fs.readFileSync(path.resolve(__dirname, url.split("?")[0]));
          assert.equal(file.toString("ascii", 1, 4), "PNG");
          this.naturalWidth = file.readUInt32BE(16); this.naturalHeight = file.readUInt32BE(20);
        } catch { this.onerror(); return; }
        this.onload();
      });
    }
  }
  const scope = {MagicStudyData: D, MagicStudyModel: M, document, Image: LocalImage, performance: {now: () => now}, devicePixelRatio: 1,
    requestAnimationFrame: callback => { animation = callback; }, addEventListener: () => {}, console};
  scope.window = scope; sandbox = vm.createContext(scope);
  vm.runInContext(fs.readFileSync(path.join(__dirname, "viewer.js"), "utf8"), sandbox);
  function settle() { while (pending.length) pending.shift()(); animation(now); }
  settle();
  return {scope, ids, requests, draws, settle, keyListeners, advance(ms) { now += ms; animation(now); }};
}

const preview = launch();
const metadata = JSON.parse(fs.readFileSync(path.resolve(__dirname, "../packed/manifest.json"), "utf8"));
const expectedPacked = D.elements.filter(name => metadata.assets[name] && fs.existsSync(path.resolve(__dirname, `../packed/${name}.png`)));
equal(preview.scope.MagicStudyReview.summary().mode, "packed");
equal(Array.from(preview.scope.MagicStudyReview.summary().loaded).sort(), [...expectedPacked].sort());
equal(preview.ids.get("cards").children.length, 8);
equal(preview.ids.get("queue-rows").children.length, 36);
equal(preview.scope.MagicStudyReview.summary().reactions, 36);
ok(preview.requests.every(url => !url.includes("steam") && !url.includes("http")));
ok(preview.ids.get("queue-rows").children.every(row => row.children[3].textContent === "PAUSED · NOT GENERATED IN THIS BATCH"));
equal(preview.ids.get("steam")?.onclick, undefined);
ok(preview.draws.length >= expectedPacked.length);
const lastDraws = preview.draws.slice(-expectedPacked.length);
for (const draw of lastDraws) { equal(draw[3], 32); equal(draw[4], 32); equal(draw[7], 64); equal(draw[8], 64); }
preview.ids.get("pause").onclick();
const pausedTick = preview.scope.MagicStudyReview.summary().tick;
preview.advance(1000); equal(preview.scope.MagicStudyReview.summary().tick, pausedTick);
preview.ids.get("step").onclick(); preview.settle();
ok(preview.scope.MagicStudyReview.summary().tick > pausedTick);
equal(preview.scope.MagicStudyReview.summary().paused, true);
preview.ids.get("restart").onclick(); equal(preview.scope.MagicStudyReview.summary().tick, 0);
preview.ids.get("size").onchange({target: {value: "128"}}); preview.settle();
equal(preview.draws.at(-1)[7], 128); equal(preview.draws.at(-1)[8], 128);
preview.ids.get("source").onchange({target: {value: "raw"}}); preview.settle();
equal(preview.scope.MagicStudyReview.summary().mode, "raw");
preview.ids.get("reload").onclick(); preview.settle();
equal(preview.scope.MagicStudyReview.summary().mode, "raw"); // Reload preserves explicit choice.
preview.ids.get("source").onchange({target: {value: "packed"}}); preview.settle();
equal(preview.scope.MagicStudyReview.summary().mode, "packed");
const sourceOnly = launch(false);
equal(sourceOnly.scope.MagicStudyReview.summary().mode, "raw");
ok(sourceOnly.requests.every(url => url.startsWith("../sources/") && !url.includes("steam")));
equal(sourceOnly.ids.get("cards").children.length, 8);
console.log(`PASS viewer DOM/canvas test double: ${checks} checks; ${expectedPacked.length}/8 packed sheets read; not a browser visual acceptance.`);
