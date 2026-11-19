## Headless contract checks for ScreenMenu model and WorldScreen rendering.
extends SceneTree

const WorldScreenScene = preload("res://environment/kit/world_screen.tscn")
const ScreenMenuScript = preload("res://ui/screen_menu.gd")
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var screen: WorldScreen = WorldScreenScene.instantiate() as WorldScreen
	root.add_child(screen)
	await process_frame
	var menu: ScreenMenu = ScreenMenuScript.new()
	var options: Array[Dictionary] = [
		{"id": &"start", "label": "START GAME"},
		{"id": &"settings", "label": "SETTINGS", "enabled": false},
		{"id": &"quit", "label": "QUIT"}
	]
	var confirmed: Array[StringName] = []
	menu.option_confirmed.connect(func(option_id: StringName, _label: String) -> void: confirmed.append(option_id))
	_check(menu.open(screen, "MAIN MENU", "Select an operation.", options, "UP/DOWN MOVE  •  USE SELECT"), "Valid menu should open")
	_check(menu.is_active() and menu.get_selected_index() == 0 and menu.get_selected_option_id() == &"start", "Menu should select the first enabled option")
	var rendered: String = screen.get_screen_text().get_parsed_text()
	_check(rendered.contains("MAIN MENU") and rendered.contains("Select an operation."), "Header and description should render")
	_check(rendered.contains("> START GAME") and rendered.contains("SETTINGS") and rendered.contains("QUIT"), "Options and selection marker should render")
	_check(rendered.contains("UP/DOWN MOVE"), "Prompt should render")
	_check(menu.move_selection(1) and menu.get_selected_option_id() == &"quit", "Navigation should skip disabled options")
	_check(menu.move_selection(1) and menu.get_selected_option_id() == &"start", "Navigation should wrap by default")
	_check(not menu.select_index(1), "Disabled option should not be selectable")
	_check(menu.handle_action(ScreenMenu.ACTION_DOWN) and menu.get_selected_option_id() == &"quit", "Semantic down action should navigate")
	_check(menu.handle_action(ScreenMenu.ACTION_CONFIRM), "Semantic confirm action should confirm")
	_check(confirmed.size() == 1 and confirmed[0] == &"quit", "Confirmation should emit selected option ID")
	menu.wrap_navigation = false
	_check(not menu.move_selection(1), "Navigation should stop at end when wrapping is disabled")
	_check(menu.handle_action(ScreenMenu.ACTION_CANCEL), "Semantic cancel action should cancel")
	_check(not menu.is_active() and screen.get_screen_text().get_parsed_text().is_empty(), "Cancel should close menu and clear screen")
	var duplicate_ids: Array[Dictionary] = [{"id": &"same", "label": "ONE"}, {"id": &"same", "label": "TWO"}]
	_check(not menu.open(screen, "INVALID", "", duplicate_ids), "Duplicate option IDs should be rejected")
	var all_disabled: Array[Dictionary] = [{"id": &"a", "label": "A", "enabled": false}, {"id": &"b", "label": "B", "enabled": false}]
	_check(not menu.open(screen, "UNAVAILABLE", "", all_disabled), "Menu with no enabled options should be rejected")
	screen.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("SCREEN MENU PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("SCREEN MENU FAIL: %s" % message)
