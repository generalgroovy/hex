extends RefCounted
## Optional lesson order over existing earned rivals, never an unlock gate.
## Mega Man supplies the learn-a-defeated-boss's-weapon precedent; these three
## counter lessons are original H.E.X. choices and require playtest assessment.
const REFERENCE := "https://news.capcomusa.com/mega_man/blog/2018/10/02/ready-mega-man-11-is-out-now"
const LESSONS := [
	{"id":"wa_bidi","title":"1 / 3 · Read the gaps","lesson":"Conservatory: cross between the three Rapid bursts, then answer during recovery.","reuse":"Equip the learned Rapid to practice short, paid pressure while circling a slower spell."},
	{"id":"oh_tipi","title":"2 / 3 · Leave the marked ground","lesson":"Tideglass: read Fuse's committed landing point; move before the delayed area blast.","reuse":"Equip the learned Fuse to pressure a predicted stopping point while you change lanes."},
	{"id":"s_wayne","title":"3 / 3 · Read the second lane","lesson":"Basalt: watch the real wall-facing bank line and its reflected route; keep a lateral exit.","reuse":"Equip the learned Rebound and use a solid face to reach around cover."},
]


static func view(challenges: Array[Dictionary], earned: Array[String]) -> Dictionary:
	var by_id := {}
	for challenge: Dictionary in challenges: by_id[String(challenge.id)] = challenge
	var completed := 0
	var earned_reuse := {}
	var next := {}
	for lesson: Dictionary in LESSONS:
		if not by_id.has(String(lesson.id)): return {}
		if earned.has(String(lesson.id)):
			completed += 1
			earned_reuse[String(lesson.id)] = String(lesson.reuse)
		elif next.is_empty():
			next = lesson.duplicate(true)
			var challenge: Dictionary = by_id[String(lesson.id)]
			next["name"] = String(challenge.name)
			next["signature_wire"] = int(challenge.signature_wire)
			next["spell_name"] = String(challenge.spell_name)
			next["counter"] = String(challenge.counter)
	return {"completed":completed,"total":LESSONS.size(),"complete":completed==LESSONS.size(),
		"title":"Three signature lessons complete" if next.is_empty() else String(next.title),
		"lesson":"Try the learned forms in the Range or challenge any remaining rival." if next.is_empty() else String(next.lesson),
		"next":next,"earned_reuse":earned_reuse,"optional":true,"notice":"A suggested learning route; every rival remains selectable.","reference":REFERENCE}
