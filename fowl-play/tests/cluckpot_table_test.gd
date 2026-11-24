## Cluckpot rules and four-machine scene integration checks.
extends SceneTree

const Rules = preload("res://casino/tables/cluckpot/cluckpot_rules.gd")
const ArcadeScene: PackedScene = preload("res://casino/tables/cluckpot/cluckpot_arcade.tscn")
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Rules.PAYOUTS["SEVEN"] > Rules.PAYOUTS["ROOSTER"], "Golden 7 is the top regular symbol payout")
	_check(Rules.PAYOUTS["WILD"] > Rules.PAYOUTS["ROOSTER"], "Golden Chicken wild has a premium payout")
	_check(Rules.PAYOUTS["CORN"] > Rules.PAYOUTS["WINGS"], "Chicken wings are a regular low-value payout symbol")
	_check(Rules.SYMBOLS.size() == 7 and Rules.SYMBOLS.has("WINGS") and not Rules.SYMBOLS.has("CHERRY") and not Rules.SYMBOLS.has("LEMON"), "The symbol pool uses the seven uploaded Fowl Play assets")
	var seven_columns: Array = [
		["SEVEN", "CHICK", "EGG"],
		["SEVEN", "CORN", "CORN"],
		["SEVEN", "EGG", "WINGS"],
	]
	var seven_wins: Array[Dictionary] = Rules.evaluate_lines(seven_columns)
	_check(not seven_wins.is_empty() and str(seven_wins[0].get("symbol", "")) == "SEVEN", "Three Golden 7s form a winning line")
	_check(Rules.calculate_payout(100, {"line_wins": seven_wins}) >= 2800, "Golden 7 line pays the top multiplier")
	var wild_columns: Array = [
		["ROOSTER", "CHICK", "EGG"],
		["WILD", "CORN", "WINGS"],
		["ROOSTER", "EGG", "CORN"],
	]
	var wild_wins: Array[Dictionary] = Rules.evaluate_lines(wild_columns)
	var found_rooster: bool = false
	for win: Dictionary in wild_wins:
		if str(win.get("symbol", "")) == "ROOSTER":
			found_rooster = true
	_check(found_rooster, "Golden Chicken wild substitutes into a matching rooster line")

	var arcade: Node3D = ArcadeScene.instantiate() as Node3D
	_check(is_instance_valid(arcade), "Cluckpot arcade scene instantiates")
	if not is_instance_valid(arcade):
		_finish()
		return
	root.add_child(arcade)
	await process_frame
	_check(arcade.get_child_count() == 4, "The arcade scene contains exactly four concurrent machines")
	var table_ids: Dictionary = {}
	var first_machine: BaseTable
	for child: Node in arcade.get_children():
		_check(child is BaseTable, "Every cabinet has its own BaseTable controller")
		if not child is BaseTable:
			continue
		var machine: BaseTable = child as BaseTable
		var id: String = str(machine.get("table_id"))
		_check(not table_ids.has(id), "Every machine has a unique wallet table ID")
		table_ids[id] = true
		_check(machine.get_node_or_null("BettingKeypad/BettingKeypadController") != null, "Every machine has an independent shared BettingKeypad controller")
		var reels: Node = machine.get_node_or_null("Visuals/Cabinet/Reels")
		_check(is_instance_valid(reels) and reels.get_child_count() == 3, "Every cabinet builds three physical reel drums")
		for reel_index: int in range(3):
			var drum_mesh: MeshInstance3D = machine.get_node_or_null("Visuals/Cabinet/Reels/Reel_%d/CylindricalDrum" % reel_index) as MeshInstance3D
			_check(is_instance_valid(drum_mesh) and drum_mesh.mesh is CylinderMesh, "Each reel is a real cylindrical barrel, not a flat symbol strip")
			if is_instance_valid(drum_mesh) and drum_mesh.mesh is CylinderMesh:
				var barrel_mesh: CylinderMesh = drum_mesh.mesh as CylinderMesh
				_check(barrel_mesh.top_radius < 0.475, "The inner drum core stays behind the wrapped symbol faces instead of hiding them")
			_check(machine.get_node_or_null("Visuals/Cabinet/Reels/Reel_%d/ReelEndCap_-1" % reel_index) is MeshInstance3D and machine.get_node_or_null("Visuals/Cabinet/Reels/Reel_%d/ReelEndCap_1" % reel_index) is MeshInstance3D, "Each drum has machined end caps")
			var ring: Node3D = machine.get_node_or_null("Visuals/Cabinet/Reels/Reel_%d" % reel_index) as Node3D
			_check(is_instance_valid(ring) and ring.get_child_count() >= 12, "Each cylindrical reel carries a full wrapped ring of symbol faces")
		var wager_screen: WorldScreen = machine.get_node_or_null("Visuals/Cabinet/WagerWorldScreen") as WorldScreen
		_check(is_instance_valid(wager_screen), "Every cabinet has its own head-mounted WorldScreen")
		if is_instance_valid(wager_screen):
			_check(wager_screen.display_size.x >= 1.5 and wager_screen.display_size.y >= 0.55, "Wager WorldScreen is enlarged to replace the old jackpot medallion")
			_check(wager_screen.position.y < 2.7 and wager_screen.position.y - wager_screen.display_size.y * 0.5 > 2.13, "Enlarged WorldScreen sits above the reel bezel without covering the reel window")
			_check(machine.get_node_or_null("Visuals/Cabinet/SevenMedallion") == null and machine.get_node_or_null("Visuals/Cabinet/JackpotSeven") == null, "Old Golden 7 medallion is removed")
			_check(wager_screen.pixels_per_unit >= 2048 and wager_screen.font_size_ratio >= 0.14, "Wager WorldScreen uses high-resolution large typography")
		_check(machine.get_node_or_null("Visuals/Cabinet/ButtonHousing") == null, "The cabinet has no redundant spin button")
		var textured_symbol_count: int = 0
		for reel_index: int in range(3):
			for symbol_index: int in range(10):
				var symbol_sprite: Sprite3D = machine.get_node_or_null("Visuals/Cabinet/Reels/Reel_%d/Cell_%d/SymbolIcon" % [reel_index, symbol_index]) as Sprite3D
				if is_instance_valid(symbol_sprite) and symbol_sprite.texture != null:
					textured_symbol_count += 1
		_check(textured_symbol_count == 30, "All thirty wrapped reel faces use the uploaded PNG artwork")
		if first_machine == null:
			first_machine = machine
	_check(table_ids.size() == 4, "All four machine IDs are unique")

	if is_instance_valid(first_machine):
		var wallet: Node = root.get_node_or_null("CasinoWallet")
		var day_manager: Node = root.get_node_or_null("CasinoDayManager")
		if is_instance_valid(wallet) and is_instance_valid(day_manager):
			_check_result(wallet.call("begin_run", 10000), "Initialize shared wallet")
			_check_result(day_manager.call("begin_casino_day", 1, 17500), "Start casino quota snapshot")
			first_machine.set("spin_duration", 5.2)
			_check(float(first_machine.get("spin_duration")) >= 4.0 and first_machine.has_method("_set_reel_drum_angle") and first_machine.get("_reel_drums").size() == 3, "Spin uses continuous reel progress over a four-to-six-second presentation")
			_check_result(first_machine.call("enter_proximity", 1), "Register test player near a machine")
			var limits: Dictionary = first_machine.call("get_wager_limits")
			var stake: int = int(limits.get("minimum", 0))
			_check_result(first_machine.call("set_selected_wager", 1, stake), "Select wager through shared limits")
			var wager_screen: WorldScreen = first_machine.get_node_or_null("Visuals/Cabinet/WagerWorldScreen") as WorldScreen
			if is_instance_valid(wager_screen):
				var screen_text: ScreenText = wager_screen.get_screen_text()
				_check(is_instance_valid(screen_text) and screen_text.text.contains("#54e58b"), "Valid wager is presented in green on the cabinet display")
				var display_adapter: Node = first_machine.get_node_or_null("WagerDisplayAdapter")
				if is_instance_valid(display_adapter):
					display_adapter.call("set_status", "REELS IN MOTION", "WAGER $100", true)
					display_adapter.call("set_pending_wager_amount", 0)
					_check(screen_text.text.contains("REELS IN MOTION"), "Clearing the keypad draft does not erase the active spin display")
			var spin: Dictionary = first_machine.call("_handle_spin", 1)
			_check(bool(spin.get("ok", false)), "Host accepts a valid slot spin")
			await create_timer(5.6).timeout
			var visual_builder: CluckpotVisualBuilder = first_machine.get_node("Visuals") as CluckpotVisualBuilder
			var settled_record: Dictionary = first_machine.get("last_spin_result")
			var expected_columns: Array = settled_record.get("symbols", [])
			_check(int(settled_record.get("visual_seed", 0)) > 0, "Host supplies a shared visual seed for synchronized multiplayer reels")
			var aligned_faces: int = 0
			if is_instance_valid(visual_builder) and expected_columns.size() == 3:
				for reel_index: int in range(3):
					for row_index: int in range(3):
						var visible_cell: Node3D = visual_builder.reel_cells[reel_index][row_index]
						var visible_icon: Sprite3D = visible_cell.get_node_or_null("SymbolIcon") as Sprite3D
						var expected_path: String = _symbol_texture_path(str(expected_columns[reel_index][row_index]))
						if is_instance_valid(visible_icon) and visible_icon.texture != null and visible_icon.texture.resource_path == expected_path:
							aligned_faces += 1
			_check(aligned_faces == 9, "All nine final visible reel symbols match the authoritative spin outcome")
			var persistent_reels: int = 0
			for reel_index: int in range(3):
				var reel_node: Node3D = visual_builder.reel_drums[reel_index]
				var drum_core: MeshInstance3D = reel_node.get_node_or_null("CylindricalDrum") as MeshInstance3D
				if is_instance_valid(reel_node) and is_instance_valid(drum_core) and drum_core.visible and reel_node.quaternion.is_equal_approx(Quaternion.IDENTITY):
					persistent_reels += 1
			_check(persistent_reels == 3, "All three cylindrical drums remain present, visible, and at their home orientation after stopping")
			var resting_depths: int = 0
			for reel_index: int in range(3):
				var reel_node: Node3D = visual_builder.reel_drums[reel_index]
				var expected_depth: float = 0.27
				if is_instance_valid(reel_node) and is_equal_approx(reel_node.position.z, expected_depth):
					resting_depths += 1
			_check(resting_depths == 3, "All three reels return to their original forward depth after the stop bounce")
			var wallet_snapshot: Dictionary = wallet.call("get_snapshot")
			_check(int(wallet_snapshot.get("reserved_total", 0)) == 0, "Spin settlement releases the reserved wager")
			var wager: Dictionary = wallet.call("get_wager", str(spin.get("wager_id", "")))
			_check(not wager.is_empty(), "The spin returns a verifiable wallet wager ID")
			if not wager.is_empty():
				_check(str(wager.get("status", "")) == "settled", "The spin's wallet wager settles exactly once")
			first_machine.set("spin_duration", 5.2)
			var cleanup_spin: Dictionary = first_machine.call("_handle_spin", 1)
			_check(bool(cleanup_spin.get("ok", false)), "A second spin starts before day-end cleanup")
			var cleanup: Dictionary = first_machine.call("request_day_end_cleanup", "test_day_end")
			_check(bool(cleanup.get("ok", false)) and str(cleanup.get("action", "")) == "settled_in_flight", "Day-end cleanup settles an in-flight spin")
			var cleanup_wager: Dictionary = wallet.call("get_wager", str(cleanup_spin.get("wager_id", "")))
			_check(str(cleanup_wager.get("status", "")) == "settled", "Day-end cleanup settles the spin's exact wallet wager")

	arcade.queue_free()
	_finish()


func _symbol_texture_path(symbol: String) -> String:
	match symbol:
		"SEVEN": return "res://assets/images/cluckpot/seven.png"
		"WILD": return "res://assets/images/cluckpot/gold_chicken.png"
		"ROOSTER": return "res://assets/images/cluckpot/normal_chicken.png"
		"CHICK": return "res://assets/images/cluckpot/baby_chicken.png"
		"EGG": return "res://assets/images/cluckpot/egg.png"
		"CORN": return "res://assets/images/cluckpot/corn.png"
		"WINGS": return "res://assets/images/cluckpot/chickenwings.png"
	return ""


func _check_result(result: Dictionary, label: String) -> void:
	_check(bool(result.get("ok", false)), "%s: %s" % [label, str(result.get("reason", ""))])


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("CLUCKPOT FAIL: " + label)


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("CLUCKPOT PASS: Golden 7 payouts, Golden Chicken wild, four independent machines, shared keypads, and host settlement")
	quit(0)
