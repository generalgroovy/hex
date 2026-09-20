(function () {
  "use strict";
  const D = window.MagicStudyData, M = window.MagicStudyModel;
  const $ = id => document.getElementById(id);
  const clock = new M.Clock(performance.now());
  const state = {stage: "basics", mode: "raw", modeChosen: false, size: 64, background: "dark", generation: 0, metadata: null, images: new Map(), cards: [], lastReadout: -1};
  // This batch deliberately stops before all reaction art, including Steam.
  const names = [...D.elements];

  function currentAsset(name) { return M.asset(name, state.mode, state.metadata); }
  function currentNames() { return D.elements; }

  function buildCards() {
    $("cards").replaceChildren();
    state.cards = [];
    const entries = D.elements;
    for (const name of entries) {
      const card = document.createElement("article");
      card.className = "card";
      const heading = document.createElement("h2"), title = document.createElement("span"), status = document.createElement("span");
      title.textContent = D.title(name);
      status.className = "status";
      heading.append(title, status);
      const canvas = document.createElement("canvas");
      const ratio = Math.max(1, window.devicePixelRatio || 1);
      canvas.width = Math.round(240 * ratio); canvas.height = Math.round(154 * ratio);
      canvas.setAttribute("aria-label", D.title(name) + " frame preview");
      const caption = document.createElement("div"); caption.className = "caption";
      card.append(heading, canvas, caption); $("cards").append(card);
      state.cards.push({name, canvas, context: canvas.getContext("2d"), ratio, status, caption, key: ""});
    }
    updateNotes();
  }

  function updateNotes() {
    const packed = state.mode === "packed";
    $("stage-note").textContent = "Eight supplied frames per element, looped for inspection. Display size is exact CSS pixels. Raw fractional cells retain their aspect ratio; no alpha removal or sprite fitting happens here.";
    $("timing-note").textContent = packed
      ? "Packed mode reads local manifest.js when available: nearest 32px cells and declared study frame durations. This page does not run or change the game. First-level interaction studies are not started."
      : "Source study timing: 120 ticks/sec; Fire 8/10/8/10/8/10/8/10 ticks; others 10 ticks/frame. These are review timings, not gameplay changes. Raw layout warnings are measured before any packer calibration.";
  }

  function refreshAvailability() {
    const loaded = currentNames().filter(name => state.images.get(name)?.status === "loaded").length;
    const total = currentNames().length;
    $("availability").textContent = `${loaded}/${total} ${state.mode === "packed" ? "packed sheets" : "raw sources"} available` +
      (state.mode === "packed" && !state.metadata ? " · packed metadata missing; timings use labeled study defaults" : "");
  }

  function loadImages() {
    const generation = ++state.generation;
    state.images.clear();
    for (const name of names) {
      const entry = currentAsset(name), image = new Image();
      const record = {image, status: "waiting", message: "Waiting for local PNG"};
      state.images.set(name, record);
      image.onload = () => {
        if (generation !== state.generation) return;
        const rect = M.sourceRect(image.naturalWidth, image.naturalHeight, 0, entry.packed);
        record.status = rect ? "loaded" : "invalid";
        record.message = rect ? "" : "Packed sheet must be 128×64";
        for (const card of state.cards) card.key = "";
        refreshAvailability();
      };
      image.onerror = () => {
        if (generation !== state.generation) return;
        record.status = "waiting"; record.message = "Waiting for " + name + ".png";
        refreshAvailability();
      };
      // No fetch/XHR: direct relative file images work in an offline file:// tab.
      image.src = entry.path + "?review=" + generation + "-" + Date.now();
    }
    for (const card of state.cards) card.key = "";
    refreshAvailability();
  }

  function reloadFiles() {
    loadImages();
    const script = document.createElement("script");
    script.src = "../packed/manifest.js?review=" + Date.now();
    script.onload = () => {
      state.metadata = window.MagicStudyPackedMetadata || null;
      if (!state.modeChosen && state.mode !== "packed" && D.elements.some(name => state.metadata?.assets?.[name])) {
        state.mode = "packed"; $("source").value = "packed";
        loadImages();
      }
      for (const card of state.cards) card.key = "";
      updateNotes(); refreshAvailability(); script.remove();
    };
    script.onerror = () => { state.metadata = null; refreshAvailability(); script.remove(); };
    document.head.append(script);
  }

  function renderCard(card, tick) {
    const name = card.name;
    const entry = currentAsset(name), record = state.images.get(name);
    const frame = M.frameAt(entry.ticks, tick, true);
    const key = [name, frame, record?.status, state.mode, state.size, state.background, entry.timing, entry.layoutWarning].join("|");
    if (key === card.key) return;
    card.key = key;
    const ctx = card.context;
    ctx.setTransform(card.ratio, 0, 0, card.ratio, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = state.background === "stone" ? "#695c4a" : "#14242d";
    ctx.fillRect(0, 0, 240, 154);
    ctx.strokeStyle = state.background === "stone" ? "#80715a" : "#263a42";
    ctx.lineWidth = 1;
    for (let x = 0; x <= 240; x += 16) { ctx.beginPath(); ctx.moveTo(x + .5, 0); ctx.lineTo(x + .5, 154); ctx.stroke(); }
    for (let y = 0; y <= 154; y += 16) { ctx.beginPath(); ctx.moveTo(0, y + .5); ctx.lineTo(240, y + .5); ctx.stroke(); }
    if (!record || record.status !== "loaded" || frame < 0) {
      ctx.fillStyle = "#dbc697"; ctx.font = "12px system-ui"; ctx.textAlign = "center";
      ctx.fillText(record?.status === "invalid" ? "Invalid packed dimensions" : "Source not supplied yet", 120, 76);
      card.status.textContent = "WAITING";
      card.caption.textContent = "No substitute art. " + entry.path;
      return;
    }
    const image = record.image, crop = M.sourceRect(image.naturalWidth, image.naturalHeight, frame, entry.packed);
    const factor = state.size / Math.max(crop.width, crop.height);
    const width = crop.width * factor, height = crop.height * factor;
    // Fit the unchanged fractional cell; no per-frame bounds or matte inference.
    ctx.drawImage(image, crop.x, crop.y, crop.width, crop.height, Math.round((240 - width) / 2), Math.round((154 - height) / 2), width, height);
    card.status.textContent = entry.packed ? "PACKED STUDY" : "RAW STUDY";
    card.caption.textContent = `Frame ${frame + 1}/8 · ${entry.ticks[frame]} ticks · ${entry.total}-tick pose loop\n` +
      (entry.packed ? "32px cells · no production approval" : "Raw matte/alpha unverified");
    if (entry.layoutWarning) card.caption.textContent += "\nReview: " + entry.layoutWarning;
  }

  function draw(now) {
    const tick = clock.at(now);
    for (const card of state.cards) renderCard(card, tick);
    const readout = Math.floor(tick / 12);
    if (readout !== state.lastReadout) {
      $("clock").textContent = `t=${Math.floor(tick)} @ 120 ticks/sec · ${clock.speed}× · ${clock.paused ? "PAUSED" : "PLAYING"}`;
      state.lastReadout = readout;
    }
    requestAnimationFrame(draw);
  }

  function setPaused(paused) {
    clock.setPaused(paused, performance.now());
    $("pause").textContent = paused ? "Play" : "Pause";
    $("pause").setAttribute("aria-pressed", String(paused));
    state.lastReadout = -1;
  }
  function restart() { clock.seek(0, performance.now()); state.lastReadout = -1; }
  function step() {
    setPaused(true);
    const now = performance.now(), tick = clock.at(now);
    const next = M.nextBoundary(currentNames().map(currentAsset), tick);
    clock.seek(next, now);
    state.lastReadout = -1;
  }
  function setStage(stage) {
    if (stage !== "basics") return; // User stop boundary: no reaction studies.
    state.stage = stage;
    for (const id of ["basics", "steam"]) {
      $(id).classList.toggle("selected", stage === id); $(id).setAttribute("aria-pressed", String(stage === id));
    }
    restart(); buildCards(); refreshAvailability();
  }

  for (const reaction of D.reactions) {
    const tr = document.createElement("tr");
    const cells = [String(reaction.wire), reaction.name, reaction.elements.map(D.title).join(" + "), "PAUSED · NOT GENERATED IN THIS BATCH"];
    cells.forEach((text, index) => {
      const td = document.createElement("td"); td.textContent = text;
      if (index === 3) td.className = "queue-state";
      tr.append(td);
    });
    $("queue-rows").append(tr);
  }
  $("basics").onclick = () => setStage("basics");
  $("pause").onclick = () => setPaused(!clock.paused); $("step").onclick = step; $("restart").onclick = restart;
  $("speed").onchange = event => { clock.setSpeed(Number(event.target.value), performance.now()); state.lastReadout = -1; };
  $("size").onchange = event => { state.size = Number(event.target.value); };
  $("background").onchange = event => { state.background = event.target.value; };
  $("source").onchange = event => { state.modeChosen = true; state.mode = event.target.value; restart(); updateNotes(); reloadFiles(); };
  $("grayscale").onchange = event => $("cards").classList.toggle("grayscale", event.target.checked);
  $("reload").onclick = reloadFiles;
  document.addEventListener("keydown", event => {
    if (/^(INPUT|SELECT|BUTTON|TEXTAREA)$/.test(event.target.tagName) || event.ctrlKey || event.altKey || event.metaKey) return;
    if (event.code === "Space") { event.preventDefault(); setPaused(!clock.paused); }
    else if (event.code === "ArrowRight") { event.preventDefault(); step(); }
    else if (event.code === "KeyR") restart();
  });
  window.addEventListener("resize", buildCards);
  buildCards(); reloadFiles(); requestAnimationFrame(draw);
  window.MagicStudyReview = Object.freeze({
    summary: () => ({stage: state.stage, mode: state.mode, loaded: [...state.images].filter(([,value]) => value.status === "loaded").map(([name]) => name), reactions: D.reactions.length, tick: Math.floor(clock.at(performance.now())), paused: clock.paused}),
    pause: () => setPaused(true)
  });
})();
