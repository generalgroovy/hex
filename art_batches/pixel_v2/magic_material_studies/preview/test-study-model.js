"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const D = require("./study-data.js");
const M = require("./study-model.js");
let checks = 0;
function equal(actual, expected) { assert.deepEqual(actual, expected); checks++; }
function ok(value) { assert.ok(value); checks++; }

equal(D.elements.length, 8);
equal(D.reactions.length, 36);
equal(new Set(D.reactions.map(row => row.id)).size, 36);
equal(M.asset("fire", "raw").total, 72);
equal(M.asset("water", "raw").total, 80);
assert.throws(() => M.asset("../secret", "raw")); checks++;
for (const name of D.elements) {
  const entry = M.asset(name, "raw");
  let boundary = 0;
  for (let frame = 0; frame < 8; frame++) {
    equal(M.frameAt(entry.ticks, boundary), frame);
    equal(M.frameAt(entry.ticks, boundary + entry.ticks[frame] - .001), frame);
    equal(M.nextBoundary([entry], boundary), boundary + entry.ticks[frame]);
    boundary += entry.ticks[frame];
  }
  equal(M.frameAt(entry.ticks, boundary), 0);
  equal(M.frameAt(entry.ticks, boundary, false), -1);
  equal(M.frameAt(entry.ticks, -1), -1);
  equal(M.frameAt(entry.ticks, NaN), -1);
  for (let age = 0; age < 600; age++) equal(M.frameAt(entry.ticks, age), M.frameAt(entry.ticks, age + entry.total * 100));
}
equal(M.frameAt([0,1,1,1,1,1,1,1], 0), -1);
equal(M.frameAt([1], 0), -1);
for (let frame = 0; frame < 8; frame++) {
  const rect = M.sourceRect(128, 64, frame, true);
  equal(rect, {x: frame % 4 * 32, y: Math.floor(frame / 4) * 32, width: 32, height: 32});
  const raw = M.sourceRect(1536, 1024, frame, false);
  equal(raw.width, 384); equal(raw.height, 512);
  ok(raw.x + raw.width <= 1536 && raw.y + raw.height <= 1024);
}
equal(M.sourceRect(1536, 1024, 0, true), null);
equal(M.sourceRect(0, 64, 0), null);
equal(M.sourceRect(128, 64, 8), null);
const metadata = {assets: {fire: {tick_rate: 120, path: "https://invalid.invalid/never.png", frames: Array.from({length:8}, () => ({duration_ticks: 3})), loop: true, layout_qa: {qa_flags: ["row_drift"]}}}};
equal(M.asset("fire", "packed", metadata).total, 24);
equal(M.asset("fire", "packed", metadata).path, "../packed/fire.png");
equal(M.asset("fire", "packed", metadata).layoutWarning, "row drift");
equal(M.asset("fire", "raw", metadata).total, 72);
metadata.assets.fire.frames[0].duration_ticks = -10;
equal(M.asset("fire", "packed", metadata).total, 72);
metadata.assets.fire.frames[0].duration_ticks = 3;
metadata.assets.fire.tick_rate = 60;
equal(M.asset("fire", "packed", metadata).total, 72);
const clock = new M.Clock(100);
equal(clock.at(1100), 120);
clock.setPaused(true, 1100); equal(clock.at(5000), 120);
clock.setSpeed(2, 5000); equal(clock.at(5100), 120);
clock.setPaused(false, 5100); equal(clock.at(6100), 360);
clock.setSpeed(.5, 6100); equal(clock.at(7100), 420);
equal(clock.setSpeed(0, 7100), false); equal(clock.speed, .5);
clock.seek(0, 7100); equal(clock.at(8100), 60);
const frameRates = [30, 60, 120, 144, 240];
for (const fps of frameRates) {
  const renderingClock = new M.Clock(0);
  for (let step = 0; step <= fps; step++) renderingClock.at(step * 1000 / fps);
  equal(renderingClock.at(1000), 120);
}
equal(M.nextBoundary([M.asset("fire", "raw"), M.asset("water", "raw")], 0), 8);
equal(M.nextBoundary([M.asset("fire", "raw"), M.asset("water", "raw")], 8), 10);

const repository = path.resolve(__dirname, "../../../..");
const source = fs.readFileSync(path.join(repository, "src/sim/chemistry/element_chemistry_system.gd"), "utf8");
const table = source.slice(source.indexOf("const RECIPE_ROWS"), source.indexOf("static func recipe("));
const wireElements = ["earth","fire","water","wind","ice","charge","light","dark"];
const rows = [...table.matchAll(/\["([a-z_]+)",(\d),(\d),/g)];
equal(rows.length, 36);
rows.forEach((row, index) => {
  equal(D.reactions[index].id, row[1]);
  equal(D.reactions[index].wire, 301 + index);
  equal(D.reactions[index].elements, [wireElements[Number(row[2]) - 1], wireElements[Number(row[3]) - 1]]);
});
const html = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
const viewer = fs.readFileSync(path.join(__dirname, "viewer.js"), "utf8");
ok(/id="steam"[^>]*disabled/.test(html));
ok(html.includes("stopped before first-level interactions"));
ok(html.includes("connect-src 'none'"));
ok(!/\bfetch\s*\(|\bXMLHttpRequest\b|\bWebSocket\b/.test(viewer));
ok(!/<script[^>]+src="https?:/i.test(html));
ok(viewer.includes('const names = [...D.elements]'));
ok(viewer.includes('PAUSED · NOT GENERATED IN THIS BATCH'));
ok(viewer.includes('if (stage !== "basics") return;'));
console.log(`PASS magic study viewer: ${checks} deterministic checks; no game writes, art approval or browser-render claim.`);
