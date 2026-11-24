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


## Trim a label to the space a slot actually has, so a long art name cannot
## bleed into the next slot.
func _fit(text: String, font_size: int, max_width: float) -> String:
	if _text_width(text, font_size) <= max_width:
		return text
	var cut := text
	while cut.length() > 1 and _text_width(cut + "..", font_size) > max_width:
		cut = cut.substr(0, cut.length() - 1)
	return cut + ".."


## Relics read gold, broken gear reads red, everything else by rarity.
func _item_color(item: Dictionary) -> Color:
	if bool(item.get("unique", false)):
		return Color("#f0d080")
	if Items.is_broken(item):
		return Color("#d06060")
	var rarity := clampi(int(item.get("rarity", 0)), 0, ItemGen.RARITY_COLORS.size() - 1)
	return Color(ItemGen.RARITY_COLORS[rarity])


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

	if String(host.phase) == "ended":
		draw_ended(player)
		draw_toasts()
		return

	if String(host.phase) == "creation":
		draw_creation(player)
		draw_toasts()
		return

	draw_vitals(player)
	draw_statuses(player)
	draw_world_panel(player)
	draw_waypoint(player)
	draw_techniques(player)
	draw_inventory(player)
	# The dossier is ambient HUD; every full-screen screen opens over it.
	draw_npc_dossier(player)
	draw_gear(player)
	draw_storage(player)
	draw_forge(player)
	draw_alchemy(player)
	draw_quest(player)
	draw_party(player)
	draw_prompt()
	draw_realm_banner()
	draw_tribulation()
	draw_boss()
	draw_toasts()
	if _help_visible:
		draw_help()


## The end of the road: a quiet screen with the life that was lived, and the
## only key that still does anything.
func draw_ended(player: Player) -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.9))
	var center := view * 0.5
	var title := "THE DAO RELEASES YOU"
	_text(center + Vector2(-_text_width(title, 30) * 0.5, -130.0), title, 30, Color("#c9d8e2"))
	var lines: Array[String] = [
		Aging.age_text(Game.age_years(), player.stats.lifespan_years()),
		"Realm %d · %d kills · %d karma" % [player.cultivation.realm, Game.kills, Game.karma],
		"%d spirit stones · %d days in the world" % [Game.spirit_stones, maxi(0, Clock.day - Game.born_day)],
	]
	for i in lines.size():
		_text(center + Vector2(-_text_width(lines[i], 15) * 0.5, -60.0 + float(i) * 26.0), lines[i], 15, MUTED)
	var hint := "ENTER — begin again"
	_text(center + Vector2(-_text_width(hint, 16) * 0.5, 110.0), hint, 16, Color("#e8d9a8"))


func draw_vitals(player: Player) -> void:
	var x := 24.0
	var y := 28.0
	draw_rect(Rect2(x - 12.0, y - 22.0, 316.0, 292.0), PANEL_BG)

	_text(Vector2(x, y), player.cultivation.stage_title(), 19, ACCENT)
	y += 20.0
	var root: Dictionary = player.cultivation.root_data()
	var root_label := String(root.get("name", "?"))
	if not player.cultivation.identified:
		root_label = "unread root"
	_text(Vector2(x, y), "Root: %s   Method: %s (%d%%)" % [root_label, String(player.cultivation.method_data().get("name", "?")), player.cultivation.method_insight_points(player.cultivation.method_id)], 12, MUTED)
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
	_text(Vector2(x, y), "Regen %.1f/s   %s" % [
		player.stats.health_regen(), Aging.age_text(Game.age_years(), lifespan)
	], 11, MUTED)
	y += 18.0
	var passive_text := "Passives: none"
	if not player.passives.is_empty():
		var names: Array[String] = []
		for id in player.active_passives():
			names.append(String(DB.passive(String(id)).get("name", id)))
		passive_text = "Passives: " + ", ".join(names) if not names.is_empty() else "Passives: all dormant"
		var dormant := player.dormant_passives().size()
		if dormant > 0:
			passive_text += "   (%d dormant)" % dormant
	_text(Vector2(x, y), passive_text, 11, Color("#b8a8d8"))
	y += 18.0
	_text(Vector2(x, y), "Meridians: %d/12   Contamination: %d%%" % [
		player.cultivation.meridian_count(), int(player.cultivation.contamination)
	], 11, Color("#8fd8e8"))
	y += 18.0
	_text(Vector2(x, y), "Realm art: %s   Unlocks: %d" % [
		String(player.cultivation.realm_ability().get("name", "—")), player.cultivation.unlock_ids().size()
	], 11, Color("#d8c898"))
	y += 18.0
	var insight_text := "Comprehension: %d%%   Insights: %d/%d" % [
		roundi(player.cultivation.enlightenment_meter), player.enlightenments.size(), Enlightenments.count_total()
	]
	var insight_names := Enlightenments.known_names(player.enlightenments)
	if not insight_names.is_empty():
		insight_text += " — " + ", ".join(insight_names)
	_text(Vector2(x, y), insight_text, 11, Color("#c8d8a8"))
	# The tribulation line only appears where an attempt is possible, so the HUD
	# never advertises a roll the player cannot make.
	if player.cultivation.is_peak() and player.cultivation.realm < Realms.count():
		y += 18.0
		var chance := player.breakthrough_chance_estimate()
		var note := String(player.cultivation.method_breakthrough_profile(player.method_state()).get("note", ""))
		_text(Vector2(x, y), "Tribulation %d%%   Prep %d/%d   %s" % [
			roundi(chance * 100.0), player.cultivation.preparation, Cultivation.MAX_PREPARATION, note
		], 11, Color("#e0c880"))


## A boss gets one wide bar at the top of the screen, with its phase name and a
## mark at every health threshold, so the fight's shape is readable without
## opening anything.
func draw_boss() -> void:
	var body: Node = null
	for node in get_tree().get_nodes_in_group("boss"):
		if node is Node2D and is_instance_valid(node):
			body = node
			break
	if body == null or Game.player == null:
		return
	var entry_value: Variant = body.get("boss_entry")
	if typeof(entry_value) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = entry_value
	if entry.is_empty():
		return
	var at := (body as Node2D).global_position
	if at.distance_to((Game.player as Node2D).global_position) > 1600.0:
		return
	var ratio := clampf(float(body.get("hp")) / maxf(1.0, float(body.get("hp_max"))), 0.0, 1.0)
	var width := minf(560.0, size.x - 120.0)
	var x := size.x * 0.5 - width * 0.5
	var y := 58.0
	draw_rect(Rect2(x - 10.0, y - 22.0, width + 20.0, 58.0), PANEL_BG)
	_text(Vector2(x, y - 3.0), String(body.get("display_name")), 15, Color("#d8c8ff"))
	var phase_label := Boss.phase_name(entry, int(body.get("boss_phase")))
	_text(Vector2(x + width - _text_width(phase_label, 12), y - 3.0), phase_label, 12, MUTED)
	var bar_y := y + 8.0
	draw_rect(Rect2(x, bar_y, width, 12.0), Color("#000000", 0.55))
	draw_rect(Rect2(x, bar_y, width * ratio, 12.0), Boss.bar_color(entry))
	draw_rect(Rect2(x, bar_y, width, 12.0), Color("#3b3350"), false, 1.0)
	for threshold in Boss.thresholds(entry):
		var mark_x := x + width * (1.0 - float(threshold))
		draw_line(Vector2(mark_x, bar_y), Vector2(mark_x, bar_y + 12.0), Color("#f0e0ff", 0.7), 1.5)
	_text(Vector2(x, bar_y + 27.0), "%d / %d" % [int(body.get("hp")), int(body.get("hp_max"))], 11, MUTED)


## Live combat statuses, in their own colours, just above the skill bar. Kept out
## of the vitals panel so a status can never push the stat lines off it.
func draw_statuses(player: Player) -> void:
	var labels := Status.labels(player.statuses)
	if labels.is_empty():
		return
	var x := 24.0
	var y := size.y - 132.0
	_text(Vector2(x, y), "Status:", 11, MUTED)
	var cursor := x + _text_width("Status: ", 11)
	var index := 0
	for entry in player.statuses:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var status_id := String((entry as Dictionary).get("id", ""))
		if not Status.is_valid(status_id):
			continue
		var label := String(labels[index]) if index < labels.size() else Status.name_of(status_id)
		_text(Vector2(cursor, y), label, 11, Status.color(status_id))
		cursor += _text_width(label, 11) + 14.0
		index += 1


func draw_world_panel(player: Player) -> void:
	var w := size.x
	var x := w - 316.0
	var y := 28.0
	draw_rect(Rect2(x - 12.0, y - 22.0, 316.0, 194.0), PANEL_BG)
	_text(Vector2(x, y), "%s   %s" % [Clock.label(), Weather.label()], 13, MUTED)
	y += 18.0
	_text(Vector2(x, y), _fit("%s   %s   Kills %d   Karma %d" % [
		player.display_name, host.current_biome_name(), Game.kills, Game.karma], 11, 292.0), 11, MUTED)
	y += 18.0
	_text(Vector2(x, y), "Spirit stones: %d" % Game.spirit_stones, 13, Color("#d8c070"))
	y += 18.0
	var weapon: Dictionary = player.equipment.get("weapon", {})
	var category := player.weapon_type_name()
	if weapon.is_empty():
		_text(Vector2(x, y), "Weapon: unarmed · %s" % category, 12, MUTED)
	else:
		var condition := Items.durability_ratio(weapon)
		var weapon_label := "%s · %s" % [String(weapon.get("name", "?")), category]
		if condition <= 0.0:
			weapon_label += " · BROKEN"
		elif condition < 0.999:
			weapon_label += " · %d%%" % roundi(condition * 100.0)
		var weapon_color := Color(ItemGen.RARITY_COLORS[int(weapon.get("rarity", 0))])
		if condition <= 0.0:
			weapon_color = Color("#d06060")
		_text(Vector2(x, y), weapon_label, 12, weapon_color)
	y += 18.0
	var armor_condition := player.gear_condition("armor")
	var armor_note := ""
	if armor_condition <= 0.0:
		armor_note = "   ARMOUR BROKEN"
	elif armor_condition < 0.999:
		armor_note = "   armour %d%%" % roundi(armor_condition * 100.0)
	_text(Vector2(x, y), "Weapon dmg %d   Armor %d%s" % [int(player.weapon_damage()), int(player.armor()), armor_note], 12, Color("#d06060") if armor_condition <= 0.0 else MUTED)
	y += 18.0
	var next_move := player.next_move_name()
	if next_move != "":
		_text(Vector2(x, y), "Next strike: %s  (%d/%d)" % [
			next_move, player.next_combo_step() + 1, Weapons.moves(player.weapon_type_id()).size()
		], 11, MUTED)
	y += 18.0
	# Guard reads straight from the stance the damage path uses, so the HUD can
	# never promise a ward the body is not holding.
	var stance := player.guard_state()
	var stance_color := MUTED
	if stance == "parry":
		stance_color = Color("#ffe08a")
	elif stance == "broken":
		stance_color = Color("#e07070")
	elif stance == "block":
		stance_color = Color("#9fd0ff")
	_text(Vector2(x, y), "Guard: %s   (hold CTRL / MMB)" % Defense.label(stance), 11, stance_color)
	y += 18.0
	# Live body arts read from the same entries the stat pipeline is fed, so the
	# HUD cannot show a buff that is not in the numbers.
	var buffs: Array = player.active_buff_labels()
	if buffs.is_empty():
		_text(Vector2(x, y), "Body art: none", 11, MUTED)
	else:
		_text(Vector2(x, y), "Body art: " + ", ".join(buffs), 11, Color("#e0c070"))


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


## The travelling party, under the quest line: each member's name, trade, realm,
## bond and health. Every number comes from the body itself, so the panel cannot
## disagree with the fight happening behind it.
func draw_party(player: Player) -> void:
	var members: Array = host.party_members()
	if members.is_empty():
		return
	var x := size.x - 316.0
	var y := 296.0
	var height := 34.0 + float(members.size()) * 34.0
	draw_rect(Rect2(x - 12.0, y - 22.0, 316.0, height), PANEL_BG)
	_text(Vector2(x, y), "PARTY  %s" % Party.slots_label(members.size(), player.stats.party_slots()), 12, ACCENT)
	y += 20.0
	for value in members:
		var npc := value as Npc
		if npc == null:
			continue
		_text(Vector2(x, y), _fit("%s · %s" % [npc.display_name, npc.role], 11, 206.0), 11, INK)
		var ratio := clampf(npc.hp / maxf(1.0, npc.hp_max), 0.0, 1.0)
		_bar(Vector2(x + 214.0, y - 9.0), Vector2(64.0, 8.0), ratio, Color("#79d0a0"), "")
		y += 17.0
		_text(Vector2(x, y), "%s · %s · %d/%d HP" % [
			String(DB.realm(npc.realm).get("name", "Realm %d" % npc.realm)),
			npc.bond_label(), roundi(npc.hp), roundi(npc.hp_max)], 10, MUTED)
		y += 17.0


## The active bar only: six slots, each with its art's own cooldown sweep.
## Occupancy of the other two bars and any art off the bars are named on the
## line beneath, so the readout never hides a known technique.
func draw_techniques(player: Player) -> void:
	var x := 24.0
	var y := size.y - 96.0
	var slot_size := Vector2(112.0, 46.0)
	draw_rect(Rect2(x - 12.0, y - 24.0, slot_size.x * 6.0 + 24.0, 92.0), PANEL_BG)
	_text(Vector2(x, y - 8.0), "Skill bar %s/%s  (1-6 select · [ ] bar · B arrange · Q cycle · LMB execute)" % [
		SkillBar.bar_label(player.active_bar), SkillBar.bar_label(SkillBar.BAR_COUNT - 1)], 11, MUTED)
	y += 2.0
	var slots := player.active_bar_slots()
	for i in slots.size():
		var index := SkillBar.index_of(player.active_bar, i)
		var rect := Rect2(Vector2(x + float(i) * (slot_size.x + 6.0), y), slot_size)
		var tech_id := String(slots[i])
		var selected := tech_id != "" and tech_id == String(player.current_technique().get("id", ""))
		draw_rect(rect, Color("#182229", 0.9) if not selected else Color("#24343d", 0.95))
		draw_rect(rect, Color("#7fd3e0") if selected else Color("#2b343a"), false, 2.0 if selected else 1.0)
		_text(rect.position + Vector2(7.0, 15.0), "%d" % (i + 1), 10, MUTED)
		if tech_id == "":
			_text(rect.position + Vector2(24.0, 16.0), "empty", 10, Color("#42515a"))
			continue
		var tech: Dictionary = DB.technique(tech_id)
		_text(rect.position + Vector2(24.0, 16.0), _fit(String(tech.get("name", "?")), 10, rect.size.x - 30.0), 10, INK)
		var tier := player.mastery_tier(tech_id)
		_text(rect.position + Vector2(7.0, 29.0), Mastery.label(tier), 9, MUTED)
		var cost := float(tech.get("qi_cost", 0.0)) * Mastery.qi_mult(tier) * Realms.technique_mult(player.cultivation.realm)
		var affordable := player.cultivation.qi >= cost
		_text(rect.position + Vector2(7.0, 42.0), "Qi %d" % int(round(cost)), 10, Color("#7fd3e0") if affordable else Color("#c05858"))
		var left := player.slot_cooldown_left(index)
		if left > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * player.slot_cooldown_ratio(index))), Color("#05090b", 0.62))
			_text(rect.position + Vector2(rect.size.x - 34.0, 42.0), SkillBar.cooldown_text(left), 10, Color("#ffd07f"))
	# Occupancy of all three bars, then what is actually held.
	var tabs: Array[String] = []
	for bar in SkillBar.BAR_COUNT:
		tabs.append("%s%s %d/%d" % [">" if bar == player.active_bar else " ", SkillBar.bar_label(bar),
			SkillBar.bar_filled(player.bars, bar), SkillBar.SLOTS_PER_BAR])
	var held := "%s · %s" % [String(player.current_technique().get("name", "—")),
		TechniqueCombat.kind_label(player.current_technique_kind())]
	var off_bar: Array = player.known_off_bar()
	var line := "   ".join(tabs) + "      Held: " + held
	if not off_bar.is_empty():
		line += "   (+%d off-bar · B)" % off_bar.size()
	_text(Vector2(x, y + 62.0), _fit(line, 10, slot_size.x * 6.0), 10, ACCENT)


func draw_inventory(player: Player) -> void:
	var w := size.x
	var y := 290.0
	draw_rect(Rect2(w - 316.0 - 12.0, y - 22.0, 316.0, 170.0), PANEL_BG)
	_text(Vector2(w - 316.0, y), "Satchel  (%d items, %d kinds)" % [Items.total_count(player.inventory), player.inventory.size()], 13, INK)
	_text(Vector2(w - 96.0, y), Inventory.sort_label(player.inventory_sort), 11, MUTED)
	y += 20.0
	# The satchel's own order, so the strip and the grid never disagree.
	var shown: Array = player.inventory.slice(0, 6)
	for item in shown:
		_text(Vector2(w - 316.0, y), Items.label(item), 12, _item_color(item))
		y += 17.0
	if player.inventory.is_empty():
		_text(Vector2(w - 316.0, y), "Empty. Kill something.", 12, MUTED)


## The satchel screen: a 6x5 grid of everything carried, the worn slots beside
## it, and — for a piece of gear — exactly what the stat pipeline would gain or
## lose. It never equips by itself; ENTER goes through Player.equip(), the same
## rules a pickup does.
func draw_gear(player: Player) -> void:
	if host == null or not bool(host.gear_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.86))
	var panel := Rect2(view * 0.5 - Vector2(440.0, 260.0), Vector2(880.0, 520.0))
	draw_rect(panel, Color("#0b1014", 0.97))
	draw_rect(panel, Color("#7fd3e0", 0.45), false, 1.5)
	var origin := panel.position
	_text(origin + Vector2(22.0, 32.0), "SATCHEL", 18, ACCENT)
	_text(origin + Vector2(112.0, 32.0), "sort: %s (R)    I — close    arrows — choose    ENTER — wear    U — use" % Inventory.sort_label(player.inventory_sort), 11, MUTED)

	var rows: Array = host.inventory_rows()
	var count := rows.size()
	_text(origin + Vector2(22.0, 64.0), "CARRIED  (%d kinds, %d items)" % [count, Items.total_count(rows)], 11, MUTED)

	# Grid: one page of six by five cells, the cursor on one of them.
	var selected := clampi(int(host.gear_index), 0, maxi(0, count - 1))
	var pages := Inventory.page_count(rows)
	var page := Inventory.page_of(selected) if count > 0 else 0
	var cell := Vector2(72.0, 34.0)
	var grid_origin := origin + Vector2(22.0, 78.0)
	for i in Inventory.PAGE_SIZE:
		var index := page * Inventory.PAGE_SIZE + i
		var rect := Rect2(grid_origin + Vector2(float(i % Inventory.COLS) * (cell.x + 4.0), float(i / Inventory.COLS) * (cell.y + 4.0)), cell)
		draw_rect(rect, Color("#111a1f"))
		draw_rect(rect, Color("#243039"), false, 1.0)
		if index >= count:
			continue
		var item: Dictionary = rows[index]
		if index == selected:
			draw_rect(rect, Color("#7fd3e0", 0.85), false, 2.0)
		_text(rect.position + Vector2(4.0, 14.0), _fit(Items.label(item), 9, cell.x - 8.0), 9, _item_color(item))
		_text(rect.position + Vector2(4.0, 28.0), _fit(Inventory.slot_label(item), 9, cell.x - 8.0), 9, Color("#5c6b73"))
	_text(grid_origin + Vector2(0.0, 5.0 * (cell.y + 4.0) + 18.0), "Page %d/%d" % [page + 1, pages], 11, MUTED)

	# Worn slots, kept beside the grid rather than in it: they are not carried.
	var worn_x := origin.x + 500.0
	var worn_y := origin.y + 64.0
	_text(Vector2(worn_x, worn_y), "WORN", 11, MUTED)
	worn_y += 20.0
	for slot in ["weapon", "armor", "ring", "talisman"]:
		var worn: Dictionary = player.equipment.get(slot, {})
		_text(Vector2(worn_x, worn_y), String(Equipment.SLOT_LABELS.get(slot, slot)), 11, MUTED)
		var label := "—"
		var color := Color("#5c6b73")
		if not worn.is_empty():
			label = Items.label(worn)
			color = _item_color(worn)
		_text(Vector2(worn_x + 72.0, worn_y), _fit(label, 12, 280.0), 12, color)
		worn_y += 21.0

	var cx := worn_x
	var cy := origin.y + 190.0
	draw_line(Vector2(cx, cy - 16.0), Vector2(panel.position.x + panel.size.x - 22.0, cy - 16.0), Color("#243039"), 1.0)
	if count == 0:
		_text(Vector2(cx, cy), "Satchel empty.", 12, MUTED)
		return
	var chosen: Dictionary = rows[selected]
	var worn_slot: Dictionary = player.equipment.get(String(chosen.get("slot", "")), {})
	var against := "no piece worn there" if worn_slot.is_empty() else "against %s" % String(worn_slot.get("name", "?"))
	_text(Vector2(cx, cy), _fit("%s  (ilvl %d)  — %s" % [String(chosen.get("name", "?")), int(chosen.get("ilvl", 1)), against], 13, 358.0), 13, _item_color(chosen))
	cy += 22.0
	_text(Vector2(cx, cy), "%s · value %d · sells for %d" % [Inventory.slot_label(chosen), int(chosen.get("value", 0)), Economy.sell_value(chosen)], 11, MUTED)
	cy += 18.0
	var lore := String(chosen.get("lore", ""))
	if lore != "":
		_text(Vector2(cx, cy), _fit(lore, 11, 358.0), 11, Color("#d8c070"))
		cy += 19.0

	if String(chosen.get("slot", "")) == "consumable":
		var alchemy_rules: Alchemy = host.alchemy
		var effect: Dictionary = alchemy_rules.effect_for(chosen) if alchemy_rules != null else {}
		if effect.is_empty():
			_text(Vector2(cx, cy), "No effect you know how to draw out.", 11, MUTED)
			return
		var amount := Alchemy.effect_amount(effect, chosen)
		var effect_id := String(effect.get("id", ""))
		var line := ("Purges %.0f contamination" % amount) if effect_id == "cleanse" \
			else ("Restores %.0f %s" % [amount, String(Alchemy.EFFECT_LABELS.get(effect_id, effect_id))])
		_text(Vector2(cx, cy), line, 12, ACCENT)
		cy += 20.0
		_text(Vector2(cx, cy), "Potency x%.2f.  U drinks it." % Alchemy.potency_of(chosen), 11, Color("#8fd8a0"))
		return

	if not Items.is_equipment(String(chosen.get("slot", ""))):
		_text(Vector2(cx, cy), "Not wearable. Keep it, sell it, or store it.", 11, MUTED)
		return
	var info: Dictionary = host.gear_compare(chosen)
	var check: Dictionary = info.get("check", {})
	var deltas: Array = info.get("deltas", [])
	if deltas.is_empty():
		_text(Vector2(cx, cy), "Identical numbers.", 12, MUTED)
		cy += 19.0
	for delta in deltas:
		var value := float((delta as Dictionary).get("delta", 0.0))
		var unit := String((delta as Dictionary).get("unit", ""))
		var shown := ("%.1f" % value) if absf(value) < 10.0 else str(roundi(value))
		var line := "%s%s%s %s" % ["+" if value > 0.0 else "", shown, unit, String((delta as Dictionary).get("label", ""))]
		_text(Vector2(cx + 10.0, cy), line, 12, Color("#8fe0a8") if value > 0.0 else Color("#e08f8f"))
		cy += 18.0
	cy += 6.0
	if bool(check.get("ok", true)):
		_text(Vector2(cx, cy), "Wearable.  ENTER wears it.", 12, ACCENT)
	else:
		_text(Vector2(cx, cy), "Refused — %s" % String(check.get("reason", "cannot be worn")), 12, Color("#e08f8f"))


## The forge: recipes, refinement and disassembly behind one cursor. The panel
## never performs an action silently — ENTER is always the commitment.
func draw_forge(player: Player) -> void:
	if host == null or not bool(host.forge_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.86))
	var panel := Rect2(view * 0.5 - Vector2(390.0, 240.0), Vector2(780.0, 480.0))
	draw_rect(panel, Color("#0b1014", 0.97))
	draw_rect(panel, Color("#e0a060", 0.45), false, 1.5)
	var origin := panel.position
	_text(origin + Vector2(22.0, 32.0), "AZURE FORGE", 18, Color("#e8b070"))
	var modes: Array[String] = ["FORGE", "REFINE", "DISASSEMBLE"]
	var mode := int(host.forge_mode)
	var tabs := ""
	for i in modes.size():
		tabs += ("[%s] " % modes[i]) if i == mode else (" %s  " % modes[i])
	_text(origin + Vector2(160.0, 32.0), tabs + "   TAB switches", 11, MUTED)
	_text(origin + Vector2(22.0, 52.0), "↑/↓ choose    ENTER work    E — close", 11, Color("#6b7b84"))
	_text(origin + Vector2(430.0, 52.0), Professions.progress_text(Game.professions, "profession.smith", DB), 11, Color("#d8c070"))

	var rows: Array = host.forge_rows()
	var selected := clampi(int(host.forge_index), 0, maxi(0, rows.size() - 1))
	var first := maxi(0, selected - 10)
	var list_y := origin.y + 82.0
	if rows.is_empty():
		_text(Vector2(origin.x + 22.0, list_y), "Nothing to work here.", 12, MUTED)
	for i in range(first, mini(rows.size(), first + 12)):
		var entry: Dictionary = rows[i]
		var label := String(entry.get("name", "?")) if mode == 0 else Items.label(entry)
		if mode == 0 and not bool(Professions.gate(entry, Game.professions, DB).get("ok", false)):
			label += "  (locked)"
		var line := "%s %s" % [">" if i == selected else " ", _fit(label, 12, 330.0)]
		_text(Vector2(origin.x + 22.0, list_y), line, 12, ACCENT if i == selected else _item_color(entry))
		list_y += 20.0
	if rows.is_empty():
		return

	var chosen: Dictionary = rows[selected]
	var cx := origin.x + 390.0
	var cy := origin.y + 82.0
	if mode == 0:
		var check: Dictionary = Crafting.check(chosen, player.inventory, Game.spirit_stones, player.cultivation.realm)
		var base: Dictionary = DB.base_item(String((chosen.get("output", {}) as Dictionary).get("base", "")))
		_text(Vector2(cx, cy), String(chosen.get("name", "?")), 14, ACCENT)
		cy += 22.0
		_text(Vector2(cx, cy), _fit("Makes: %s (ilvl %d+)" % [String(base.get("name", "?")), maxi(int(base.get("ilvl", 1)), player.cultivation.realm)], 12, 360.0), 12, MUTED)
		cy += 20.0
		_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(chosen), 11, 360.0), 11, Color("#d8c070"))
		cy += 20.0
		_text(Vector2(cx, cy), _fit(String(chosen.get("desc", "")), 11, 360.0), 11, Color("#7f9098"))
		cy += 32.0
		var gate: Dictionary = Professions.gate(chosen, Game.professions, DB)
		if not bool(gate.get("ok", false)):
			_text(Vector2(cx, cy), "Locked — %s." % String(gate.get("reason", "rank too low")), 12, Color("#e08f8f"))
		elif bool(check.get("ok", false)):
			_text(Vector2(cx, cy), "Ready.  ENTER forges it.", 12, ACCENT)
		else:
			_text(Vector2(cx, cy), _fit("Refused — %s" % String(check.get("reason", "not enough")), 11, 360.0), 11, Color("#e08f8f"))
		return

	var rules: Dictionary = host.forge_cost(mode)
	_text(Vector2(cx, cy), _fit(Items.label(chosen), 14, 360.0), 14, _item_color(chosen))
	cy += 22.0
	if mode == 1:
		var refine_check: Dictionary = Crafting.check(rules, player.inventory, Game.spirit_stones, player.cultivation.realm)
		_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(rules), 11, 360.0), 11, Color("#d8c070"))
		cy += 20.0
		_text(Vector2(cx, cy), _fit(String(rules.get("desc", "")), 11, 360.0), 11, Color("#7f9098"))
		cy += 32.0
		if bool(chosen.get("unique", false)):
			_text(Vector2(cx, cy), "An authored relic refuses a smith.", 11, Color("#e08f8f"))
		elif not bool(refine_check.get("ok", false)):
			_text(Vector2(cx, cy), _fit("Needs %s." % String(refine_check.get("reason", "more")), 11, 360.0), 11, Color("#e08f8f"))
		else:
			_text(Vector2(cx, cy), "ENTER rerolls every affix.", 12, ACCENT)
		return
	var ore := Crafting.disassemble_ore(chosen)
	_text(Vector2(cx, cy), "Yields: %d Spirit Ore" % ore, 12, Color("#d8c070"))
	cy += 20.0
	_text(Vector2(cx, cy), _fit(String(rules.get("desc", "")), 11, 360.0), 11, Color("#7f9098"))
	cy += 32.0
	if ore <= 0:
		_text(Vector2(cx, cy), "That cannot be broken down.", 11, Color("#e08f8f"))
	elif bool(chosen.get("unique", false)):
		_text(Vector2(cx, cy), "An authored relic refuses the hammer.", 11, Color("#e08f8f"))
	else:
		_text(Vector2(cx, cy), "ENTER breaks it down for good.", 12, ACCENT)


## The cauldron: potions, their effects and exactly what they will cost. The
## panel never brews silently — ENTER is the commitment.
func draw_alchemy(player: Player) -> void:
	if host == null or not bool(host.alchemy_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.86))
	var panel := Rect2(view * 0.5 - Vector2(370.0, 215.0), Vector2(740.0, 430.0))
	draw_rect(panel, Color("#0b1014", 0.97))
	draw_rect(panel, Color("#8fd8a0", 0.45), false, 1.5)
	var origin := panel.position
	_text(origin + Vector2(22.0, 32.0), "HERB-GARDEN CAULDRON", 18, Color("#9fe0a8"))
	_text(origin + Vector2(272.0, 32.0), "↑/↓ choose    ENTER brew    E — close", 11, MUTED)
	_text(origin + Vector2(22.0, 52.0), Professions.progress_text(Game.professions, "profession.alchemist", DB), 11, Color("#d8c070"))

	var rows: Array = host.alchemy_rows()
	var selected := clampi(int(host.alchemy_index), 0, maxi(0, rows.size() - 1))
	var list_y := origin.y + 72.0
	if rows.is_empty():
		_text(Vector2(origin.x + 22.0, list_y), "Nothing can be brewed here.", 12, MUTED)
		return
	for i in rows.size():
		var entry: Dictionary = rows[i]
		var check: Dictionary = Crafting.check(entry, player.inventory, Game.spirit_stones, player.cultivation.realm)
		var locked := not bool(Professions.gate(entry, Game.professions, DB).get("ok", false))
		var label := String(entry.get("name", "?")) + ("  (locked)" if locked else "")
		var line := "%s %s" % [">" if i == selected else " ", _fit(label, 12, 290.0)]
		var color := ACCENT if i == selected else Color("#9fc8a8")
		if (not bool(check.get("ok", false)) or locked) and i != selected:
			color = Color("#6b7b84")
		_text(Vector2(origin.x + 22.0, list_y), line, 12, color)
		list_y += 22.0

	var chosen: Dictionary = rows[selected]
	var base: Dictionary = DB.base_item(String(chosen.get("base", "")))
	var rules_check: Dictionary = Crafting.check(chosen, player.inventory, Game.spirit_stones, player.cultivation.realm)
	var cx := origin.x + 360.0
	var cy := origin.y + 66.0
	_text(Vector2(cx, cy), String(chosen.get("name", "?")), 14, ACCENT)
	cy += 22.0
	_text(Vector2(cx, cy), _fit("Brews: %s (ilvl %d+)" % [String(base.get("name", "?")), maxi(int(base.get("ilvl", 1)), player.cultivation.realm)], 12, 350.0), 12, MUTED)
	cy += 20.0
	_text(Vector2(cx, cy), Alchemy.effect_text(chosen), 12, Color("#8fd8a0"))
	cy += 20.0
	var potency := Alchemy.potency_for(player.stats.crafting_quality_mult(), false)
	_text(Vector2(cx, cy), "Your insight: potency x%.2f" % potency, 11, Color("#7f9098"))
	cy += 20.0
	_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(chosen), 11, 350.0), 11, Color("#d8c070"))
	cy += 20.0
	_text(Vector2(cx, cy), _fit(String(chosen.get("desc", "")), 11, 350.0), 11, Color("#7f9098"))
	cy += 34.0
	var gate: Dictionary = Professions.gate(chosen, Game.professions, DB)
	if not bool(gate.get("ok", false)):
		_text(Vector2(cx, cy), "Locked — %s." % String(gate.get("reason", "rank too low")), 12, Color("#e08f8f"))
	elif bool(rules_check.get("ok", false)):
		_text(Vector2(cx, cy), "Ready.  ENTER brews one.", 12, ACCENT)
	else:
		_text(Vector2(cx, cy), _fit("Refused — %s" % String(rules_check.get("reason", "not enough")), 11, 350.0), 11, Color("#e08f8f"))
	cy += 26.0
	_text(Vector2(cx, cy), "Pills are drunk from the satchel (I, then U).", 11, Color("#7f9098"))


## The person in front of the body: the whole database entry, not a name plate.
## It follows proximity instead of a key, so walking away closes it and no part
## of the run has to pause for a glance.
func draw_npc_dossier(_player: Player) -> void:
	if host == null:
		return
	var npc := host.nearest_npc() as Npc
	if npc == null:
		return
	var x := 24.0
	var y := 334.0
	var width := 432.0
	draw_rect(Rect2(x - 12.0, y - 22.0, width, 252.0), PANEL_BG)
	draw_rect(Rect2(x - 12.0, y - 22.0, width, 252.0), Color("#5f7f8c", 0.45), false, 1.0)
	_text(Vector2(x, y), _fit("%s — %s" % [npc.display_name, npc.role], 15, 408.0), 15, ACCENT)
	y += 20.0
	var sect_part := ""
	if String(npc.sect_id) != "":
		sect_part = " · " + String(npc.sect_id)
	var realm_name := String(DB.realm(npc.realm).get("name", "Realm %d" % npc.realm))
	_text(Vector2(x, y), _fit("Realm %d — %s%s · nerve %s" % [
		npc.realm, realm_name, sect_part, npc.nerve_label()], 11, 408.0), 11, MUTED)
	y += 17.0
	# An alarm replaces the routine line: what the body is doing about the threat
	# matters more than what the hour had planned for it.
	var routine := npc.activity_line()
	var routine_color := Color("#9fb0b8")
	if npc.reacting():
		routine = npc.reaction_line()
		routine_color = Color("#ffb08f")
	elif npc.travelling():
		routine += " · walking"
	_text(Vector2(x, y), _fit(routine, 11, 408.0), 11, routine_color)
	y += 17.0
	_text(Vector2(x, y), npc.attrs.summary(), 11, INK)
	y += 17.0
	var root: Dictionary = DB.by_id("root", npc.root_id)
	var purity := Roots.purity_label(float(root.get("purity", 0.5)))
	_text(Vector2(x, y), _fit("Root: %s (tier %d, %s)   Body: %s" % [
		npc.root_name(), npc.root_tier, purity, npc.physique_name()], 11, 408.0), 11, Color("#c8b8e8"))
	y += 17.0
	var arts: Array[String] = npc.technique_names()
	_text(Vector2(x, y), _fit("Arts: " + (", ".join(arts) if not arts.is_empty() else "none"), 11, 408.0), 11, Color("#8fd8e8"))
	y += 17.0
	var worn: Array[String] = []
	for slot in ["weapon", "armor", "ring", "talisman"]:
		var piece: Variant = npc.gear.get(slot, {})
		if typeof(piece) == TYPE_DICTIONARY and not (piece as Dictionary).is_empty():
			worn.append(String((piece as Dictionary).get("name", String(slot))))
	_text(Vector2(x, y), _fit("Gear: " + (", ".join(worn) if not worn.is_empty() else "nothing"), 11, 408.0), 11, Color("#d0b888"))
	y += 17.0
	var ambition: Array[String] = npc.goal_labels()
	_text(Vector2(x, y), _fit("Goals: " + (", ".join(ambition) if not ambition.is_empty() else "none"), 11, 408.0), 11, Color("#d8c070"))
	y += 17.0
	var memory: Dictionary = NpcDb.memory_entry(Game.npc_memory, npc.npc_id)
	var bond: Dictionary = npc.bond_to_player()
	var relation := "A stranger (%+d). E — talk." % int(bond.get("score", 0))
	if bool(memory.get("met", false)):
		relation = "Met %d× · day %d · %s · regard %+d (%s)" % [
			int(memory.get("talks", 0)), int(memory.get("last_day", 0)),
			Relationships.describe(int(bond.get("score", 0))),
			npc.standing(), npc.standing_label()]
	_text(Vector2(x, y), _fit(relation, 11, 408.0), 11, MUTED)
	y += 16.0
	# Authored ties take the footnote when a person has any: they are facts about
	# two people, not numbers the run can warm up or grind down.
	var footnote := "The sheet regenerates from the seed; memory is saved."
	var footnote_color := Color("#5f7079")
	if host != null:
		var ties := String(host.npc_tie_line(npc))
		if ties != "":
			footnote = ties
			footnote_color = Color("#c8b8e8")
	_text(Vector2(x, y), _fit(footnote, 10, 408.0), 10, footnote_color)


## The storehouse: the satchel on the left, the shelves on the right. The cursor
## sits on one side and ENTER moves that stack across whole.
func draw_storage(player: Player) -> void:
	if host == null or not bool(host.storage_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.86))
	var panel := Rect2(view * 0.5 - Vector2(380.0, 240.0), Vector2(760.0, 480.0))
	draw_rect(panel, Color("#0b1014", 0.97))
	draw_rect(panel, Color("#c8b070", 0.45), false, 1.5)
	var origin := panel.position
	_text(origin + Vector2(22.0, 32.0), "STOREHOUSE", 18, Color("#d8c070"))
	_text(origin + Vector2(166.0, 32.0), "←/→ side    ↑/↓ choose    ENTER move    E — close", 11, MUTED)

	var side := int(host.storage_side)
	var store: Storage = host.storage
	_text(origin + Vector2(22.0, 64.0), "SATCHEL  (%d kinds)" % player.inventory.size(), 11, ACCENT if side == 0 else MUTED)
	_text(origin + Vector2(390.0, 64.0), "STORED  (%d/%d kinds)" % [store.slots_used(), Storage.CAPACITY], 11, ACCENT if side == 1 else MUTED)
	var cursor := clampi(int(host.storage_index), 0, 999)
	for column in 2:
		var column_rows: Array = host.storage_rows(column)
		var active := column == side
		var chosen_index := cursor if active else 0
		chosen_index = clampi(chosen_index, 0, maxi(0, column_rows.size() - 1))
		var first := maxi(0, chosen_index - 9)
		var x := origin.x + (22.0 if column == 0 else 390.0)
		var y := origin.y + 90.0
		if column_rows.is_empty():
			_text(Vector2(x, y), "Empty.", 11, Color("#4a5a63"))
		for i in range(first, mini(column_rows.size(), first + 11)):
			var item: Dictionary = column_rows[i]
			var line := _fit(Items.label(item), 12, 330.0)
			var color := _item_color(item)
			if active and i == chosen_index:
				line = "> " + line
				color = ACCENT
			_text(Vector2(x, y), line, 12, color)
			y += 20.0

	var chosen: Dictionary = host.storage_selected()
	var footer_y := origin.y + 372.0
	if not chosen.is_empty():
		var line := "%s · %s · value %d · sells for %d" % [String(chosen.get("name", "?")), Inventory.slot_label(chosen), int(chosen.get("value", 0)), Economy.sell_value(chosen)]
		_text(Vector2(origin.x + 22.0, footer_y), _fit(line, 12, 716.0), 12, _item_color(chosen))
	else:
		_text(Vector2(origin.x + 22.0, footer_y), "Nothing selected.", 12, MUTED)
	_text(Vector2(origin.x + 22.0, footer_y + 26.0), "ENTER moves the whole stack across. The storehouse is saved with the run.", 11, MUTED)


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


## The encounter banner: the trial's name, its colour, and where in it you are.
func draw_tribulation() -> void:
	var arena := host.tribulation_arena as TribulationArena
	if arena == null or arena.tribulation == null:
		return
	var trial: Tribulation = arena.tribulation
	var color := Color(Tribulation.color_of(trial.type_id))
	var text := "TRIBULATION — %s · Wave %d/%d · Hits %d" % [
		Tribulation.name_of(trial.type_id), trial.wave, trial.waves_total, trial.hits
	]
	var width := _text_width(text, 16) + 32.0
	var pos := Vector2(size.x * 0.5 - width * 0.5, 56.0)
	draw_rect(Rect2(pos, Vector2(width, 30.0)), Color("#120d18", 0.85))
	draw_rect(Rect2(pos, Vector2(width, 30.0)), Color(color, 0.7), false, 1.5)
	_text(pos + Vector2(16.0, 20.0), text, 16, color)


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
	var lines := "WASD move · SHIFT sprint · LMB technique · RMB weapon strike · CTRL guard · SPACE dodge · F meditate · G tribulation · E interact · P party · 1-6 slot · Q cycle · [ ] bar · B bars · I satchel (U drinks a pill) · M map · F5 save · F9 load · F2 mute · F1 hide"
	var trade := "At a merchant: 1-6 buy/sell · TAB switch · E close · T travel · M map"
	_text(Vector2(24.0, size.y - 44.0), trade, 11, Color("#6b7b84"))
	_text(Vector2(24.0, size.y - 12.0), lines, 11, Color("#7b8b94"))
	var pad := "Gamepad: left stick move · right stick aim · X attack · LS click guard · A dodge · B interact · Y meditate · RB sprint · LB shop · DPAD travel/waypoint"
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
