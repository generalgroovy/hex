extends FluxTestSuite

const Art = preload("res://src/presentation/fullbody_cast_presenter.gd")

class CountingBody:
	extends WireframeBodyPresenter
	var frame_calls := 0
	func frame(body_type: String, animation_state: String, aim: Vector2i, travel: Vector2i, normalized_phase: float) -> Dictionary:
		frame_calls += 1
		return super.frame(body_type,animation_state,aim,travel,normalized_phase)

func run() -> int:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "language")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language), "old default loads")
	check(presenter.fullbody_art == null, "candidate is opt-in")
	var revision := presenter.portrait_revision()
	check(presenter.enable_fullbody_art(), "art admission: " + presenter.last_error)
	if presenter.fullbody_art == null: return finish("fullbody-cast")
	check(presenter.portrait_revision() > revision, "portrait caches invalidate")
	var art: RefCounted = presenter.fullbody_art
	var body := CountingBody.new()
	body.content_hash = presenter.wireframe_body.content_hash
	body.base_textures = presenter.wireframe_body.base_textures
	body.locomotion_textures = presenter.wireframe_body.locomotion_textures
	body.sprint_textures = presenter.wireframe_body.sprint_textures
	presenter.wireframe_body = body
	equal(art.entries.size(), 30, "all30 live identities")
	var config := SimConfig.new(120)
	_test_sparse_skinning(art)
	_test_facing_topology_round_trip(presenter,config)
	var state := PlayerState.new()
	for id: String in presenter.champions:
		equal(art.entries[id].body,presenter.champions[id].body_type,"art size matches active gameplay size")
		var portrait := presenter.portrait_frame(id)
		check(portrait.get("fullbody_art", false), "identity portrait " + id)
		check(not portrait.get("temporary_body_template", true), "not shared skeleton")
		for direction: int in 8:
			var preview := presenter.inspection_frame(id, CartoonChampionPresenter.EXPECTED_DIRECTIONS[direction])
			equal(preview.get("region"), Rect2(direction*256,0,256,256), "8 original-source detail views")
			state.aim_x = EightDirectionResolver.FIXED_VECTORS[direction].x
			state.aim_y = EightDirectionResolver.FIXED_VECTORS[direction].y
			state.velocity_x = -state.aim_x*200
			state.velocity_y = -state.aim_y*200
			state.movement_mode = PlayerState.MovementMode.SPRINT
			state.pending_cast_wire_id = 1
			var before := state.canonical_values()
			var frame := presenter.movement_frame(id,state,12,config,false,0.25)
			equal(frame.get("pivot"), Vector2(64,104), "feet registration")
			equal(frame.get("cell_size"), Vector2(128,128), "128 canvas")
			equal(frame.get("aim_index"), direction, "cursor owns facing")
			equal(frame.get("travel_index"), (direction+4)%8, "travel independent")
			check(frame.has("mesh"), "moving cast keeps actual body mesh")
			check(not frame.get("wireframe_body",true), "candidate never reports a skeleton frame")
			var arrays: Array = (frame.mesh as ArrayMesh).surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: check(vertex.is_finite(), "finite geometry")
			equal(state.canonical_values(), before, "art never writes authority")
	state.pending_cast_wire_id = 0
	for aim: int in 8:
		for travel: int in 8:
			state.aim_x = EightDirectionResolver.FIXED_VECTORS[aim].x
			state.aim_y = EightDirectionResolver.FIXED_VECTORS[aim].y
			state.velocity_x = EightDirectionResolver.FIXED_VECTORS[travel].x*300
			state.velocity_y = EightDirectionResolver.FIXED_VECTORS[travel].y*300
			state.movement_mode = PlayerState.MovementMode.SLIDE
			state.slide_ticks = 12
			var slide := presenter.movement_frame("jan_wicked",state,12,config)
			equal((slide.source_region as Rect2).position.x, float(travel*128), "slide follows all8 travel directions not cursor")
			equal(slide.get("art_pose_quality"), "authored key pose", "authored low silhouette")
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.slide_ticks = 0
	state.velocity_x = 0
	state.velocity_y = 0
	state.jumpsquat_active = true
	var squat := presenter.movement_frame("wa_bidi",state,12,config)
	equal(squat.get("squat_depth"), 0, "no legacy double deformation")
	state.jumpsquat_ticks = 24
	check(is_equal_approx(float(presenter.movement_frame("wa_bidi",state,12,config).motion_phase),2.0/3.0),"squat24ticks is not fully charged")
	state.jumpsquat_ticks = config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS)
	equal(presenter.movement_frame("wa_bidi",state,12,config).motion_phase,1.0,"squat reaches36tick contract")
	state.jumpsquat_active = false
	state.air_height = 20000
	state.air_vertical_velocity = 10000
	state.hop_ticks = 20
	state.air_dodge_ticks = 12
	equal(Art.action_for_state(state), "air_dodge", "dash wins over generic air")
	state.air_dodge_ticks = 0
	state.wall_skim_ticks = 12
	equal(Art.action_for_state(state), "wallrun", "wallrun distinct")
	state.wall_skim_ticks = 0
	state.air_floating = true
	state.flight_capable = true
	state.float_ticks = 1
	equal(Art.action_for_state(state), "fly", "actual capability, positive paid timer and Stamina admit the flight pose")
	state.float_ticks = 0
	equal(Art.action_for_state(state), "jump", "expired flight timer cannot retain the flying pose")
	state.float_ticks = 1
	var flight_stamina := state.stamina
	state.stamina = 0
	equal(Art.action_for_state(state), "jump", "exhausted paid flight cannot retain the flying pose")
	state.stamina = flight_stamina
	state.flight_capable = false
	equal(Art.action_for_state(state), "jump", "no flight for nonflier")
	state.air_height = 0
	state.air_vertical_velocity = 0
	state.hop_ticks = 0
	state.air_floating = false
	state.velocity_x = 0
	state.velocity_y = 0
	state.landing_ticks = 8
	equal(Art.action_for_state(state),"land","stationary landing uses its supplied clip")
	state.landing_ticks = 0
	state.health = 0
	equal(presenter.movement_frame("oh_tipi",state,12,config).sample_phase,1.0,"nonloop reaches final pose")
	state.health = 100
	state.movement_mode = PlayerState.MovementMode.SLIDE
	state.velocity_x = 200000
	state.pending_cast_wire_id = 1
	state.aim_x = -1000
	state.aim_y = 0
	var travel_cast := presenter.movement_frame("oh_tipi",state,12,config)
	equal(travel_cast.aim_index,6,"travel pose retains independent west casting aim")
	equal(travel_cast.travel_index,2,"travel pose still slides east")
	var keyed_cast := presenter.movement_frame("wa_bidi",state,12,config)
	check(keyed_cast.independent_cast_pose,"special-key actions retain independent casting through explicit shared-rig fallback")
	check(keyed_cast.has("mesh"),"missing painted cast overlay is not falsely reported as authored")
	state.pending_cast_wire_id = 0
	for index: int in 440:
		var ids: Array = art.entries.keys()
		var id: String = ids[index%ids.size()]
		state.velocity_x = 200000
		state.movement_mode = PlayerState.MovementMode.WALK
		presenter.movement_frame(id,state,index,config,false,float(index/30%12)/12.0)
	check(art.meshes.size() <= Art.CACHE_LIMIT, "geometry bounded")
	_test_fluid_motion(presenter, config)
	_test_continuous_mesh(presenter,config)
	_test_locomotion_settle(presenter,config)
	_test_continuous_modifiers(presenter,config)
	_test_retro_secondary_motion(presenter,config)
	_test_action_readability(presenter,config)
	_test_forced_action_dispatch(presenter,config)
	_test_real_control_journey(presenter,config)
	_test_wall_contact_pose(presenter,config)
	_test_weight_transfer_and_followthrough(presenter,config)
	_test_observer(presenter)
	equal(body.frame_calls,0,"identity art never computes discarded wireframe poses")
	check(presenter.configure(language), "default can be restored")
	check(presenter.fullbody_art == null, "reload clears candidate")
	return finish("fullbody-cast")


func _test_sparse_skinning(art: RefCounted) -> void:
	# Compare every retained vertex against the same untrimmed source topology.
	# Only fully transparent quads may disappear; pose math must stay identical
	# for all 30 identities, eight facings and every shared-rig action.
	var retained_vertices := 0
	var dense_vertices := 0
	for id: String in art.entries:
		var pixels: Image = art.textures[id].get_image()
		var texel_scale := pixels.get_height()/128
		for facing: int in 8:
			var key := "%s/%d" % [id,facing]
			var sparse: Dictionary = art.skin_tables[key]
			var direction: Dictionary = art.entries[id].directions[Art.DIRS[facing]]
			var dense: Dictionary = Art.compile_skin(direction)
			retained_vertices += sparse.points.size()
			dense_vertices += dense.points.size()
			check(sparse.points.size() > 0 and sparse.points.size() < dense.points.size(),"every admitted skin trims only empty canvas")
			var occupied := pixels.get_region(Rect2i(facing*128*texel_scale,0,128*texel_scale,128*texel_scale)).get_used_rect()
			var ink := Rect2(Vector2(occupied.position)/texel_scale-Art.ORIGIN,Vector2(occupied.size)/texel_scale).grow(1.0)
			var original_quads: Dictionary = {}
			for triangle: int in range(0,sparse.indices.size(),6):
				var original: int = sparse.source_indices[sparse.indices[triangle]]
				original_quads[original]=true
				var expected := PackedInt32Array([original,original+1,original+17,original+1,original+18,original+17])
				for corner: int in 6:
					equal(sparse.source_indices[sparse.indices[triangle+corner]],expected[corner],"retained triangles preserve source winding and UV vertices")
			for y: int in 16:
				for x: int in 16:
					var original := y*17+x
					var quad := Rect2(Art.vec(direction.vertices[original]),Vector2(8,8))
					equal(original_quads.has(original),quad.intersects(ink,true),"all ink and texel-guard quads retained, only transparent padding removed")
			var dense_lookup: Dictionary = {}
			for index: int in dense.source_indices.size(): dense_lookup[dense.source_indices[index]]=index
			for action: String in art.motions.actions:
				# Travel-facing actions retain this direction; independent aim uses
				# a different leg direction, so both retarget paths are exercised.
				var travel := facing if art.motions.actions[action].travel_facing else (facing+3)%8
				var reduced := (facing%2)==0
				var compact: PackedVector3Array = art.build_vertices(id,action,facing,travel,0.37,true,0.61,0.73,0.65,not reduced)
				art.skin_tables[key]=dense
				var reference: PackedVector3Array = art.build_vertices(id,action,facing,travel,0.37,true,0.61,0.73,0.65,not reduced)
				art.skin_tables[key]=sparse
				var max_error := 0.0
				for index: int in sparse.source_indices.size():
					max_error=maxf(max_error,compact[index].distance_to(reference[dense_lookup[sparse.source_indices[index]]]))
				check(max_error==0.0,"sparse and dense skinning are bit-exact %s/%d/%s" % [id,facing,action])
	check(retained_vertices < dense_vertices*0.6,"whole roster omits at least40percent of padding vertices without coarsening artwork")


func _test_facing_topology_round_trip(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var state := PlayerState.new(9182)
	var sizes_seen := {}
	for id: String in presenter.fullbody_art.entries:
		state.aim_x=0
		state.aim_y=1000
		state.velocity_x=MovementTuning.BASE_SPEED
		state.velocity_y=0
		state.movement_mode=PlayerState.MovementMode.WALK
		var first := presenter.movement_frame(id,state,30,config,false,0.25)
		var first_mesh: ArrayMesh = first.render_mesh
		var first_indices: PackedInt32Array = first_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var first_uvs: PackedVector2Array = first_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		for facing: int in range(1,8):
			state.aim_x=EightDirectionResolver.FIXED_VECTORS[facing].x
			state.aim_y=EightDirectionResolver.FIXED_VECTORS[facing].y
			state.movement_mode=PlayerState.MovementMode.SPRINT
			var other := presenter.movement_frame(id,state,32,config,false,0.7)
			check(other.render_mesh != first_mesh,"different-facing topology never shares a mutable stream")
			var arrays: Array = other.render_mesh.surface_get_arrays(0)
			sizes_seen[(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()]=true
			var highest := 0
			for index: int in arrays[Mesh.ARRAY_INDEX]: highest=maxi(highest,index)
			check(highest < (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),"each facing stream index stays in its own compact vertex range")
			state.aim_x=0
			state.aim_y=1000
			state.movement_mode=PlayerState.MovementMode.WALK
			var returned := presenter.movement_frame(id,state,34,config,false,0.35)
			equal(returned.render_mesh,first_mesh,"A to B to A reuses the correct original stream")
			var returned_arrays: Array = returned.render_mesh.surface_get_arrays(0)
			equal(returned_arrays[Mesh.ARRAY_INDEX],first_indices,"returning facing retains exact triangle topology across walk/run transition")
			equal(returned_arrays[Mesh.ARRAY_TEX_UV],first_uvs,"returning facing retains exact atlas UVs across walk/run transition")
	check(sizes_seen.size()>1,"round-trip fixture exercises unequal facing vertex counts")


func _test_continuous_mesh(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var state := PlayerState.new()
	state.entity_id = 412
	state.velocity_y = MovementTuning.BASE_SPEED
	state.aim_x = 0
	state.aim_y = 1000
	state.movement_mode = PlayerState.MovementMode.WALK
	var before := state.canonical_values()
	for id: String in ["wa_bidi","jan_wicked","fluup"]:
		for direction: int in 8:
			state.aim_x = EightDirectionResolver.FIXED_VECTORS[direction].x
			state.aim_y = EightDirectionResolver.FIXED_VECTORS[direction].y
			state.velocity_x = state.aim_x*400
			state.velocity_y = state.aim_y*400
			var first := presenter.movement_frame(id,state,30,config,false,0.0)
			var a: PackedVector3Array = first.render_mesh.get_meta("cpu_vertices")
			var middle := presenter.movement_frame(id,state,30,config,false,0.5/24.0)
			var m: PackedVector3Array = middle.render_mesh.get_meta("cpu_vertices")
			var last := presenter.movement_frame(id,state,30,config,false,1.0/24.0)
			var b: PackedVector3Array = last.render_mesh.get_meta("cpu_vertices")
			equal(first.render_mesh,last.render_mesh,"streamed buffer reused without rebuilding mesh")
			var changed := false
			for index: int in a.size():
				check(m[index].distance_to(a[index].lerp(b[index],0.5))<0.001,"subframe geometry is exact midpoint, not a ghosted sprite")
				changed = changed or a[index].distance_to(m[index])>0.001
			check(changed,"every size/heading has intermediate gait geometry")
			var repeat := presenter.movement_frame(id,state,30,config,false,1.0/24.0)
			equal(repeat.render_mesh,last.render_mesh,"repeated world/fog request reuses streamed mesh")
			state.entity_id += 1
			var other := presenter.movement_frame(id,state,30,config,false,0.4)
			check(other.render_mesh != last.render_mesh,"two players of same character do not share mutable mesh")
			state.entity_id -= 1
			check(presenter.fullbody_art.render_meshes.size()<=Art.RENDER_CACHE_LIMIT,"streaming buffers bounded")
	state.aim_x = 0
	state.aim_y = 1000
	state.velocity_x = 0
	state.velocity_y = MovementTuning.BASE_SPEED
	equal(state.canonical_values(),before,"continuous art leaves authority unchanged")


func _test_continuous_modifiers(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var state := PlayerState.new(902)
	state.movement_mode = PlayerState.MovementMode.WALK
	var art: RefCounted = presenter.fullbody_art
	for id: String in ["wa_bidi","jan_wicked","fluup"]:
		for direction: int in 8:
			state.aim_x = EightDirectionResolver.FIXED_VECTORS[direction].x
			state.aim_y = EightDirectionResolver.FIXED_VECTORS[direction].y
			var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[(direction+3)%8]
			state.velocity_x = travel.x*150
			state.velocity_y = travel.y*150
			state.cast_recovery_ticks = 4
			var before := state.canonical_values()
			var first := presenter.movement_frame(id,state,30,config,false,0.25)
			var first_vertices: PackedVector3Array = first.render_mesh.get_meta("cpu_vertices")
			var expected: PackedVector3Array = art.build_vertices(id,"walk",direction,(direction+3)%8,0.25,true,1.0,first.cast_weight,first.stride_weight)
			for index: int in expected.size(): check(first_vertices[index].distance_to(expected[index])<0.001,"continuous modifiers use actual bone pose, not quantized arms/stride")
			equal(state.canonical_values(),before,"continuous modifiers leave authority untouched")
			var cached_count: int = art.meshes.size()
			state.cast_recovery_ticks = 5
			var second := presenter.movement_frame(id,state,30,config,false,0.25)
			check(second.cast_weight > first.cast_weight,"adjacent120Hz recovery ticks do not collapse to one of five weights")
			equal(art.meshes.size(),cached_count,"cast progress does not churn GPU source cache")
			var change := 0.0
			var second_vertices: PackedVector3Array = second.render_mesh.get_meta("cpu_vertices")
			for index: int in expected.size(): change=maxf(change,first_vertices[index].distance_to(second_vertices[index]))
			check(change > 0.001 and change < 4.0,"adjacent cast tick changes are visible but bounded %s heading%d delta%.4f" % [id,direction,change])
			state.cast_recovery_ticks = 0
			var previous_weight := -1.0
			for speed: int in range(100,106):
				state.velocity_x=travel.x*speed
				state.velocity_y=travel.y*speed
				var frame := presenter.movement_frame(id,state,30,config,false,0.25)
				check(frame.stride_weight>previous_weight,"fine acceleration/braking has continuous stride amplitude")
				previous_weight=frame.stride_weight
			check(art.meshes.size()==cached_count,"speed changes share unmodified source poses")
			var entry: Dictionary = art.entries[id]
			var sampled: Dictionary = art.sample(entry.body,"walk",direction,(direction+3)%8,0.25)
			var anchors: Dictionary = entry.directions[Art.DIRS[direction]].anchors
			var base: Dictionary = Art.retarget(anchors,sampled.rest,sampled.points,true)
			var cast_sample: Dictionary = art.sample(entry.body,"cast",direction,(direction+3)%8,1.0)
			var cast_target: Dictionary = Art.retarget(anchors,cast_sample.rest,cast_sample.points)
			for step: int in 11:
				var target := base.duplicate()
				Art.blend_cast_arms(target,cast_target,float(step)/10.0)
				for side: String in ["l","r"]:
					for chain: Array in [["shoulder_","elbow_"],["elbow_","hand_"]]:
						var a: String = chain[0]+side
						var b: String = chain[1]+side
						check(absf(target[a].distance_to(target[b])-base[a].distance_to(base[b]))<0.001,"cast blending preserves arm bone lengths across recovery")
				for joint: String in ["pelvis","hip_l","hip_r","knee_l","knee_r","ankle_l","ankle_r"]:
					equal(target[joint],base[joint],"casting never resets or alters the lower-body gait")


func _test_locomotion_settle(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var state := PlayerState.new(701)
	state.aim_x=0
	state.aim_y=1000
	state.velocity_y=MovementTuning.BASE_SPEED
	state.movement_mode=PlayerState.MovementMode.WALK
	var walk := presenter.movement_frame("oh_tipi",state,60,config,false,0.25)
	var old: PackedVector3Array = walk.render_mesh.get_meta("cpu_vertices")
	state.movement_mode=PlayerState.MovementMode.SPRINT
	var before := state.canonical_values()
	var sprint := presenter.movement_frame("oh_tipi",state,60.6,config,false,0.25)
	var settled: PackedVector3Array = sprint.render_mesh.get_meta("cpu_vertices")
	var target: PackedVector3Array = sprint.mesh.get_meta("cpu_vertices")
	for index: int in old.size():
		check(settled[index].distance_to(target[index])<=5.001,"locomotion transition correction capped at5px")
		check(settled[index].distance_to(old[index])<=target[index].distance_to(old[index])+0.001,"walk/run switch reduces rather than exaggerates pop")
	var finished := presenter.movement_frame("oh_tipi",state,66,config,false,0.25)
	var final_vertices: PackedVector3Array = finished.render_mesh.get_meta("cpu_vertices")
	for index: int in target.size(): check(final_vertices[index].distance_to(target[index])<0.001,"locomotion settles within70ms")
	equal(state.canonical_values(),before,"settling leaves gameplay timing and velocity untouched")
	state.movement_mode=PlayerState.MovementMode.WALK
	presenter.movement_frame("oh_tipi",state,66.6,config,false,0.25)
	state.slide_ticks=12
	state.movement_mode=PlayerState.MovementMode.SLIDE
	var slide := presenter.movement_frame("oh_tipi",state,67.2,config,false,0.25)
	check(not presenter.fullbody_art.render_meshes["oh_tipi/701/0"].has("settle"),"low exposure pose cancels locomotion-only smoothing immediately")
	equal(slide.action,"slide","slide is visible immediately")


func _test_fluid_motion(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var state := PlayerState.new()
	state.aim_y = 1000
	state.velocity_x = 300000
	state.air_height = 20000
	state.hop_ticks = 20
	state.wall_skim_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)
	var first := presenter.movement_frame("oh_tipi",state,30,config,false,-1.0)
	state.wall_skim_ticks -= 10
	var next := presenter.movement_frame("oh_tipi",state,30,config,false,-1.0)
	check(next.sample_phase > first.sample_phase,"moving preview wallrun retains timer fallback when distance phase is absent")
	state.wall_skim_ticks = 0
	state.air_vertical_velocity = MovementTuning.CHARGED_JUMP_VERTICAL_SPEED
	var rise := presenter.movement_frame("oh_tipi",state,30,config)
	state.air_vertical_velocity = 1000
	var apex := presenter.movement_frame("oh_tipi",state,30,config)
	check(apex.sample_phase > rise.sample_phase,"rising pose unfolds approaching apex")
	state.air_vertical_velocity = -1000
	var fall := presenter.movement_frame("oh_tipi",state,30,config)
	state.air_vertical_velocity = -MovementTuning.AIR_TERMINAL_FALL_SPEED
	var fast := presenter.movement_frame("oh_tipi",state,30,config)
	check(fast.sample_phase > fall.sample_phase,"fall gathers feet as descent accelerates")
	state.air_height = 0
	state.hop_ticks = 0
	state.air_vertical_velocity = 0
	state.movement_mode = PlayerState.MovementMode.WALK
	state.velocity_x = MovementTuning.BASE_SPEED
	var full := presenter.movement_frame("oh_tipi",state,30,config,false,0.25)
	state.velocity_x = 60000
	var slow := presenter.movement_frame("oh_tipi",state,30,config,false,0.25)
	check(slow.stride_weight < full.stride_weight,"braking reduces stride without slowing input")
	state.velocity_x = MovementTuning.BASE_SPEED
	var a := presenter.movement_frame("oh_tipi",state,30,config,false,0.0)
	var b := presenter.movement_frame("oh_tipi",state,30,config,false,1.0/24.0)
	check(a.mesh != b.mesh,"half-old-step has distinct cached geometry")
	var loop := presenter.movement_frame("oh_tipi",state,30,config,false,1.0)
	equal(a.mesh,loop.mesh,"loop boundary reuses exact starting mesh")
	state.cast_recovery_ticks = config.milliseconds_to_ticks(90)
	var recovery_start := presenter.movement_frame("oh_tipi",state,30,config,false,0.25)
	state.cast_recovery_ticks = 1
	var before := state.canonical_values()
	var recovery_end := presenter.movement_frame("oh_tipi",state,30,config,false,0.25)
	check(recovery_end.cast_weight < recovery_start.cast_weight,"cast arms relax during recovery")
	equal(recovery_end.sample_phase,recovery_start.sample_phase,"recovery never resets legs")
	equal(state.canonical_values(),before,"refinement cannot change movement or combat state")
	var invalid: Dictionary = presenter.fullbody_art.frame("oh_tipi",state,NAN,config,NAN)
	check(is_finite(float(invalid.sample_phase)),"invalid preview clock is sanitized")
	for body: String in ["small","middle","large"]:
		var at_start: Dictionary = presenter.fullbody_art.sample(body,"walk",0,0,0.0).points
		var near_end: Dictionary = presenter.fullbody_art.sample(body,"walk",0,0,0.99999).points
		for joint: String in at_start:
			check(at_start[joint].distance_to(near_end[joint]) < 0.01,"gait loop is continuous")
		for index: int in 24:
			var phase := float(index)/24.0
			var sample: Dictionary = presenter.fullbody_art.sample(body,"walk",0,0,phase).points
			var frames: Array = presenter.fullbody_art.motions.bodies[body].clips["walk/0/0"]
			var key_first := floori(phase*frames.size())
			var key_second := (key_first+1)%frames.size()
			for joint: String in sample:
				var low: Vector2 = Art.vec(frames[key_first].points[joint])
				var high: Vector2 = Art.vec(frames[key_second].points[joint])
				check(sample[joint].x >= minf(low.x,high.x)-0.001 and sample[joint].x <= maxf(low.x,high.x)+0.001,"curve respects authored x envelope")
				check(sample[joint].y >= minf(low.y,high.y)-0.001 and sample[joint].y <= maxf(low.y,high.y)+0.001,"curve respects authored y envelope")
	for id: String in ["wa_bidi","jan_wicked","fluup"]:
		var entry: Dictionary = presenter.fullbody_art.entries[id]
		for facing: int in [0,4]:
			var contact_a: Dictionary = presenter.fullbody_art.sample(entry.body,"walk",facing,facing,0.0)
			var contact_b: Dictionary = presenter.fullbody_art.sample(entry.body,"walk",facing,facing,0.5)
			var anchors: Dictionary = entry.directions[Art.DIRS[facing]].anchors
			var pose_a: Dictionary = Art.retarget(anchors,contact_a.rest,contact_a.points,true)
			var pose_b: Dictionary = Art.retarget(anchors,contact_b.rest,contact_b.points,true)
			check((pose_a.ankle_l-pose_a.ankle_r).distance_to(pose_b.ankle_l-pose_b.ankle_r)>1.0,"front/back feet alternate independently of pelvis bob")
			for pose: Dictionary in [pose_a,pose_b]:
				for side: String in ["l","r"]:
					for segment: Array in [["hip_","knee_"],["knee_","ankle_"]]:
						var start: String = segment[0]+side
						var end: String = segment[1]+side
						check(absf(pose[start].distance_to(pose[end])-Art.vec(anchors[start]).distance_to(Art.vec(anchors[end])))<0.01,"foot solve preserves bone length")
	# All size/facing/travel pairs retain finite rigid-bone output at the added
	# in-between phase; inspect every vertex rather than trusting clip metadata.
	for id: String in ["wa_bidi","jan_wicked","fluup"]:
		for aim: int in 8:
			for travel: int in 8:
				state.aim_x = EightDirectionResolver.FIXED_VECTORS[aim].x
				state.aim_y = EightDirectionResolver.FIXED_VECTORS[aim].y
				state.velocity_x = EightDirectionResolver.FIXED_VECTORS[travel].x*300
				state.velocity_y = EightDirectionResolver.FIXED_VECTORS[travel].y*300
				var frame := presenter.movement_frame(id,state,30,config,false,1.0/24.0)
				var arrays: Array = frame.mesh.surface_get_arrays(0)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: check(vertex.is_finite(),"smooth mixed-direction vertex finite")
	check(presenter.fullbody_art.meshes.size() <= Art.CACHE_LIMIT,"refined sampling keeps existing cache bound")


func _test_retro_secondary_motion(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var art: RefCounted = presenter.fullbody_art
	equal(Art.secondary_pose_amount("jumpsquat",0.0),0.0,"secondary anticipation begins without a size pop")
	check(Art.secondary_pose_amount("jumpsquat",1.0)>Art.secondary_pose_amount("jumpsquat",0.5),"held charge visibly gathers the torso")
	equal(Art.secondary_pose_amount("land",0.0),Art.MAX_BODY_COMPRESSION_PIXELS,"contact has a bounded squash response")
	equal(Art.secondary_pose_amount("land",1.0),0.0,"landing response settles to original proportions")
	check(Art.secondary_pose_amount("jump",0.15)<0.0,"takeoff extends the chest slightly")
	equal(Art.secondary_pose_amount("jump",0.85),0.0,"takeoff extension is gone before the apex")
	for action: String in ["walk","sprint","slide","wavedash","air_dodge","defeated","stunned"]:
		equal(Art.secondary_pose_amount(action,0.5),0.0,"secondary response never delays or obscures low/protected/control poses")
	for id: String in ["s_wayne","oh_tipi","red_baron"]:
		var entry: Dictionary = art.entries[id]
		for direction: int in 8:
			var anchors: Dictionary = entry.directions[Art.DIRS[direction]].anchors
			var sample: Dictionary = art.sample(entry.body,"jumpsquat",direction,direction,0.7)
			var before: Dictionary = Art.retarget(anchors,sample.rest,sample.points)
			for amount: float in [-Art.MAX_BODY_EXTENSION_PIXELS,0.0,Art.MAX_BODY_COMPRESSION_PIXELS]:
				var target := before.duplicate()
				Art.apply_secondary_pose(target,anchors,amount,direction)
				for joint: String in ["pelvis","hip_l","hip_r","knee_l","knee_r","ankle_l","ankle_r","toe_l","toe_r"]:
					equal(target[joint],before[joint],"every size/facing preserves exact pelvis, leg and foot registration")
				check((target.head-target.neck).is_equal_approx(before.head-before.neck),"skull translates rigidly without changing its bone or proportions")
				for side: String in ["l","r"]:
					for chain: Array in [["shoulder_","elbow_"],["elbow_","hand_"]]:
						var a: String = chain[0]+side
						var b: String = chain[1]+side
						check(absf(target[a].distance_to(target[b])-before[a].distance_to(before[b]))<0.001,"secondary inertia cannot change arm lengths")
			for action: String in ["jumpsquat","jump","double_jump","walljump","slide_jump","land"]:
				var phase := 0.7 if action == "jumpsquat" else 0.15
				var stable: PackedVector3Array = art.build_vertices(id,action,direction,direction,phase,false,0.0,1.0,1.0,false)
				var lively: PackedVector3Array = art.build_vertices(id,action,direction,direction,phase,false,0.0,1.0,1.0,true)
				var skin: Dictionary = art.skin_tables["%s/%d" % [id,direction]]
				var head_index: int = skin.parts.find("head")
				var first_head := -1
				var changed := false
				for index: int in stable.size():
					check(lively[index].is_finite(),"body-only response is finite across all three sizes/eight headings")
					var source_point: Vector2 = skin.points[index]
					check(lively[index].distance_to(Vector3(source_point.x+16.0,source_point.y+20.0,0.0))<=12.001,"secondary motion stays inside the existing12px nonlocomotion deformation envelope")
					changed = changed or lively[index].distance_to(stable[index])>0.001
					if skin.primary[index] == head_index and skin.secondary[index] == head_index:
						if first_head < 0: first_head=index
						else: check(absf(lively[index].distance_to(lively[first_head])-stable[index].distance_to(stable[first_head]))<0.001,"rigid skull mesh distances are preserved")
				check(changed,"anticipation/takeoff/contact produces visible nonzero body response")
	var state := PlayerState.new(977)
	state.jumpsquat_active = true
	state.jumpsquat_ticks = config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS)
	var canonical := state.canonical_values()
	var lively: Dictionary = art.frame("oh_tipi",state,30,config,0.0,false)
	check(float(lively.secondary_body_response)>0.0,"normal presentation enables restrained squash")
	var reduced: Dictionary = art.frame("oh_tipi",state,30,config,0.0,true)
	equal(reduced.secondary_body_response,0.0,"reduced motion suppresses new secondary deformation")
	equal(reduced.pivot,lively.pivot,"reduced motion retains the same ground anchor")
	equal(reduced.display_height,lively.display_height,"size identity is unchanged between accessibility modes")
	equal(state.canonical_values(),canonical,"secondary art never changes health, motion, exposure, costs or collision")
	for id: String in ["wa_bidi","jan_wicked","fluup"]:
		var authored: Dictionary = art.frame(id,state,30,config,0.0,false)
		equal(authored.art_pose_quality,"authored key pose","painted low/air keyframes retain their reviewed corrections")
		equal(authored.secondary_body_response,0.0,"authored skulls are never globally stretched")


func _test_observer(presenter: CartoonChampionPresenter) -> void:
	var harness := preload("res://tests/support/chemistry_coach_harness.gd").new()
	check(harness.configure_fixture(), "observer fixture")
	harness.cartoon_champion_presenter = presenter
	var state: PlayerState = harness.world.player()
	state.air_height = 20000
	state.hop_ticks = 20
	state.air_dodge_ticks = 12
	state.velocity_x = 200000
	state.aim_y = 1000
	state.spawn_protection_ticks = 0
	harness.actor_motion_history.capture(harness.world.players)
	var before := state.canonical_values()
	var overlay: Dictionary = harness._pov_observer_overlay_frame(20,0)
	check(overlay.has("fullbody_pose"), "post-fog body uses candidate frame")
	if overlay.has("fullbody_pose"):
		var direct := presenter.movement_frame(harness._champion_visual_id(state),state,20,harness.world.config,false,harness.actor_motion_history.gait_phase(state.entity_id))
		equal(overlay.fullbody_pose.get("mesh"), direct.get("mesh"), "same retained mesh for world/fog, no static redraw")
		equal(overlay.fullbody_pose.get("pivot"), Vector2(64,104), "observer has correct128px registration")
	equal(before,state.canonical_values(),"observer paint is presentation-only")
	state.health = 0
	equal(harness._pov_observer_overlay_frame(20,0),{},"dead observer gets no visibility exemption")
	harness.free()


func _test_action_readability(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var art: RefCounted = presenter.fullbody_art
	equal(Art.secondary_pose_amount("land",0.10),Art.MAX_BODY_COMPRESSION_PIXELS,"brief contact hold makes landing distinct from takeoff")
	equal(Art.secondary_pose_amount("land",0.90),0.0,"contact releases before the landing window ends")
	equal(Art.secondary_pose_amount("jump",0.20),-Art.MAX_BODY_EXTENSION_PIXELS,"takeoff holds its distinct extended silhouette briefly")
	check(Art.secondary_pose_amount("jumpsquat",1.0)>2.5,"full charge has a legible but bounded torso gather")
	var walk := absf(Art.locomotion_lean_radians("walk",0.0,2))
	var sprint := absf(Art.locomotion_lean_radians("sprint",0.0,2))
	var wallrun := absf(Art.locomotion_lean_radians("wallrun",0.0,2))
	check(walk>0.0 and sprint>walk*2.0 and wallrun>sprint,"walk/run/wallrun have distinct bounded travel posture")
	check(wallrun<=deg_to_rad(5.5),"readability cue never becomes a large body rotation")
	for action: String in ["walk","sprint","wallrun"]:
		check(is_equal_approx(Art.locomotion_lean_radians(action,0.0,2),Art.locomotion_lean_radians(action,1.0,2)),"stride posture wraps continuously")
		check(is_equal_approx(Art.locomotion_lean_radians(action,0.0,2),Art.locomotion_lean_radians(action,0.5,2)),"both alternating foot contacts receive equal emphasis")
		check(is_equal_approx(Art.locomotion_lean_radians(action,0.25,2),-Art.locomotion_lean_radians(action,0.25,6)),"left and right posture are symmetric")
		equal(Art.locomotion_lean_radians(action,0.25,0),0.0,"front-facing gait does not acquire an invented sideways tilt")
		equal(Art.locomotion_lean_radians(action,0.25,4),0.0,"back-facing gait does not acquire an invented sideways tilt")
		equal(Art.locomotion_lean_radians(action,0.25,2,0.0),0.0,"posture settles with braking instead of leaning at rest")
		check(is_finite(Art.locomotion_lean_radians(action,NAN,2)),"invalid preview phase cannot poison pose")
	for action: String in ["idle","slide","wavedash","air_dodge","roll","jumpsquat","jump","land","defeated","stunned","rooted"]:
		equal(Art.locomotion_lean_radians(action,0.25,2),0.0,"locomotion cue never obscures another action or exposure pose")
	for id: String in ["s_wayne","oh_tipi","red_baron"]:
		var entry: Dictionary = art.entries[id]
		for direction: int in 8:
			var anchors: Dictionary = entry.directions[Art.DIRS[direction]].anchors
			for action: String in ["walk","sprint","wallrun"]:
				var sampled: Dictionary = art.sample(entry.body,action,direction,direction,0.25)
				var before: Dictionary = Art.retarget(anchors,sampled.rest,sampled.points,true)
				var target := before.duplicate()
				Art.apply_locomotion_lean(target,Art.locomotion_lean_radians(action,0.25,direction))
				for joint: String in ["pelvis","hip_l","hip_r","knee_l","knee_r","ankle_l","ankle_r","toe_l","toe_r"]:
					equal(target[joint],before[joint],"distinct travel posture leaves every planted lower-body joint exact")
				check((target.head-target.neck).is_equal_approx(before.head-before.neck),"locomotion preserves skull orientation and size")
				check(is_equal_approx(target.neck.distance_to(target.pelvis),before.neck.distance_to(before.pelvis)),"locomotion preserves torso bone length")
				for side: String in ["l","r"]:
					for chain: Array in [["shoulder_","elbow_"],["elbow_","hand_"]]:
						var a: String = chain[0]+side
						var b: String = chain[1]+side
						check(absf(target[a].distance_to(target[b])-before[a].distance_to(before[b]))<0.001,"distinct travel posture preserves every arm segment")
				var stable: PackedVector3Array = art.build_vertices(id,action,direction,direction,0.25,false,0.0,1.0,1.0,false)
				var lively: PackedVector3Array = art.build_vertices(id,action,direction,direction,0.25,false,0.0,1.0,1.0,true)
				var changed := false
				for index: int in lively.size():
					check(lively[index].is_finite(),"all three sizes/eight directions retain finite travel geometry")
					changed = changed or lively[index].distance_to(stable[index])>0.001
				if direction in [1,2,3,5,6,7]: check(changed,"visible lean distinguishes travel from stable accessibility pose")
	var state := PlayerState.new(978)
	state.movement_mode = PlayerState.MovementMode.SPRINT
	state.aim_y = 1000
	state.velocity_x = MovementTuning.BASE_SPEED
	var canonical := state.canonical_values()
	var lively: Dictionary = art.frame("oh_tipi",state,30,config,0.25,false)
	var reduced: Dictionary = art.frame("oh_tipi",state,30,config,0.25,true)
	check(float(lively.secondary_body_lean)>0.0,"normal presentation exposes the sprint posture cue")
	equal(reduced.secondary_body_lean,0.0,"reduced motion suppresses new locomotion lean")
	equal(reduced.aim_index,lively.aim_index,"posture never delays or substitutes facing direction")
	equal(reduced.pivot,lively.pivot,"accessibility modes share exact feet registration")
	equal(state.canonical_values(),canonical,"readability changes do not alter costs, collision or authority")
	state.movement_mode = PlayerState.MovementMode.SLIDE
	state.slide_ticks = 12
	for id: String in ["wa_bidi","jan_wicked","fluup"]:
		var authored: Dictionary = art.frame(id,state,30,config,0.0,false)
		equal(authored.art_pose_quality,"authored key pose","new posture never rewrites authored special skins")
		equal(authored.secondary_body_lean,0.0,"authored low pose remains untouched")


func _test_forced_action_dispatch(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var art: RefCounted = presenter.fullbody_art
	var state := PlayerState.new(981)
	state.velocity_x = MovementTuning.BASE_SPEED
	state.movement_mode = PlayerState.MovementMode.WALK
	var controls := {
		PlayerState.ControlState.LAUNCHED:"hit", PlayerState.ControlState.GRAPPLED:"hit",
		PlayerState.ControlState.CHARGING:"cast", PlayerState.ControlState.STUNNED:"stunned",
		PlayerState.ControlState.ROOTED:"rooted",
	}
	for control: int in controls:
		state.control_state = control
		state.cast_recovery_ticks = 4
		var before := state.canonical_values()
		var frame: Dictionary = art.frame("oh_tipi",state,30,config,0.25)
		equal(frame.action,controls[control],"forced control cannot masquerade as a frozen walking cycle")
		if frame.action in ["hit","stunned"]:
			check(not frame.independent_cast_pose,"forced reaction is not masked by residual casting arms")
		equal(state.canonical_values(),before,"control presentation never changes force, timer, exposure or paid state")
	state.control_state = PlayerState.ControlState.FREE
	state.cast_recovery_ticks = 0
	var modes := {
		PlayerState.MovementMode.LAUNCHED:"hit", PlayerState.MovementMode.GRAPPLED:"hit",
		PlayerState.MovementMode.IMPACT_RECOVERY:"hit", PlayerState.MovementMode.CHARGING:"cast",
		PlayerState.MovementMode.STUNNED:"stunned", PlayerState.MovementMode.ROOTED:"rooted",
	}
	for mode: int in modes:
		state.movement_mode = mode
		equal(Art.action_for_state(state),modes[mode],"movement-only control flags retain the same readable reaction")
	state.movement_mode = PlayerState.MovementMode.IMPACT_RECOVERY
	state.impact_recovery_ticks = config.milliseconds_to_ticks(MovementTuning.IMPACT_RECOVERY_DURATION_MS)
	var start: Dictionary = art.frame("oh_tipi",state,30,config,0.25)
	state.impact_recovery_ticks = 1
	var end: Dictionary = art.frame("oh_tipi",state,30,config,0.25)
	check(end.motion_phase>start.motion_phase,"impact reaction settles with its actual recovery timer, not global time")
	state.impact_recovery_ticks = 0
	state.movement_mode = PlayerState.MovementMode.WALK
	equal(Art.action_for_state(state),"walk","ordinary pose returns immediately when authority clears recovery")
	state.control_state = PlayerState.ControlState.GRAPPLED
	var held: Dictionary = art.frame("oh_tipi",state,30,config,0.0)
	var later: Dictionary = art.frame("oh_tipi",state,60,config,0.9)
	check(is_equal_approx(float(held.motion_phase),float(later.motion_phase)),"held forced recoil cannot loop or borrow frozen locomotion phase")
	state.health = 0
	equal(Art.action_for_state(state),"defeated","defeat retains precedence over every reaction")


func _test_real_control_journey(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	for id: String in ["wa_bidi", "jan_wicked", "fluup"]:
		for reduced: bool in [false, true]:
			var actor := PlayerState.new(983)
			actor.position_x = 400000
			actor.position_y = 300000
			var collision := CollisionWorld.new()
			check(MovementSystem.apply_control_state(actor, PlayerState.ControlState.LAUNCHED, 100, Vector2i(1000,0), 240000, config), "real launch admitted for art journey")
			var saw_recovery := false
			for tick: int in 80:
				MovementSystem.step(actor, SimCommand.new(), config, collision)
				var before := actor.canonical_values()
				var frame := presenter.movement_frame(id, actor, 6000+tick*0.5, config, reduced, 0.0)
				if actor.control_state == PlayerState.ControlState.LAUNCHED or actor.impact_recovery_ticks > 0:
					equal(frame.action, "hit", "actual launch/recovery never looks like frozen walking")
				if actor.impact_recovery_ticks > 0: saw_recovery = true
				equal(actor.canonical_values(), before, "actual forced movement is untouched by visual sampling")
			check(saw_recovery, "launch expires through real bounded impact recovery")
			equal(actor.control_state, PlayerState.ControlState.FREE, "real force timer ends")
			equal(actor.impact_recovery_ticks, 0, "real recovery timer ends")
			check(Art.action_for_state(actor) in ["idle", "walk"], "voluntary presentation resumes after real recovery")


func _test_wall_contact_pose(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var art: RefCounted = presenter.fullbody_art
	var state := PlayerState.new(982)
	state.wall_skim_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)-12
	state.wall_skim_x = 1000
	state.wall_skim_y = 0
	state.movement_mode = PlayerState.MovementMode.WALL_SKIM
	state.air_height = 20000
	for aim: int in 8:
		state.aim_x = EightDirectionResolver.FIXED_VECTORS[aim].x
		state.aim_y = EightDirectionResolver.FIXED_VECTORS[aim].y
		var before := state.canonical_values()
		var paused: Dictionary = art.frame("oh_tipi",state,30,config,-1.0)
		equal(paused.travel_index,2,"blocked preview keeps wall tangent independent of moving cursor")
		equal(paused.motion_phase,0.0,"stationary timer fallback holds a braced contact without marching")
		var retained: Dictionary = art.frame("oh_tipi",state,30,config,0.375,false,Vector2i(0,-1000))
		state.wall_skim_ticks -= 1
		var continued: Dictionary = art.frame("oh_tipi",state,30.5,config,0.375,false,Vector2i(0,-1000))
		equal(retained.travel_index,4,"actual retained wall travel takes priority over entry tangent and aim")
		equal(continued.motion_phase,retained.motion_phase,"unchanged wall distance holds the exact stride despite advancing timer")
		equal(continued.aim_index,aim,"wall body never substitutes tangent for spell aim")
		state.wall_skim_ticks += 1
		equal(state.canonical_values(),before,"blocked wall presentation never changes attachment or movement")
	state.velocity_x = MovementTuning.BASE_SPEED
	var first: Dictionary = art.frame("oh_tipi",state,30,config,0.375,false,Vector2i.RIGHT)
	var moving: Dictionary = art.frame("oh_tipi",state,30.5,config,0.425,false,Vector2i.RIGHT)
	check(moving.motion_phase>first.motion_phase,"real wall travel advances the supplied continuous stride")
	for id: String in ["wa_bidi","jan_wicked","fluup"]:
		var held: Dictionary = art.frame(id,state,30,config,0.375,false,Vector2i.RIGHT)
		var later: Dictionary = art.frame(id,state,36,config,0.375,false,Vector2i.RIGHT)
		equal(held.mesh,later.mesh,"all three sizes retain the exact cached wall pose for unchanged travel")
		equal(held.travel_index,2,"wall travel direction is size-independent")


func _test_weight_transfer_and_followthrough(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var art: RefCounted = presenter.fullbody_art
	for action: String in ["walk","sprint","wallrun"]:
		for heading: int in 8:
			var first := Art.gait_counterbalance_radians(action,0.0,heading)
			check(is_equal_approx(first,-Art.gait_counterbalance_radians(action,0.5,heading)),"opposite support feet receive equal opposite chest transfer")
			check(is_equal_approx(first,Art.gait_counterbalance_radians(action,1.0,heading)),"weight transfer wraps smoothly at the stride boundary")
			equal(Art.gait_counterbalance_radians(action,0.0,heading,0.0),0.0,"weight transfer vanishes continuously at rest")
			for phase: float in [0.0,0.125,0.25,0.375,0.5,0.75,1.0]:
				check(absf(Art.gait_counterbalance_radians(action,phase,heading))<=deg_to_rad(Art.MAX_GAIT_COUNTERBALANCE_DEGREES)+0.0001,"support transfer stays inside its small rigid-rotation budget")
	for action: String in ["idle","hit","cast","slide","roll","jump","land","defeated","stunned"]:
		equal(Art.gait_counterbalance_radians(action,0.0,0),0.0,"support transfer never animates another action or exposure pose")
	for id: String in art.entries:
		var entry: Dictionary = art.entries[id]
		for aim: int in 8:
			var travel := (aim+3)%8
			var sampled: Dictionary = art.sample(entry.body,"sprint",aim,travel,0.125)
			var anchors: Dictionary = entry.directions[Art.DIRS[aim]].anchors
			var base: Dictionary = Art.retarget(anchors,sampled.rest,sampled.points,true)
			var balanced := base.duplicate()
			Art.apply_locomotion_lean(balanced,Art.gait_counterbalance_radians("sprint",0.125,travel))
			_check_upper_body_invariants(base,balanced,"counterbalance")
			var cast_sample: Dictionary = art.sample(entry.body,"cast",aim,travel,1.0)
			var cast_target: Dictionary = Art.retarget(anchors,cast_sample.rest,cast_sample.points)
			for weight: float in [0.0,0.25,0.5,0.75,1.0]:
				var direct := balanced.duplicate()
				var delayed := balanced.duplicate()
				Art.blend_cast_arms(direct,cast_target,weight)
				Art.blend_cast_arms(delayed,cast_target,weight,true)
				_check_upper_body_invariants(balanced,delayed,"cast follow-through")
				for side: String in ["l","r"]:
					var elbow := "elbow_"+side
					var hand := "hand_"+side
					equal(delayed[elbow],direct[elbow],"follow-through leaves upper-arm recovery exact")
					if weight == 0.0 or weight == 1.0:
						equal(delayed[hand],direct[hand],"release and rest endpoints remain exact without a longer action window")
					else:
						var cast_lower: Vector2 = cast_target[hand]-cast_target[elbow]
						var direct_lower: Vector2 = direct[hand]-direct[elbow]
						var delayed_lower: Vector2 = delayed[hand]-delayed[elbow]
						check(absf(cast_lower.angle_to(delayed_lower))<=absf(cast_lower.angle_to(direct_lower))+0.0001,"hand follows behind elbow along bounded recovery arc without overshoot")
	var state := PlayerState.new(983)
	state.aim_x = 0
	state.aim_y = 1000
	state.velocity_y = MovementTuning.BASE_SPEED
	state.movement_mode = PlayerState.MovementMode.SPRINT
	state.cast_recovery_ticks = 5
	var before := state.canonical_values()
	var live: Dictionary = art.frame("oh_tipi",state,30,config,0.0,false)
	var reduced: Dictionary = art.frame("oh_tipi",state,30,config,0.0,true)
	check(absf(float(live.gait_counterbalance))>0.0,"live shared rig exposes the support transfer")
	equal(reduced.gait_counterbalance,0.0,"reduced motion disables optional counterbalance")
	equal(live.cast_weight,reduced.cast_weight,"accessibility never extends casting or recovery")
	equal(state.canonical_values(),before,"support and recovery refinements leave authoritative state byte-identical")


func _check_upper_body_invariants(before: Dictionary, after: Dictionary, label: String) -> void:
	for joint: String in ["pelvis","hip_l","hip_r","knee_l","knee_r","ankle_l","ankle_r","toe_l","toe_r"]:
		equal(after[joint],before[joint],label+" retains exact pelvis, leg and planted-foot coordinates")
	check((after.head-after.neck).is_equal_approx(before.head-before.neck),label+" retains rigid skull size and orientation")
	check(absf(after.neck.distance_to(after.pelvis)-before.neck.distance_to(before.pelvis))<0.001,label+" retains torso bone length")
	for side: String in ["l","r"]:
		for chain: Array in [["shoulder_","elbow_"],["elbow_","hand_"]]:
			var start: String = chain[0]+side
			var end: String = chain[1]+side
			check(absf(after[start].distance_to(after[end])-before[start].distance_to(before[end]))<0.001,label+" retains every arm-bone length")
