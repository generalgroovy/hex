class_name SurfaceMotionPolicy
extends RefCounted


# Future chemistry supplies authoritative material wire IDs and sampled status.
# Rendering, client preferences and material names can never change motion.
# Neutral by construction in this acceptance slice: no ice drift or mud grip.
const COMPATIBILITY_ID := "surface-motion-neutral-v1"
const NEUTRAL_RATIO: int = 1000


static func acceleration_ratio(_material_wire_id: int = 0, _status_mask: int = 0) -> int:
	return NEUTRAL_RATIO


static func braking_ratio(_material_wire_id: int = 0, _status_mask: int = 0) -> int:
	return NEUTRAL_RATIO


static func steering_ratio(_material_wire_id: int = 0, _status_mask: int = 0) -> int:
	return NEUTRAL_RATIO
