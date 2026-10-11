class_name UiGridNavigation
extends RefCounted
## Spatial focus never wraps diagonally or jumps into an absent cell.
## Callers own linear Tab traversal and authoritative action admission.


static func neighbor(index: int, count: int, columns: int, horizontal: int, vertical: int) -> int:
	if count <= 0 or columns <= 0:
		return index
	var candidate := index + horizontal + vertical * columns
	if candidate < 0 or candidate >= count:
		return index
	if horizontal != 0 and candidate - candidate % columns != index - index % columns:
		return index
	return candidate
