class_name InterceptionShowcase
extends RefCounted

# Explicit fresh solo encounter setup. No mid-encounter resource mutation;
# both sides use the same paid command and simulation paths as ordinary play.
static func configure(world: SimWorld, champions: ChampionCatalog, abilities: AbilityCatalog, campus: SanctumCampusLayout) -> Dictionary:
	var anchors := InterceptionPractice.spawn_contract(campus)
	var player_profile := InterceptionPractice.player_profile(abilities)
	var opponent_profile := InterceptionPractice.opponent_profile(abilities)
	if anchors.is_empty() or player_profile.is_empty() or opponent_profile.is_empty():
		return {}
	var actors: Array[PlayerState] = []
	for index: int in range(2):
		var profile: Dictionary = player_profile if index == 0 else opponent_profile
		var position: Vector2i = anchors.player_spawn_fixed if index == 0 else anchors.opponent_spawn_fixed
		if not world.collision.can_occupy(position, MovementTuning.PLAYER_RADIUS):
			return {}
		var actor := PlayerState.new(index + 1)
		if not champions.apply_to_player(actor, String(profile.champion_id)):
			return {}
		actor.team_id = index + 1
		actor.position_x = position.x
		actor.position_y = position.y
		actor.aim_x = 1000 if index == 0 else -1000
		actor.aim_y = 0
		for role: String in profile.slots:
			if not actor.place_proven_spell(int(profile.slots[role]) - 1, int(profile.wires[role])):
				return {}
		actors.append(actor)
	world.players.assign(actors)
	return {"player_profile": player_profile, "opponent_profile": opponent_profile, "start_tick": world.tick}
