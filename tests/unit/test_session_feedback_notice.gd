extends FluxTestSuite


class FeedbackHarness:
	extends "res://src/app/bootstrap.gd"
	func _session_base_label() -> String:
		return "COURT · SCORE 2 · 14s"


func run() -> int:
	var node := FeedbackHarness.new()
	node.preference_overrides_are_transient = true
	node.session_transport = SessionTransport.new()
	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node._apply_snapshot_overflow(PackedInt32Array([3, 0, 7, 0]))
	equal(node.network_projectile_overflow, 3, "existing projectile overflow remains separate")
	equal(node.network_event_overflow, 7, "accepted snapshot event-capacity slot reaches presentation")
	node._update_network_feedback_notice(0.1)
	equal(node.network_event_overflow_notice_seconds, 2.0, "event pressure starts a finite readable notice")
	equal(node._session_label(), "COURT · SCORE 2 · 14s", "notice preserves the ordinary round and score status")
	equal(node._session_feedback_label(), "FEEDBACK BUSY", "pressure has an independent complete label")
	check(not node._session_feedback_label().contains("7"), "notice does not claim a known number of player-visible missed events")
	check(ThemeDB.fallback_font.get_string_size(node._session_feedback_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 228.0, "complete notice fits the native session panel text width")
	node._apply_snapshot_overflow(PackedInt32Array([0, 0, 0, 0]))
	node._update_network_feedback_notice(1.5)
	check(node.network_event_overflow_notice_seconds > 0.0, "brief replicated pressure remains readable after the queue quiets")
	node._update_network_feedback_notice(0.5)
	equal(node._session_label(), "COURT · SCORE 2 · 14s", "notice clears after two quiet presentation seconds")
	equal(node._session_feedback_label(), "", "independent warning line disappears after quiet interval")
	node.session_transport.mode = SessionTransport.Mode.HOSTING
	node.authoritative_session = AuthoritativeSession.new()
	node.authoritative_session.pending_combat_event_overflow_count = 1
	node._update_network_feedback_notice(0.1)
	check(node._session_feedback_label().contains("FEEDBACK BUSY"), "host sees its own actual pending-lane pressure")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	node._update_network_feedback_notice(0.01)
	equal(node.network_event_overflow_notice_seconds, 0.0, "offline transition clears stale feedback notice immediately")
	equal(node.network_event_overflow, 0, "offline transition clears stale replicated pressure")
	node.free()
	return finish("session-feedback-notice")
