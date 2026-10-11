class_name WellspringDistrictStyle
extends RefCounted
## Shared quiet wayfinding colors. These confer no element, surface or collision.
const STYLES := {
	"garden": ["384635", "68755b", "b5ba91", "leaf"],
	"nexus": ["595248", "817663", "cfbe94", "diamond"],
	"proving": ["504d49", "7d756c", "bfaf8d", "cross"],
	"coast": ["43565a", "778b89", "c0cbb8", "wave"],
	"grove": ["354a3a", "718267", "bbca9e", "leaf"],
	"foundry": ["50413b", "886c58", "c9a779", "bars"],
	"observatory": ["555766", "838899", "c7cbd2", "star"],
}


static func style_for(environment: String) -> Dictionary:
	var row: Array = STYLES.get(environment, STYLES.nexus)
	return {"ground": Color(row[0]), "edge": Color(row[1]), "accent": Color(row[2]), "motif": String(row[3])}


static func environment_for(district: Dictionary) -> String:
	return String(district.get("environment", district.get("style", "nexus")))


static func ground_ornaments(district: Dictionary) -> Array[Dictionary]:
	# Authored landmark margins receive six quiet floor motifs. This is finite
	# wayfinding decoration, never a new standing object or implied collision.
	var environment := environment_for(district)
	var values: Variant = district.get("landmark_anchor", [])
	var result: Array[Dictionary] = []
	if environment not in ["coast", "grove", "foundry", "observatory"] or not values is Array or values.size() != 2: return result
	var anchor := Vector2(float(values[0]), float(values[1]))
	for offset: Vector2 in [Vector2(-184, -112), Vector2(184, -112), Vector2(-224, 0), Vector2(224, 0), Vector2(-184, 112), Vector2(184, 112)]:
		var point := anchor + offset
		result.append({"bounds": Rect2(point - Vector2(60, 60), Vector2(120, 120)), "lines": emblem(point, environment)})
	return result


static func emblem(anchor: Vector2, environment: String) -> PackedVector2Array:
	# Flat, open-ended stone inlays: no enclosing danger circle, pulse or halo.
	# Unique silhouettes survive monochrome/reduced effects and retain empty feet.
	var result := PackedVector2Array()
	match String(style_for(environment).motif):
		"wave":
			for row: int in 3:
				for column: int in 4:
					var point := anchor + Vector2(-44 + column * 22, -24 + row * 24)
					result.append_array(PackedVector2Array([point, point + Vector2(11, -5), point + Vector2(11, -5), point + Vector2(22, 0)]))
		"leaf":
			for side: int in [-1, 1]:
				result.append_array(PackedVector2Array([anchor + Vector2(side * 42, 30), anchor + Vector2(side * 24, 0), anchor + Vector2(side * 24, 0), anchor + Vector2(side * 42, -30)]))
		"bars":
			for row: int in 3:
				result.append_array(PackedVector2Array([anchor + Vector2(-44, -28 + row * 28), anchor + Vector2(-18, -28 + row * 28), anchor + Vector2(18, -28 + row * 28), anchor + Vector2(44, -28 + row * 28)]))
		"star":
			for axis: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				var side := axis.orthogonal()
				result.append_array(PackedVector2Array([anchor + axis * 18 + side * 10, anchor + axis * 44, anchor + axis * 44, anchor + axis * 18 - side * 10]))
		_:
			result.append_array(PackedVector2Array([anchor + Vector2(-36, 0), anchor + Vector2(0, -28), anchor + Vector2(0, -28), anchor + Vector2(36, 0), anchor + Vector2(36, 0), anchor + Vector2(0, 28), anchor + Vector2(0, 28), anchor + Vector2(-36, 0)]))
	return result
