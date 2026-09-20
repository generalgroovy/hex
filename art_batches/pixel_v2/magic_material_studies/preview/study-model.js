(function (root) {
  "use strict";
  const data = typeof module !== "undefined" && module.exports ? require("./study-data.js") : root.MagicStudyData;
  const names = [...data.elements, ...data.steam];

  function asset(name, mode, metadata) {
    if (!names.includes(name)) throw new Error("Unknown study name");
    const packed = mode === "packed";
    const entry = metadata && metadata.assets && metadata.assets[name];
    let ticks = name === "fire" ? [...data.fireTicks] : [...data.defaultTicks];
    let timing = "Declared study defaults; not gameplay timing";
    const layout = entry && (packed ? entry.layout_qa : entry.raw_layout_qa);
    const flags = layout && Array.isArray(layout.qa_flags) ? layout.qa_flags.filter(value => typeof value === "string").slice(0, 3) : [];
    if (packed && entry && entry.tick_rate === 120 && Array.isArray(entry.frames) && entry.frames.length === 8 &&
        entry.frames.every(frame => Number.isInteger(frame.duration_ticks) && frame.duration_ticks > 0 && frame.duration_ticks <= 1200)) {
      ticks = entry.frames.map(frame => frame.duration_ticks);
      timing = "Packed study metadata; not a gameplay change";
    }
    return {
      name, path: "../" + (packed ? "packed/" : "sources/") + name + ".png", ticks,
      total: ticks.reduce((sum, value) => sum + value, 0), timing,
      layoutWarning: flags.map(value => value.replace(/_/g, " ").slice(0, 130)).join("; "),
      metadataAvailable: !!entry, packed, loop: entry ? !!entry.loop : !/formation|decay/.test(name),
      authorityPhaseTicks: packed && entry && Number.isInteger(entry.authority_phase_ticks) && entry.authority_phase_ticks > 0 && entry.authority_phase_ticks <= 12000 ? entry.authority_phase_ticks : null
    };
  }

  function frameAt(ticks, age, loop = true) {
    if (!Number.isFinite(age) || age < 0 || !Array.isArray(ticks) || ticks.length !== 8 ||
        !ticks.every(tick => Number.isInteger(tick) && tick > 0)) return -1;
    const total = ticks.reduce((sum, value) => sum + value, 0);
    if (!loop && age >= total) return -1;
    let phase = Math.floor(age) % total;
    for (let index = 0; index < ticks.length; index++) {
      if (phase < ticks[index]) return index;
      phase -= ticks[index];
    }
    return -1;
  }

  function sourceRect(width, height, frame, packed = false) {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0 ||
        !Number.isInteger(frame) || frame < 0 || frame >= 8) return null;
    if (packed && (width !== 128 || height !== 64)) return null;
    const cellWidth = width / 4, cellHeight = height / 2;
    return {x: (frame % 4) * cellWidth, y: Math.floor(frame / 4) * cellHeight, width: cellWidth, height: cellHeight};
  }

  function steamAt(age, metadata, mode = "raw") {
    const phases = data.steam.map(name => asset(name, mode, metadata));
    const lengths = phases.map((phase, index) => phase.authorityPhaseTicks || phase.total * (index === 1 ? 2 : 1));
    const total = lengths.reduce((sum, value) => sum + value, 0);
    let phaseAge = Math.floor(Math.max(0, age)) % total;
    for (let index = 0; index < phases.length; index++) {
      if (phaseAge < lengths[index]) return {name: phases[index].name, phase: index, age: phaseAge, length: lengths[index], total, frame: frameAt(phases[index].ticks, phaseAge, index === 1)};
      phaseAge -= lengths[index];
    }
    return null;
  }

  function nextBoundary(assets, age) {
    let next = Infinity;
    for (const entry of assets) {
      const total = entry.total, cycle = Math.floor(Math.max(0, age) / total) * total;
      let end = cycle;
      for (const duration of entry.ticks) {
        end += duration;
        if (end > age + 1e-7) next = Math.min(next, end);
      }
    }
    return Number.isFinite(next) ? next : Math.floor(age) + 1;
  }

  function nextSteamBoundary(age, metadata, mode = "raw") {
    const phase = steamAt(age, metadata, mode);
    const entry = asset(phase.name, mode, metadata);
    const phaseStart = Math.floor(Math.max(0, age)) - phase.age;
    return phaseStart + Math.min(phase.length, nextBoundary([entry], phase.age));
  }

  class Clock {
    constructor(now = 0) { this.anchor = now; this.base = 0; this.speed = 1; this.paused = false; }
    at(now) { return this.base + (this.paused ? 0 : Math.max(0, now - this.anchor) * 0.12 * this.speed); }
    settle(now) { this.base = this.at(now); this.anchor = now; }
    setPaused(paused, now) { this.settle(now); this.paused = paused; }
    setSpeed(speed, now) {
      if (!Number.isFinite(speed) || speed < 0.1 || speed > 4) return false;
      this.settle(now); this.speed = speed; return true;
    }
    seek(tick, now) { this.base = Math.max(0, tick); this.anchor = now; }
  }

  const api = Object.freeze({asset, frameAt, sourceRect, steamAt, nextBoundary, nextSteamBoundary, Clock});
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.MagicStudyModel = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
