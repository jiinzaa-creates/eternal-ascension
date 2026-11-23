class_name Hud
extends Control
## Combat, progression and quest HUD, drawn entirely in code.
##
## Code-drawn UI is a deliberate art direction, not a placeholder: it keeps the
## interface legible at any resolution and avoids shipping borrowed asset packs.

const PANEL_BG := Color("#0d1216", 0.74)
const INK := Color("#e6eef2")
const MUTED := Color("#8fa2ab")
const ACCENT := Color("#9fe0c0")

var host: Node
var _font: Font
var _toasts: Array = []
var _help_visible := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	Bus.toast.connect(_on_toast)
	Bus.help_toggled.connect(func(visible: bool) -> void: _help_visible = visible)


func _on_toast(text: String) -> void:
	_toasts.append({"text": text, "ttl": 6.0})
	if _toasts.size() > 6:
		_toasts.pop_front()


func _process(delta: float) -> void:
	for toast in _toasts:
		toast["ttl"] = float(toast["ttl"]) - delta
	_toasts = _toasts.filter(func(t: Dictionary) -> bool: return float(t["ttl"]) > 0.0)
	queue_redraw()


func _text(pos: Vector2, text: String, font_size: int = 14, color: Color = INK) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _bar(pos: Vector2, bar_size: Vector2, ratio: float, color: Color, label: String) -> void:
	draw_rect(Rect2(pos, bar_size), Color("#000000", 0.55))
	draw_rect(Rect2(pos, Vector2(bar_size.x * clampf(ratio, 0.0, 1.0), bar_size.y)), color)
	draw_rect(Rect2(pos, bar_size), Color("#2b343a"), false, 1.0)
	_text(pos + Vector2(bar_size.x + 8.0, bar_size.y - 1.0), label, 12, MUTED)


func _draw() -> void:
	if host == null:
		return
	var player: Player = Game.player as Player
	if player == null:
		return

	if String(host.phase) == "creation":
		draw_creation(player)
		draw_toasts()
		return

	draw_vitals(player)
	draw_world_panel(player)
	draw_waypoint(player)
	draw_techniques(player)
	draw_inventory(player)
	draw_quest(player)
	draw_prompt()
	draw_realm_banner()
	draw_toasts()
	if _help_visible:
		draw_help()


func draw_vitals(player: Player) -> void:
	var x := 24.0
	var y := 28.0
	draw_rect(Rect2(x - 12.0, y - 22.0, 316.0, 244.0), PANEL_BG)

	_text(Vector2(x, y), player.cultivation.stage_label(), 19, ACCENT)
	y += 20.0
	var root: Dictionary = player.cultivation.root_data()
	var root_label := String(root.get("name", "?"))
	if not player.cultivation.identified:
		root_label = "unread root"
	_text(Vector2(x, y), "Root: %s   Method: %s" % [root_label, String(player.cultivation.method_data().get("name", "?"))], 12, MUTED)
	y += 18.0
	_text(Vector2(x, y), "Physique: %s (tier %d)" % [Physiques.name_of(player.physique_id), Physiques.tier_of(player.physique_id)], 12, Color("#c8b8e8"))
	y += 20.0

	_bar(Vector2(x, y), Vector2(196.0, 10.0), player.hp / maxf(1.0, player.hp_max), Color("#d05050"),
		"HP %d/%d" % [int(player.hp), int(player.hp_max)])
	y += 18.0
	var qi_cap := player.cultivation.qi_max(player.stats)
	_bar(Vector2(x, y), Vector2(196.0, 10.0), player.cultivation.qi / maxf(1.0, qi_cap), Color("#5fb0d0"),
		"Qi %d/%d" % [int(player.cultivation.qi), int(qi_cap)])
	y += 22.0
	_text(Vector2(x, y), player.stats.summary(), 12, INK)
	y += 18.0
	var derived := player.stats.derived()
	_text(Vector2(x, y), "DMG x%.2f  CRIT %d%%  ARM %d" % [
		float(derived["physical_mult"]), int(float(derived["crit_chance"]) * 100.0), int(float(derived["armor"]))
	], 12, MUTED)
	y += 18.0
	var evasion := player.stats.evasion_chance()
	var lifespan := player.stats.lifespan_years()
	_text(Vector2(x, y), "EVA %d%%   PEN %d%%   CDR %d%%   CRIT x%.2f" % [
		int(evasion * 100.0), int(player.stats.penetration_fraction() * 100.0),
		int(player.stats.cooldown_reduction() * 100.0), player.stats.crit_multiplier()
	], 11, MUTED)
	y += 16.0
	_text(Vector2(x, y), "Regen %.1f/s   Lifespan %s" % [
		player.stats.health_regen(), "unbounded" if lifespan <= 0 else "%d years" % lifespan
	], 11, MUTED)
	y += 18.0
	var passive_text := "Passives: none"
	if not player.passives.is_empty():
		var names: Array[String] = []
		for id in player.passives:
			names.append(String(DB.passive(String(id)).get("name", id)))
		passive_text = "Passives: " + ", ".join(names)
	_text(Vector2(x, y), passive_text, 11, Color("#b8a8d8"))


func draw_world_panel(player: Player) -> void:
	var w := size.x
	var x := w - 316.0
	var y := 28.0
	draw_rect(Rect2(x - 12.0, y - 22.0, 316.0, 158.0), PANEL_BG)
	_text(Vector2(x, y), "%s   %s   %s" % [Clock.label(), Weather.label(), host.current_biome_name()], 13, MUTED)
	y += 18.0
	_text(Vector2(x, y), "%s   Kills %d   Karma %d" % [player.display_name, Game.kills, Game.karma], 12, MUTED)
	y += 18.0
	_text(Vector2(x, y), "Spirit stones: %d" % Game.spirit_stones, 13, Color("#d8c070"))
	y += 18.0
	var weapon: Dictionary = player.equipment.get("weapon", {})
	if weapon.is_empty():
		_text(Vector2(x, y), "Weapon: unarmed", 12, MUTED)
	else:
		_text(Vector2(x, y), String(weapon.get("name", "?")), 12, Color(ItemGen.RARITY_COLORS[int(weapon.get("rarity", 0))]))
	y += 18.0
	_text(Vector2(x, y), "Weapon dmg %d   Armor %d" % [int(player.weapon_damage()), int(player.armor())], 12, MUTED)


## Compass to the chosen waypoint, with the distance to it.
func draw_waypoint(player: Player) -> void:
	var target: Vector2 = host.waypoint_position
	if target == Vector2.ZERO or String(host.phase) == "realm":
		return
	var distance := target.distance_to(player.global_position)
	var angle := Travel.bearing(player.global_position, target)
	var w := 230.0
	var x := size.x * 0.5 - w * 0.5
	var y := 14.0
	draw_rect(Rect2(x, y, w, 30.0), PANEL_BG)
	draw_set_transform(Vector2(x + 20.0, y + 15.0), angle, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(-5, 5), Vector2(-5, -5)]), ACCENT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text(Vector2(x + 38.0, y + 19.0), "%s · %s" % [String(host.waypoint_name), Travel.distance_label(distance)], 12, INK)


func draw_quest(player: Player) -> void:
	var quests: QuestLog = host.quests as QuestLog
	if quests == null or not quests.is_valid():
		return
	var w := size.x
	var y := 210.0
	var lines: Array[String] = ["QUEST — " + quests.title(), quests.objective_text()]
	var width := 316.0
	draw_rect(Rect2(w - 316.0 - 12.0, y - 22.0, width, 22.0 + float(lines.size()) * 18.0), PANEL_BG)
	for i in lines.size():
		var color := Color("#d8c070") if i == 0 else INK
		_text(Vector2(w - 316.0, y + float(i) * 18.0), lines[i], 12, color)


func draw_techniques(player: Player) -> void:
	var x := 24.0
	var y := size.y - 96.0
	var slot_size := Vector2(112.0, 46.0)
	draw_rect(Rect2(x - 12.0, y - 24.0, slot_size.x * 6.0 + 24.0, 92.0), PANEL_BG)
	_text(Vector2(x, y - 8.0), "Technique Bar  (1-6 select, LMB execute)", 12, MUTED)
	y += 2.0
	for i in mini(6, player.technique_ids.size()):
		var tech: Dictionary = DB.technique(String(player.technique_ids[i]))
		var rect := Rect2(Vector2(x + float(i) * (slot_size.x + 6.0), y), slot_size)
		var selected := i == player.selected_technique
		draw_rect(rect, Color("#182229", 0.9) if not selected else Color("#24343d", 0.95))
		draw_rect(rect, Color("#7fd3e0") if selected else Color("#2b343a"), false, 2.0 if selected else 1.0)
		_text(rect.position + Vector2(8.0, 17.0), "%d  %s" % [i + 1, String(tech.get("name", "?"))], 10, INK)
		var cost := float(tech.get("qi_cost", 0.0))
		var affordable := player.cultivation.qi >= cost
		_text(rect.position + Vector2(8.0, 33.0), "Qi %d" % int(cost), 11, Color("#7fd3e0") if affordable else Color("#c05858"))


func draw_inventory(player: Player) -> void:
	var w := size.x
	var y := 290.0
	draw_rect(Rect2(w - 316.0 - 12.0, y - 22.0, 316.0, 170.0), PANEL_BG)
	_text(Vector2(w - 316.0, y), "Satchel  (%d items)" % player.inventory.size(), 13, INK)
	y += 20.0
	var recent: Array = player.inventory.slice(maxi(0, player.inventory.size() - 6))
	for item in recent:
		var color := Color(ItemGen.RARITY_COLORS[int(item.get("rarity", 0))])
		_text(Vector2(w - 316.0, y), String(item.get("name", "?")), 12, color)
		y += 17.0
	if player.inventory.is_empty():
		_text(Vector2(w - 316.0, y), "Empty. Kill something.", 12, MUTED)


func draw_prompt() -> void:
	var prompt := String(host.interaction_prompt())
	if prompt == "":
		return
	var width := _text_width(prompt, 14) + 28.0
	var pos := Vector2(size.x * 0.5 - width * 0.5, size.y - 116.0)
	draw_rect(Rect2(pos, Vector2(width, 28.0)), Color("#0d1216", 0.85))
	draw_rect(Rect2(pos, Vector2(width, 28.0)), Color("#7fd3e0", 0.5), false, 1.0)
	_text(pos + Vector2(14.0, 19.0), prompt, 14, INK)


func draw_realm_banner() -> void:
	if String(host.phase) != "realm":
		return
	var text := "HIDDEN REALM — Tomb of the Hollow Moon"
	var width := _text_width(text, 16) + 28.0
	var pos := Vector2(size.x * 0.5 - width * 0.5, 22.0)
	draw_rect(Rect2(pos, Vector2(width, 28.0)), Color("#241a38", 0.85))
	_text(pos + Vector2(14.0, 19.0), text, 16, Color("#c8b8ff"))


func draw_toasts() -> void:
	var y := size.y - 84.0
	var x := size.x * 0.5
	for toast in _toasts:
		var alpha := clampf(float(toast["ttl"]), 0.0, 1.0)
		var text := String(toast["text"])
		var width := _text_width(text, 13)
		_text(Vector2(x - width * 0.5, y), text, 13, Color(INK, alpha))
		y -= 19.0


func draw_help() -> void:
	var lines := "WASD move · SHIFT sprint · LMB attack · SPACE dodge · F meditate · G breakthrough · E interact · 1-6 technique · M map · F5 save · F9 load · F1 hide"
	var trade := "At a merchant: 1-6 buy/sell · TAB switch · E close · T travel · M map"
	_text(Vector2(24.0, size.y - 44.0), trade, 11, Color("#6b7b84"))
	_text(Vector2(24.0, size.y - 12.0), lines, 11, Color("#7b8b94"))
	var pad := "Gamepad: left stick move · right stick aim · X attack · A dodge · B interact · Y meditate · RB sprint · LB shop · DPAD travel/waypoint"
	_text(Vector2(24.0, size.y - 60.0), pad, 11, Color("#6b7b84"))


func draw_creation(player: Player) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#070a0c", 0.88))
	var cx := size.x * 0.5
	var y := 70.0

	var title := "ETERNAL ASCENSION"
	_text(Vector2(cx - _text_width(title, 32) * 0.5, y), title, 32, Color("#e8f4f0"))
	y += 26.0
	var sub := "The heavens do not choose you. Begin anyway."
	_text(Vector2(cx - _text_width(sub, 13) * 0.5, y), sub, 13, MUTED)
	y += 40.0

	if int(host.creation_stage) == 1:
		_draw_creation_identity(player, cx, y)
		return

	var name_line := "Wanderer: %s" % player.display_name
	_text(Vector2(cx - _text_width(name_line, 17) * 0.5, y), name_line, 17, INK)
	y += 28.0

	var root: Dictionary = player.cultivation.root_data()
	var affinities: Array = root.get("affinities", [])
	var root_line := "Spiritual Root: %s  (tier %d, %.2fx cultivation)" % [
		String(root.get("name", "?")), int(root.get("tier", 0)), float(root.get("cult_mult", 1.0))
	]
	_text(Vector2(cx - _text_width(root_line, 17) * 0.5, y), root_line, 17, ACCENT)
	y += 24.0
	var aff_line := "Affinities: " + ", ".join(affinities)
	_text(Vector2(cx - _text_width(aff_line, 12) * 0.5, y), aff_line, 12, MUTED)
	y += 22.0
	var physique_line := "Physique: %s (tier %d)" % [Physiques.name_of(player.physique_id), Physiques.tier_of(player.physique_id)]
	_text(Vector2(cx - _text_width(physique_line, 13) * 0.5, y), physique_line, 13, Color("#c8b8e8"))
	y += 26.0

	var remaining := int(host.allocation_remaining())
	var points_line := "FORMATION POINTS REMAINING: %d" % remaining
	_text(Vector2(cx - _text_width(points_line, 15) * 0.5, y), points_line, 15, Color("#d8c070"))
	y += 30.0

	# Two columns of three attributes, keys 1-6.
	var col_width := 220.0
	for i in Attributes.KEYS.size():
		var key := Attributes.KEYS[i]
		var col := i % 2
		var row := i / 2
		var x := cx - col_width + float(col) * col_width
		var line_y := y + float(row) * 26.0
		var value := player.attrs.get_attr(key)
		var label := "%d)  %s  %d" % [i + 1, Attributes.LABELS[key], value]
		_text(Vector2(x, line_y), label, 15, INK)
		_text(Vector2(x + 118.0, line_y), _attribute_note(key), 11, MUTED)
	y += 26.0 * 3.0 + 26.0

	var hint := "1-6 add a point   BACKSPACE refund   R reroll root   P reroll physique   ENTER continue"
	_text(Vector2(cx - _text_width(hint, 14) * 0.5, y), hint, 14, INK)
	y += 34.0

	var techs: Array[String] = []
	for id in player.technique_ids:
		techs.append(String(DB.technique(String(id)).get("name", id)))
	var tech_line := "Starting techniques: " + ", ".join(techs)
	_text(Vector2(cx - _text_width(tech_line, 11) * 0.5, y), tech_line, 11, MUTED)


## Second creation screen: who the cultivator was before the formation points.
func _draw_creation_identity(player: Player, cx: float, y: float) -> void:
	var heading := "WHO WALKS THE PATH?"
	_text(Vector2(cx - _text_width(heading, 20) * 0.5, y), heading, 20, ACCENT)
	y += 26.0
	var name_line := "Wanderer: %s" % player.display_name
	_text(Vector2(cx - _text_width(name_line, 15) * 0.5, y), name_line, 15, INK)
	y += 30.0

	var origin: Dictionary = host.selected_origin()
	var origins: Array = host.creation_origins()
	var left := cx - 300.0
	for i in origins.size():
		var entry: Dictionary = origins[i]
		var selected := String(entry.get("id", "")) == String(origin.get("id", ""))
		var label := "%s %s" % [">" if selected else " ", String(entry.get("name", "?"))]
		_text(Vector2(left, y + float(i) * 22.0), label, 14, ACCENT if selected else MUTED)
	y += float(maxi(1, origins.size())) * 22.0 + 12.0

	if not origin.is_empty():
		var fx := Origin.effects(origin)
		_text(Vector2(left, y), String(fx["blurb"]), 12, MUTED)
		y += 18.0
		_text(Vector2(left, y), Origin.summary(origin), 12, Color("#d8c070"))
		y += 18.0
		_text(Vector2(left, y), String(fx["condition"]), 11, Color("#7f9098"))
		y += 30.0

	_text(Vector2(left, y), "Appearance", 13, INK)
	y += 22.0
	y = _swatch_row(left, y, "Robe   Z", Appearance.ROBES, player.appearance.robe)
	y = _swatch_row(left, y, "Hair   X", Appearance.HAIRS, player.appearance.hair)
	y = _swatch_row(left, y, "Skin   C", Appearance.SKINS, player.appearance.skin)
	y += 6.0
	_text(Vector2(left, y), "Presentation   N     %s" % player.appearance.pronouns(), 12, INK)
	y += 34.0

	var hint := "TAB origin    Z robe    X hair    C skin    N presentation    BACKSPACE back    ENTER begin"
	_text(Vector2(cx - _text_width(hint, 13) * 0.5, y), hint, 13, INK)


func _swatch_row(x: float, y: float, label: String, colors: Array, selected: int) -> float:
	_text(Vector2(x, y), label, 12, MUTED)
	var sx := x + 120.0
	for i in colors.size():
		var rect := Rect2(Vector2(sx + float(i) * 26.0, y - 12.0), Vector2(20.0, 14.0))
		draw_rect(rect, Color(String(colors[i])))
		draw_rect(rect, ACCENT if i == selected else Color("#2b343a"), false, 2.0 if i == selected else 1.0)
	return y + 22.0


func _attribute_note(key: String) -> String:
	match key:
		"str":
			return "damage · carry · resistance"
		"dex":
			return "accuracy · crit · precision"
		"agi":
			return "speed · attack rate · dodge"
		"int":
			return "comprehension · crafting"
		"wis":
			return "Qi capacity · cultivation"
		"char":
			return "social · recruitment · party"
	return ""
