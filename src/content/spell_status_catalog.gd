extends RefCounted
## Shared player-facing descriptions of direct-hit channels. Ground products
## have their own recipe rules and must not borrow these shorter hit windows.

const BITS: Array[int] = [1, 2, 4, 8, 16, 32]
const ROWS: Array[Dictionary] = [
	{"bit":1, "name":"Fractured Focus", "summary":"Fractured: slower future cast startup", "detail":"Adds 8% to a future startup while active; whole-tick rounding can leave very quick spells unchanged. An already paid startup is not retimed."},
	{"bit":2, "name":"Burning", "summary":"Burn: finite damage over time", "detail":"A finite damage pool pulses while active. Refreshing does not add a second pool; protection can prevent a pulse."},
	{"bit":4, "name":"Chilled", "summary":"Chilled: slower ground travel", "detail":"Reduces ordinary ground target speed by 12% while active. Air steering and committed movement actions keep their own rules."},
	{"bit":8, "name":"Gusted", "summary":"Gust: one bounded displacement", "detail":"Applies one bounded push on entry. Refreshing an active Gust does not add another shove."},
	{"bit":16, "name":"Revealed", "summary":"Revealed: visible through concealment", "detail":"Temporarily reveals the actor through concealment; solid sight-blocking geometry still applies."},
	{"bit":32, "name":"Withered", "summary":"Withered: ready Flux recovery blocked", "detail":"Temporarily blocks otherwise ready Flux recovery. Ordinary hit damage already delays Health recovery longer than this status. Ground recovery-denial fields have separate rules; Stamina stays separate."},
]


static func description(bit: int) -> String:
	var index := BITS.find(bit)
	return String(ROWS[index].summary) if index >= 0 else ""


static func rows_for_mask(mask: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if mask < 1 or mask > 63: return result
	for row: Dictionary in ROWS:
		if mask & int(row.bit): result.append(row.duplicate(true))
	return result
