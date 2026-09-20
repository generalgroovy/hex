class_name PixelMovementEffects
extends RefCounted

const Library = preload("res://src/presentation/pixel_magic_library.gd")
const CACHE_LIMIT := 64
var library: RefCounted
var _body_masks: Dictionary = {}
var _mask_order: Array[String] = []
var _source_texture: Texture2D
var _source_image: Image
var _wall_contacts: Dictionary = {}


func _init(shared_library: RefCounted = null) -> void:
	library = shared_library if shared_library != null else Library.default_library()


func ready() -> bool:
	return library != null and library.asset_count() > 0


func stamp(canvas: CanvasItem, effect: String, anchor: Vector2, age: int, reduced: bool, angle: float = 0.0, opacity: float = 1.0) -> bool:
	if not ready():
		return false
	if effect in ["slide_dust","slide_trail","landing_dust","walljump_burst","wallrun_sparks"] and not library.take_decoration(Library.movement_asset_id(effect,reduced)):
		return true
	library.draw_stamp(canvas, Library.movement_asset_id(effect, reduced), anchor, age, angle, opacity)
	return true # Expired one-shot is handled; it must not resurrect a fallback.


static func afterimage_offsets(state: PlayerState, config: SimConfig, reduced: bool) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if state == null or config == null or state.health <= 0 or state.air_dodge_ticks <= 0 or state.is_rolling():
		return result
	var velocity := Vector2(state.velocity_x, state.velocity_y) / 1000.0
	if velocity.length_squared() <= 1.0:
		return result
	var total := config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	var elapsed := maxi(0, total - state.air_dodge_ticks)
	for index: int in range(1 if reduced else 2):
		# A copy cannot predate this accepted dash. Never paint through its start.
		var lookback := mini(elapsed, 2 + index * 2)
		if lookback > 0:
			result.append(-velocity * float(lookback) / float(config.tick_rate))
	return result


func draw_afterimages(canvas: CanvasItem, state: PlayerState, config: SimConfig, source: Texture2D, region: Rect2, body_anchor: Vector2, body_height: float, reduced: bool) -> bool:
	if not ready() or source == null:
		return false
	var offsets := afterimage_offsets(state, config, reduced)
	if offsets.is_empty():
		return true
	if library.decoration_remaining() <= 0:
		return true
	var elapsed := maxi(0, config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS) - state.air_dodge_ticks)
	var mask_id := Library.movement_asset_id("air_dash_afterimage_mask", reduced)
	var frame: Dictionary = library.sample(mask_id, elapsed)
	if frame.is_empty():
		return true
	var texture := masked_body(source, region, frame, body_height)
	if texture == null:
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index: int in range(offsets.size() - 1, -1, -1):
		if not library.take_decoration(mask_id):
			continue
		canvas.draw_texture(texture, body_anchor + offsets[index] - Vector2(48,84), Color(1,1,1,0.16 if index == 0 else 0.08))
	return true


func masked_body(source: Texture2D, region: Rect2, frame: Dictionary, body_height: float) -> Texture2D:
	if source == null or frame.is_empty() or region.size != Vector2(96,96):
		return null
	var key := "%s:%s:%s:%s" % [source.get_instance_id(), region, frame.region, body_height]
	if _body_masks.has(key):
		return _body_masks[key]
	# Native image operations, only on a bounded cache miss; never per pixel in
	# GDScript and never a replacement atlas, hand, aura or protection texture.
	if _source_texture != source:
		_source_texture = source
		_source_image = source.get_image()
	if _source_image == null:
		return null
	var body := _source_image.get_region(Rect2i(region))
	var page: Texture2D = frame.texture
	var source_mask := page.get_image().get_region(Rect2i(frame.region))
	var ratio := clampf(body_height, 40, 76) / 44.0
	var size := Vector2i(roundi(32 * ratio), roundi(48 * ratio))
	source_mask.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var mask := Image.create(96,96,false,Image.FORMAT_RGBA8)
	mask.blit_rect(source_mask, Rect2i(Vector2i.ZERO,size), Vector2i(48 - size.x / 2, 84 - roundi(44 * ratio)))
	var result := Image.create(96,96,false,Image.FORMAT_RGBA8)
	result.blit_rect_mask(body,mask,Rect2i(0,0,96,96),Vector2i.ZERO)
	var texture := ImageTexture.create_from_image(result)
	if _mask_order.size() >= CACHE_LIMIT:
		_body_masks.erase(_mask_order.pop_front())
	_mask_order.append(key)
	_body_masks[key] = texture
	return texture


func cache_size() -> int:
	return _body_masks.size()


func walljump_contact(state: PlayerState, config: SimConfig, tick: int, ground_anchor: Vector2) -> Dictionary:
	if state == null or config == null or state.health <= 0:
		return {}
	var normal := Vector2(state.wall_x,state.wall_y).normalized()
	var memory := config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
	if normal != Vector2.ZERO and state.wall_memory_ticks == memory and state.wall_contact_id > 0:
		if not _wall_contacts.has(state.entity_id) and _wall_contacts.size() >= 32:
			_wall_contacts.erase(_wall_contacts.keys()[0])
		_wall_contacts[state.entity_id] = {"anchor":ground_anchor-normal*float(MovementTuning.PLAYER_RADIUS)/1000.0,"tick":tick}
	if state.hop_mode != PlayerState.MovementMode.WALL_KICK or state.jump_protection_ticks <= 0 or not _wall_contacts.has(state.entity_id):
		return {}
	var remembered: Dictionary = _wall_contacts[state.entity_id]
	var age := config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS)-state.jump_protection_ticks
	if tick < int(remembered.tick) or tick-int(remembered.tick) > memory + config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS):
		return {}
	return {"anchor":remembered.anchor,"age":maxi(0,age)}


func protection(canvas: CanvasItem, contract: Dictionary, anchor: Vector2, reduced: bool) -> bool:
	if not ready():
		return false
	if not bool(contract.get("active", false)):
		return true
	var corners: Array = contract.get("brackets", [])
	for index: int in range(corners.size()):
		var points: PackedVector2Array = corners[index]
		var center := anchor + points[1]
		var frame: Dictionary = library.sample(Library.movement_asset_id("protection_corner", reduced),0)
		_draw_flipped(canvas,frame,center,index >= 2,index % 2 == 1)
	var shield: PackedVector2Array = contract.get("shield",PackedVector2Array())
	if shield.size() > 1:
		var center := anchor + (shield[0]+shield[1])*0.5 + Vector2(0,4)
		stamp(canvas,"protection_badge",center,0,reduced)
		var wings: Array = contract.get("float_wings",[])
		if not wings.is_empty():
			var frame: Dictionary = library.sample(Library.movement_asset_id("float_wing",reduced),0)
			_draw_flipped(canvas,frame,center+Vector2(-16,0),true,false)
			_draw_flipped(canvas,frame,center+Vector2(16,0),false,false)
			# The live three-slot time meter is drawn by the champion presenter;
			# retain the immutable legacy tick asset, but do not stack its icon.
	return true


static func _draw_flipped(canvas: CanvasItem, frame: Dictionary, anchor: Vector2, flip_x: bool, flip_y: bool) -> void:
	if frame.is_empty():
		return
	var size: Vector2 = frame.size
	var destination := Rect2(anchor - (frame.pivot as Vector2),size)
	if flip_x:
		destination.size.x = -size.x
	if flip_y:
		destination.size.y = -size.y
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_texture_rect_region(frame.texture,destination,frame.region)
