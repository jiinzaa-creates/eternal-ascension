class_name Hud
extends Control
## Combat, progression and quest HUD, drawn entirely in code.
##
## Code-drawn UI is a deliberate art direction, not a placeholder: it keeps the
## interface legible at any resolution and avoids shipping borrowed asset packs.

## The palette is mutable so the accessibility option can raise contrast for
## every panel at once. Defaults are the authored colours.
var PANEL_BG := Color("#0d1216", 0.74)
var INK := Color("#e6eef2")
var MUTED := Color("#8fa2ab")
var ACCENT := Color("#9fe0c0")


## The two palettes as pure data, so the contrast choice is testable without a
## rendered frame.
static func palette(high_contrast: bool) -> Dictionary:
	if high_contrast:
		return {
			"panel": Color("#000000", 0.93),
			"ink": Color("#ffffff"),
			"muted": Color("#dce6ec"),
			"accent": Color("#ffe066"),
		}
	return {
		"panel": Color("#0d1216", 0.74),
		"ink": Color("#e6eef2"),
		"muted": Color("#8fa2ab"),
		"accent": Color("#9fe0c0"),
	}


func apply_palette(high_contrast: bool) -> void:
	var colours := palette(high_contrast)
	PANEL_BG = colours["panel"]
	INK = colours["ink"]
	MUTED = colours["muted"]
	ACCENT = colours["accent"]
	queue_redraw()


## An ambient panel in the shared frame language (see UiFrame).
func _panel(rect: Rect2) -> void:
	UiFrame.panel(self, rect, PANEL_BG)


## A full page's rect: the authored size, centred, and never larger than
## the screen minus a margin — no page hangs off the edge at any window
## size, and every hit test works from this same rect.
func _page_rect(want_w: float, want_h: float) -> Rect2:
	var w := minf(want_w, maxf(320.0, size.x - 32.0))
	var h := minf(want_h, maxf(240.0, size.y - 32.0))
	return Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5), Vector2(w, h))

var host: Node
var _font: Font
var _toasts: Array = []
var _help_visible := true
## The HUD draws live values, but sixty redraws a second buys nothing a player
## can see. Thirty is the authored cap; tests read `redraw_requests` to prove it.
const REDRAW_HZ := 30.0
const REDRAW_INTERVAL := 1.0 / REDRAW_HZ
var redraw_requests := 0
var _redraw_accum := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sync_view_size()
	# A Control created after the first scene has no resize event to inherit.
	# Without this the title-to-run change left the HUD at size zero: left panels
	# still drew, but centered text and right/bottom panels went off-screen.
	get_viewport().size_changed.connect(_sync_view_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	Bus.toast.connect(_on_toast)
	Bus.help_toggled.connect(func(visible: bool) -> void: _help_visible = visible)
	queue_redraw()


func _on_toast(text: String) -> void:
	_toasts.append({"text": text, "ttl": 6.0})
	if _toasts.size() > 6:
		_toasts.pop_front()


func _sync_view_size() -> void:
	var view := get_viewport_rect().size
	if size != view:
		size = view
		position = Vector2.ZERO
		queue_redraw()


func _process(delta: float) -> void:
	_sync_view_size()
	# Only rebuild the toast list when something actually expired, instead of
	# allocating a filtered array every frame.
	var expired := false
	for toast in _toasts:
		var ttl := float(toast["ttl"]) - delta
		toast["ttl"] = ttl
		if ttl <= 0.0:
			expired = true
	if expired:
		_toasts = _toasts.filter(func(t: Dictionary) -> bool: return float(t["ttl"]) > 0.0)
	# Clamp before testing: a long frame (a paused editor, a load hitch) must not
	# leave a debt that makes the next frames redraw faster than the cap.
	_redraw_accum = minf(_redraw_accum + delta, REDRAW_INTERVAL)
	if _redraw_accum >= REDRAW_INTERVAL:
		_redraw_accum = 0.0
		redraw_requests += 1
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
	draw_rect(Rect2(pos, bar_size), UiFrame.BRONZE_DIM, false, 1.0)
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
	draw_cultivating(player)
	draw_techniques(player)
	draw_minimap(player)
	draw_menu_button()
	draw_gear(player)
	draw_storage(player)
	draw_forge(player)
	draw_alchemy(player)
	draw_prompt()
	draw_realm_banner()
	draw_tribulation()
	draw_inheritance_trial()
	draw_captive_ledger(player)
	draw_chronicle(player)
	draw_factions(player)
	draw_sects(player)
	draw_hierarchy(player)
	draw_sect_ledger(player)
	draw_council(player)
	draw_player_sect(player)
	draw_sect_seat(player)
	draw_storylines(player)
	draw_narrative(player)
	draw_endgame(player)
	draw_character(player)
	draw_settings(player)
	if host != null and bool(host.get("menu_open")):
		draw_menu()
	draw_toasts()


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
	# The life may have written the blank page. The death screen keeps the
	# epitaph, because the choice is part of the run rather than a menu state.
	if host != null and host.endgame != null and host.endgame.is_chosen():
		var written := "THE PAGE YOU WROTE — %s" % String(
			host.endgame.chosen().get("title", "")).to_upper()
		_text(center + Vector2(-_text_width(written, 13) * 0.5, 62.0), written, 13,
			Color("#d8c070"))
	var hint := "ENTER — begin again"
	_text(center + Vector2(-_text_width(hint, 16) * 0.5, 110.0), hint, 16, Color("#e8d9a8"))


func draw_vitals(player: Player) -> void:
	# The vitals, and nothing else: two orbs in the Diablo manner, top-left.
	# Everything this panel used to recite — root, physique, derived stats,
	# passives, meridians — lives on the character sheet now, where it has
	# room to be read.
	var hp_ratio := clampf(player.hp / maxf(1.0, player.hp_max), 0.0, 1.0)
	if hp_ratio < 0.25 and player.hp > 0.0:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 180.0)
		draw_arc(Vector2(62.0, 62.0), 47.0, 0.0, TAU, 48, Color("#e0483c", 0.30 + 0.40 * pulse), 3.0)
	_orb(Vector2(62.0, 62.0), 42.0, hp_ratio, Color("#d84a35"))
	_text_centred(Vector2(62.0, 68.0), "%d" % int(player.hp), 17, Color("#ffe9e2"))
	_text_centred(Vector2(62.0, 83.0), "/ %d" % int(player.hp_max), 9, Color("#e8b8ac"))
	var qi_cap := player.cultivation.qi_max(player.stats)
	var qi_ratio := clampf(player.cultivation.qi / maxf(1.0, qi_cap), 0.0, 1.0)
	_orb(Vector2(142.0, 70.0), 34.0, qi_ratio, Color("#3fa8dd"))
	_text_centred(Vector2(142.0, 75.0), "%d" % int(player.cultivation.qi), 14, Color("#e2f2ff"))
	_text_centred(Vector2(142.0, 89.0), "QI", 8, Color("#a8cfe8"))


## Text centred on a point (pos.y stays the baseline).
func _text_centred(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	_text(pos - Vector2(_text_width(text, font_size) * 0.5, 0.0), text, font_size, color)


## One orb: dark glass, a liquid fill clipped by the circle, a gloss, and
## the bronze ring of the frame language.
func _orb(center: Vector2, radius: float, ratio: float, liquid: Color) -> void:
	draw_circle(center, radius, Color("#07090b", 0.88))
	var r := clampf(ratio, 0.0, 1.0)
	if r >= 0.999:
		draw_circle(center, radius - 1.5, liquid)
	elif r > 0.001:
		var fill_y := center.y + radius - 2.0 * radius * r
		var dy := clampf(fill_y - center.y, -radius, radius)
		var dx := sqrt(maxf(0.0, radius * radius - dy * dy))
		var a_start := atan2(dy, -dx)
		var a_end := atan2(dy, dx)
		var sweep := fposmod(a_start - a_end, TAU)
		var points := PackedVector2Array()
		var steps := 28
		for i in range(steps + 1):
			var a := a_start - sweep * float(i) / float(steps)
			points.append(center + Vector2(cos(a), sin(a)) * (radius - 1.5))
		draw_colored_polygon(points, liquid)
		draw_line(center + Vector2(-dx, dy) * 0.97, center + Vector2(dx, dy) * 0.97,
			Color(liquid, 0.55), 1.5)
	draw_circle(center + Vector2(-radius * 0.34, -radius * 0.40), radius * 0.16, Color(1, 1, 1, 0.10))
	draw_arc(center, radius + 1.0, 0.0, TAU, 64, UiFrame.BRONZE_DIM, 2.0)
	draw_arc(center, radius + 4.0, -2.2, -0.9, 16, UiFrame.BRONZE, 1.5)
	for k in range(4):
		var a := PI * 0.25 + float(k) * PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (radius + 2.0), center + dir * (radius + 6.0), UiFrame.BRONZE_DIM, 1.5)

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
	_panel(Rect2(x - 12.0, y - 22.0, 316.0, 212.0))
	_text(Vector2(x, y), "%s   %s" % [Clock.label(), Weather.label()], 13, MUTED)
	y += 18.0
	var tiding: String = host.world_event_line()
	if tiding == "":
		_text(Vector2(x, y), "Tiding: a quiet day", 11, MUTED)
	else:
		_text(Vector2(x, y), _fit("Tiding: " + tiding, 11, 292.0), 11, Color(host.world_event_color()))
	y += 18.0
	_text(Vector2(x, y), _fit("%s   %s   Kills %d   Karma %d" % [
		player.display_name, host.current_biome_name(), Game.kills, Game.karma], 11, 292.0), 11, MUTED)
	y += 18.0
	if Realms.can_spirit_scan(player.cultivation.realm):
		var sensed := _sensed_foe_line(player)
		if sensed != "":
			_text(Vector2(x, y), _fit(sensed, 11, 292.0), 11, Color("#9fd8e0"))
			y += 18.0
	UiFrame.divider(self, x, x + 292.0, y - 9.0)
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
	UiFrame.divider(self, x, x + 292.0, y - 9.0)
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
## Spirit scan (Nascent Soul+): the nearest living foe within sense
## range, read plainly — name and the state of its body.
func _sensed_foe_line(player: Player) -> String:
	var best: Dummy = null
	var best_distance := 900.0
	for node in get_tree().get_nodes_in_group("enemy"):
		var body := node as Dummy
		if body == null or body.state == "dead":
			continue
		var distance := player.global_position.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	if best == null:
		return ""
	var label := "Sense: %s · HP %d%%" % [best.display_name, roundi(100.0 * best.hp / maxf(1.0, best.hp_max))]
	if best.is_boss:
		label += " · BOSS"
	return label


func draw_waypoint(player: Player) -> void:
	var target: Vector2 = host.waypoint_position
	if target == Vector2.ZERO or String(host.phase) == "realm":
		return
	var distance := target.distance_to(player.global_position)
	var angle := Travel.bearing(player.global_position, target)
	var w := 230.0
	var x := size.x * 0.5 - w * 0.5
	var y := 14.0
	_panel(Rect2(x, y, w, 30.0))
	draw_set_transform(Vector2(x + 20.0, y + 15.0), angle, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(-5, 5), Vector2(-5, -5)]), ACCENT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text(Vector2(x + 38.0, y + 19.0), "%s · %s" % [String(host.waypoint_name), Travel.distance_label(distance)], 12, INK)


func draw_quest(_player: Player) -> void:
	var lines: Array = []
	var quests: QuestLog = host.quests as QuestLog
	if quests != null and quests.is_valid():
		lines = quests.tracker_lines(2)
	var stories: SectStorylines = host.storylines as SectStorylines
	if stories != null:
		lines.append_array(stories.tracker_lines(1))
	if lines.is_empty():
		return
	var w := size.x
	var y := 210.0
	var width := 316.0
	_panel(Rect2(w - 316.0 - 12.0, y - 22.0, width, 22.0 + float(lines.size()) * 18.0))
	for i in lines.size():
		var line := String(lines[i])
		var color := INK
		if line.begins_with("QUEST — "):
			color = Color("#d8c070")
		elif line.begins_with("STORY — "):
			color = Color("#a8d8c0")
		_text(Vector2(w - 316.0, y + float(i) * 18.0), _fit(line, 12, 292.0), 12, color)


## The travelling party, under the quest line: each member's name, trade, realm,
## bond and health. Every number comes from the body itself, so the panel cannot
## disagree with the fight happening behind it.
## The right-hand stack starts below the quest tracker, which grows with a
## second live quest. One fixed offset would let the two panels overlap.
func _side_panel_y() -> float:
	var extra := 0.0
	if host.quests != null:
		extra += maxf(0.0, float(host.quests.tracker_lines(2).size() - 2) * 18.0)
	if host.storylines != null:
		extra += float(host.storylines.tracker_lines(1).size()) * 18.0
	return 296.0 + extra


func draw_party(player: Player) -> void:
	var members: Array = host.party_members()
	if members.is_empty():
		return
	var x := size.x - 316.0
	var y := _side_panel_y()
	var height := 34.0 + float(members.size()) * 34.0
	_panel(Rect2(x - 12.0, y - 22.0, 316.0, height))
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


## The holding yard at a glance, under the party: who is kept, how loyal they
## are and what the yard yields. Empty and unremarkable until the player takes
## someone, and never louder than the fight it sits beside.
func draw_captives(player: Player) -> void:
	var rows: Array = host.captive_rows()
	if rows.is_empty() and Game.notoriety <= 0:
		return
	var members: Array = host.party_members()
	var x := size.x - 316.0
	var y := _side_panel_y()
	if not members.is_empty():
		y += 34.0 + float(members.size()) * 34.0
	var shown := mini(rows.size(), 3)
	var height := 58.0 + float(shown) * 18.0 + (16.0 if rows.size() > shown else 0.0)
	_panel(Rect2(x - 12.0, y - 22.0, 316.0, height))
	_text(Vector2(x, y), "CAPTIVES  %d/%d · %s" % [rows.size(), Captivity.max_held(),
		Captivity.policy_name(Game.captive_policy)], 12, ACCENT)
	var legal_colour := Color("#d06060") if Captivity.wanted(Game.notoriety) else MUTED
	_text(Vector2(x + 198.0, y), "%s %d" % [Captivity.legal_label(Game.notoriety), Game.notoriety], 11, legal_colour)
	y += 20.0
	for i in shown:
		var entry: Dictionary = rows[i]
		var line := "%s · %s (%d) · %d stones" % [String(entry["name"]), String(entry["band"]),
			int(entry["loyalty"]), int(entry["labor"])]
		_text(Vector2(x, y), _fit(line, 11, 290.0), 11, Color(String(entry["colour"])))
		y += 18.0
	if rows.size() > shown:
		_text(Vector2(x, y), "+%d more · L ledger" % (rows.size() - shown), 10, MUTED)


## The ledger: one row per person held, with the terms, the escape chance and
## what the watch would pay. Play is frozen while it is open, because deciding a
## person's sentence should not happen mid-swing.
func draw_captive_ledger(player: Player) -> void:
	if not bool(host.captives_open):
		return
	var rows: Array = host.captive_rows()
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.82))
	var w := minf(720.0, maxf(320.0, view.x - 32.0))
	var h := minf(470.0, maxf(240.0, view.y - 32.0))
	var x := view.x * 0.5 - w * 0.5
	var y := minf(92.0, maxf(16.0, view.y - h - 16.0))
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.96), Color("#7fd3e0", 0.4))
	_text(Vector2(x + 24.0, y + 34.0), "THE HOLDING YARD", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "Terms: %s — %s" % [
		Captivity.policy_name(Game.captive_policy), Captivity.policy_blurb(Game.captive_policy)], 11, MUTED)
	var legal_colour := Color("#d06060") if Captivity.wanted(Game.notoriety) else MUTED
	_text(Vector2(x + 24.0, y + 78.0), "%s (%d) · %d spirit stones" % [
		Captivity.legal_label(Game.notoriety), Game.notoriety, Game.spirit_stones], 11, legal_colour)
	draw_line(Vector2(x + 20.0, y + 94.0), Vector2(x + w - 20.0, y + 94.0), Color("#2b343a"), 1.0)

	var labour := 0
	var upkeep := 0
	for value in rows:
		var row: Dictionary = value
		labour += int(row["labor"])
		upkeep += int(row["upkeep"])
	var selected: int = clampi(int(host.captive_index), 0, maxi(0, rows.size() - 1))
	for i in rows.size():
		var entry: Dictionary = rows[i]
		var row_y := y + 124.0 + float(i) * 46.0
		var background := Color("#16232a", 0.92) if i == selected else Color("#111a1f", 0.6)
		draw_rect(Rect2(x + 16.0, row_y - 18.0, w - 32.0, 40.0), background)
		_text(Vector2(x + 28.0, row_y), "%s · realm %d · held %d day%s" % [String(entry["name"]),
			int(entry["realm"]), int(entry["held"]), "" if int(entry["held"]) == 1 else "s"], 13, INK)
		_text(Vector2(x + 28.0, row_y + 16.0), "%s (%d) · %d stones/day · escape %d%% · watch pays %d" % [
			String(entry["band"]), int(entry["loyalty"]), int(entry["labor"]),
			roundi(float(entry["escape"]) * 100.0), int(entry["bounty"])], 11, Color(String(entry["colour"])))

	_text(Vector2(x + 24.0, y + h - 56.0), "Today the yard yields %d stones; rations take %d." % [labour, upkeep], 12, MUTED)
	_text(Vector2(x + 24.0, y + h - 30.0), "UP/DOWN select · ENTER hand to the watch · U release · TAB terms · L/E close", 11, Color("#7b8b94"))


## The chronicle: what the market is saying and what it wants. A frozen reading
## screen like the holding ledger, because news should not be read mid-swing.
func draw_chronicle(player: Player) -> void:
	if not bool(host.chronicle_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.82))
	var _pr := _page_rect(760.0, 500.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.96), Color("#c8b070", 0.4))
	_text(Vector2(x + 24.0, y + 34.0), "THE MARKET'S TONGUE", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "Day %d — word travels faster than feet." % Clock.day, 11, MUTED)
	draw_line(Vector2(x + 20.0, y + 74.0), Vector2(x + w - 20.0, y + 74.0), Color("#2b343a"), 1.0)

	var rows: Array = host.chronicle_rows()
	var cursor := y + 96.0
	if rows.is_empty():
		_text(Vector2(x + 24.0, cursor), "Nothing worth repeating yet.", 12, MUTED)
	for i in mini(rows.size(), 8):
		var entry: Dictionary = rows[i]
		_text(Vector2(x + 24.0, cursor), _fit("Day %d · %s" % [int(entry.get("day", 0)),
			String(entry.get("headline", ""))], 12, w - 48.0), 12, INK)
		cursor += 20.0
		var detail := String(entry.get("detail", ""))
		if detail != "":
			_text(Vector2(x + 32.0, cursor), _fit(detail, 10, w - 64.0), 10, MUTED)
			cursor += 18.0

	var offers: Array = host.story_offer_rows()
	draw_line(Vector2(x + 20.0, y + h - 148.0), Vector2(x + w - 20.0, y + h - 148.0), Color("#2b343a"), 1.0)
	_text(Vector2(x + 24.0, y + h - 124.0), "REQUESTS", 12, Color("#e0c880"))
	cursor = y + h - 104.0
	if offers.is_empty():
		_text(Vector2(x + 24.0, cursor), "Nobody is asking anything of you today.", 11, MUTED)
	for i in mini(offers.size(), 4):
		var offer: Dictionary = offers[i]
		_text(Vector2(x + 24.0, cursor), _fit(Stories.offer_text(offer), 11, w - 48.0), 11, Color("#b8d8c0"))
		cursor += 18.0
	_text(Vector2(x + 24.0, y + h - 26.0), "J / E / ESC — close", 11, Color("#7b8b94"))


## The standings screen: who the player stands with, what the band does and who
## it moves when an action is taken. A reading screen like the chronicle.
func draw_factions(player: Player) -> void:
	if not bool(host.factions_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.84))
	var _pr := _page_rect(760.0, 470.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.97), Color("#c8b070", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "STANDINGS", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "What each house thinks of you, and what the band buys.", 11, MUTED)
	if Game.notoriety > 0:
		_text(Vector2(x + 24.0, y + 76.0), "Lawful factions remember the holding yard: notoriety %d." % Game.notoriety,
			11, Color("#d09090"))
	draw_line(Vector2(x + 20.0, y + 92.0), Vector2(x + w - 20.0, y + 92.0), Color("#2b343a"), 1.0)

	var rows: Array = host.faction_rows()
	var cursor := y + 116.0
	for i in mini(rows.size(), 5):
		var row: Dictionary = rows[i]
		var band_color := Color("#9fb0b8")
		match String(row.get("band", "")):
			"standing.hostile":
				band_color = Color("#e07070")
			"standing.wary":
				band_color = Color("#e0a070")
			"standing.trusted":
				band_color = Color("#8fd8a0")
			"standing.honoured":
				band_color = Color("#e8d090")
		_text(Vector2(x + 24.0, cursor), _fit("%s  ·  %s" % [String(row.get("name", "?")),
			String(row.get("kind", ""))], 14, w - 48.0), 14, Color(String(row.get("colour", "#9aa0a6"))))
		cursor += 20.0
		_text(Vector2(x + 24.0, cursor), "%s (%+d)  ·  members' regard %+d  ·  stall prices ×%.2f" % [
			String(row.get("label", "")), int(row.get("value", 0)), int(row.get("disposition", 0)),
			float(row.get("price_mult", 1.0))], 11, band_color)
		cursor += 18.0
		var relation := String(row.get("relations", ""))
		var line := String(row.get("blurb", ""))
		if relation != "":
			line += "   " + relation
		_text(Vector2(x + 24.0, cursor), _fit(line, 10, w - 48.0), 10, MUTED)
		cursor += 30.0

	_text(Vector2(x + 24.0, y + h - 26.0), "K / E / ESC — close   ·   helping one house warms its allies and cools its rivals",
		11, Color("#7b8b94"))


## The sect codex: twelve houses, their seats and economies, their fault lines,
## and the method and technique that make each of them a distinct answer.
func draw_sects(player: Player) -> void:
	if not bool(host.sects_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.86))
	var _pr := _page_rect(1000.0, 600.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.98), Color("#c8b070", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "THE TWELVE SECTS", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "Twelve houses, twelve answers to the same mountain.", 11, MUTED)
	var local := Sects.local_sect()
	if not local.is_empty():
		var faction_id := String(local.get("faction", ""))
		var standing := Factions.describe(faction_id, Game.faction_standing, Game.notoriety)
		var line := "Your gate: %s" % String(local.get("name", ""))
		if standing != "":
			line += "   ·   " + standing
		_text(Vector2(x + 24.0, y + 76.0), _fit(line, 11, w - 48.0), 11, Color("#c8b8e8"))
	draw_line(Vector2(x + 20.0, y + 92.0), Vector2(x + w - 20.0, y + 92.0), Color("#2b343a"), 1.0)

	var rows: Array = host.sect_rows()
	for i in mini(rows.size(), 12):
		var row: Dictionary = rows[i]
		var column := floori(float(i) / 6.0)
		var line_index := i % 6
		var cx := x + 24.0 + float(column) * 488.0
		var cy := y + 108.0 + float(line_index) * 76.0
		var colour := Color(String(row.get("colour", "#9aa0a6")))
		var name := "%s  ·  %s" % [String(row.get("name", "?")), String(row.get("seat", ""))]
		if bool(row.get("local", false)):
			name += "  (your gate)"
		_text(Vector2(cx, cy), _fit(name, 14, 448.0), 14, colour)
		_text(Vector2(cx, cy + 17.0), _fit(String(row.get("philosophy", "")), 10, 448.0), 10, INK)
		_text(Vector2(cx, cy + 32.0), _fit("%s · %s" % [String(row.get("method", "")),
			String(row.get("technique", ""))], 10, 448.0), 10, Color("#c8b070"))
		var trade := "%s · %s" % [String(row.get("territory", "")), String(row.get("economy", ""))]
		_text(Vector2(cx, cy + 46.0), _fit(trade, 9, 448.0), 9, MUTED)
		_text(Vector2(cx, cy + 59.0), _fit("Fault: " + String(row.get("fault_line", "")), 9, 448.0), 9,
			Color("#a08a8a"))

	_text(Vector2(x + 24.0, y + h - 22.0), "Y / E / ESC — close   ·   the twelve are content, not yet a simulation: hierarchy, economy and politics come later",
		10, Color("#7b8b94"))


## The sect hierarchy: the seven rungs and two offices of the Azure Cloud, who
## holds each, and where the player's standing and realm have placed them.
func draw_hierarchy(player: Player) -> void:
	if not bool(host.hierarchy_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.86))
	var _pr := _page_rect(900.0, 570.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.98), Color("#c8b070", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "SECT HIERARCHY", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "The Azure Cloud's ladder — a station is earned by standing and realm, not granted by a key.", 11, MUTED)
	var realm := player.cultivation.realm
	var current := Hierarchy.player_rank(realm, Game.faction_standing, Game.notoriety,
		Hierarchy.seat_available(Game.sect_seat_open))
	_text(Vector2(x + 24.0, y + 78.0), _fit("Your station: %s · authority %d" % [
		String(current.get("name", "")), Hierarchy.authority(String(current.get("id", "")))],
		12, w - 48.0), 12, Color("#d8c898"))
	draw_line(Vector2(x + 20.0, y + 94.0), Vector2(x + w - 20.0, y + 94.0), Color("#2b343a"), 1.0)

	var rows: Array = host.hierarchy_rows()
	var row_y := y + 114.0
	for i in mini(rows.size(), 7):
		var row: Dictionary = rows[i]
		if bool(row.get("you", false)):
			draw_rect(Rect2(x + 18.0, row_y - 14.0, 470.0, 48.0), Color("#1b2328", 0.9))
		_text(Vector2(x + 24.0, row_y), "%d  ·  %s   —   authority %d" % [
			int(row.get("level", 0)), String(row.get("name", "?")), int(row.get("authority", 0))],
			13, Color("#d8c898") if bool(row.get("you", false)) else ACCENT)
		var need: Dictionary = row.get("requires", {})
		var need_line := "Needs %d standing · realm %d" % [int(need.get("standing", -100)), int(need.get("realm", 1))]
		if bool(row.get("seat", false)):
			need_line = "The seat is held."
		_text(Vector2(x + 24.0, row_y + 17.0), _fit("%s   ·   %s" % [need_line, String(row.get("duty", ""))], 10, 456.0), 10, MUTED)
		var holders: Array = row.get("holders", [])
		var held := "No one holds it." if holders.is_empty() else "Held by: " + ", ".join(holders)
		_text(Vector2(x + 24.0, row_y + 31.0), _fit(held, 9, 456.0), 9, Color("#7f9098"))
		row_y += 54.0

	var right := x + 520.0
	_text(Vector2(right, y + 114.0), "YOUR STATION", 12, ACCENT)
	_text(Vector2(right, y + 140.0), _fit(String(current.get("name", "")), 18, 348.0), 18, Color("#d8c898"))
	_text(Vector2(right, y + 160.0), _fit(Hierarchy.duty(String(current.get("id", ""))), 10, 348.0), 10, INK)
	_text(Vector2(right, y + 176.0), _fit("Privilege: " + Hierarchy.privilege(String(current.get("id", ""))), 10, 348.0), 10, MUTED)
	_text(Vector2(right, y + 192.0), "Contribution %d · stipend %d/day" % [Game.sect_contribution,
		SectEconomy.stipend_net(String(current.get("id", "")))], 10, Color("#d8c070"))
	var next := Hierarchy.next_rank(String(current.get("id", "")))
	var next_line := "No rung above this one."
	if not next.is_empty():
		var missing := Hierarchy.missing_for(String(next.get("id", "")), realm, Game.faction_standing,
			Game.notoriety, Hierarchy.seat_available(Game.sect_seat_open))
		if missing.is_empty():
			next_line = "Next: %s — ready." % String(next.get("name", ""))
		else:
			next_line = "Next: %s — %s" % [String(next.get("name", "")), ", ".join(missing)]
	_text(Vector2(right, y + 208.0), _fit(next_line, 10, 348.0), 10, Color("#a8d8c0"))
	draw_line(Vector2(right, y + 224.0), Vector2(x + w - 24.0, y + 224.0), Color("#2b343a"), 1.0)
	_text(Vector2(right, y + 244.0), "OFFICES", 12, ACCENT)
	var office_y := y + 266.0
	for i in range(7, mini(rows.size(), 9)):
		var office: Dictionary = rows[i]
		_text(Vector2(right, office_y), "%s · authority %d" % [String(office.get("name", "?")), int(office.get("authority", 0))], 12, Color("#c8b8e8"))
		var holders: Array = office.get("holders", [])
		_text(Vector2(right, office_y + 15.0), _fit(String(office.get("duty", "")), 9, 348.0), 9, INK)
		_text(Vector2(right, office_y + 28.0), _fit("Held by: " + (", ".join(holders) if not holders.is_empty() else "nobody"), 9, 348.0), 9, MUTED)
		office_y += 48.0

	_text(Vector2(x + 24.0, y + h - 22.0), "N / E / ESC — close   ·   rank follows Azure Cloud standing and realm; no rank counter is saved",
		10, Color("#7b8b94"))


## The sect ledger: the daily stipend, the two donation rates, and the
## quartermaster's shelves. A row that cannot be taken still shows why.
func draw_sect_ledger(player: Player) -> void:
	if not bool(host.sect_ledger_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.86))
	var _pr := _page_rect(820.0, 500.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.98), Color("#c8b070", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "SECT LEDGER", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "Contribution is earned in service and spent at the quartermaster's counter.", 11, MUTED)
	var rank := Hierarchy.player_rank(player.cultivation.realm, Game.faction_standing,
		Game.notoriety, Hierarchy.seat_available(Game.sect_seat_open))
	var rank_id := String(rank.get("id", "rank.servant"))
	_text(Vector2(x + 24.0, y + 78.0), _fit(SectEconomy.summary_line(rank_id, Game.sect_contribution,
		Game.sect_stipend_day, Clock.day), 11, w - 48.0), 11, Color("#d8c898"))
	_text(Vector2(x + w - 24.0 - 150.0, y + 78.0), "%d stones" % Game.spirit_stones, 11, Color("#e0c880"))
	draw_line(Vector2(x + 20.0, y + 94.0), Vector2(x + w - 20.0, y + 94.0), Color("#2b343a"), 1.0)

	var rows: Array = host.sect_ledger_rows()
	var cursor := clampi(int(host.sect_ledger_index), 0, maxi(0, rows.size() - 1))
	var row_y := y + 112.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var enabled := bool(row.get("enabled", false))
		if i == cursor:
			draw_rect(Rect2(x + 18.0, row_y - 14.0, w - 36.0, 44.0), Color("#1b2328", 0.92))
		var title := String(row.get("label", "?"))
		_text(Vector2(x + 28.0, row_y), _fit(title, 13, w - 56.0), 13,
			ACCENT if i == cursor else (INK if enabled else Color("#6f7f88")))
		var detail := String(row.get("detail", ""))
		if not enabled and String(row.get("reason", "")) != "":
			detail += "   — " + String(row.get("reason", ""))
		_text(Vector2(x + 28.0, row_y + 17.0), _fit(detail, 10, w - 56.0), 10,
			MUTED if enabled else Color("#8a7070"))
		row_y += 50.0

	_text(Vector2(x + 24.0, y + h - 22.0), "↑/↓ choose   ·   ENTER transact   ·   O / E / ESC — close",
		10, Color("#7b8b94"))


## The sect seat: the gate board as a page of choices — swear, renounce,
## learn the house's art, attune to its method, or buy standing with gifts.
func draw_sect_seat(player: Player) -> void:
	if not bool(host.sect_seat_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.86))
	var _pr := _page_rect(860.0, 540.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.98), Color("#c8b070", 0.45))
	var sect := Sects.sect(String(host.current_sect_id))
	var lead: Dictionary = Game.sect_leadership.get(String(host.current_sect_id), {})
	_text(Vector2(x + 24.0, y + 34.0), _fit(String(sect.get("name", "Sect")).to_upper(), 22, w - 48.0), 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), _fit("%s · Master %s · Deputy %s" % [
		String(sect.get("seat", "")),
		String(lead.get("master_name", "")) if String(lead.get("master_name", "")) != "" else String(sect.get("master", "")),
		String(lead.get("deputy_name", "")) if String(lead.get("deputy_name", "")) != "" else String(sect.get("deputy", ""))],
		11, w - 48.0), 11, MUTED)
	_text(Vector2(x + w - 24.0 - 150.0, y + 58.0), "%d stones" % Game.spirit_stones, 11, Color("#e0c880"))
	draw_line(Vector2(x + 20.0, y + 74.0), Vector2(x + w - 20.0, y + 74.0), Color("#2b343a"), 1.0)

	var rows: Array = host.sect_seat_rows()
	var cursor := clampi(int(host.sect_seat_index), 0, maxi(0, rows.size() - 1))
	var row_y := y + 112.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var enabled := bool(row.get("enabled", false))
		if i == cursor:
			draw_rect(Rect2(x + 18.0, row_y - 14.0, w - 36.0, 44.0), Color("#1b2328", 0.92))
		var title := String(row.get("label", "?"))
		_text(Vector2(x + 28.0, row_y), _fit(title, 13, w - 56.0), 13,
			ACCENT if i == cursor else (INK if enabled else Color("#6f7f88")))
		var detail := String(row.get("detail", ""))
		if not enabled and String(row.get("reason", "")) != "":
			detail += "   — " + String(row.get("reason", ""))
		_text(Vector2(x + 28.0, row_y + 17.0), _fit(detail, 10, w - 56.0), 10,
			MUTED if enabled else Color("#8a7070"))
		row_y += 50.0

	_text(Vector2(x + 24.0, y + h - 22.0), "↑/↓ choose   ·   ENTER decide   ·   E / ESC — close",
		10, Color("#7b8b94"))


## The council: three blocs with their support bars and one vote. Lobbying is a
## contribution purchase; the vote row states the rank and support it still wants.
func draw_council(player: Player) -> void:
	if not bool(host.council_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.86))
	var _pr := _page_rect(860.0, 520.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.98), Color("#c8b070", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "SECT COUNCIL", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "The master's seat is held. The blocs decide whether it opens to a challenge.",
		11, MUTED)
	_text(Vector2(x + 24.0, y + 78.0), "%d contribution   ·   %s" % [Game.sect_contribution,
		SectPolitics.summary_line(Game.sect_lobby)], 11, Color("#d8c898"))
	draw_line(Vector2(x + 20.0, y + 94.0), Vector2(x + w - 20.0, y + 94.0), Color("#2b343a"), 1.0)

	var rows: Array = host.council_rows()
	var cursor := clampi(int(host.council_index), 0, maxi(0, rows.size() - 1))
	var row_y := y + 112.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var enabled := bool(row.get("enabled", false))
		if i == cursor:
			draw_rect(Rect2(x + 18.0, row_y - 14.0, w - 36.0, 60.0), Color("#1b2328", 0.92))
		_text(Vector2(x + 28.0, row_y), _fit(String(row.get("label", "?")), 13, 240.0), 13,
			ACCENT if i == cursor else (INK if enabled else Color("#6f7f88")))
		_text(Vector2(x + 28.0, row_y + 16.0), _fit(String(row.get("speaker", "")), 10, 240.0), 10, MUTED)
		_text(Vector2(x + 280.0, row_y + 2.0), _fit(String(row.get("agenda", "")), 10, 340.0), 10, MUTED)
		var support := int(row.get("support", 0))
		var ceiling := maxi(1, int(row.get("max", 1)))
		var bar_x := x + 640.0
		var bar_w := 180.0
		draw_rect(Rect2(bar_x, row_y + 4.0, bar_w, 8.0), Color("#242c31"))
		draw_rect(Rect2(bar_x, row_y + 4.0, bar_w * clampf(float(support) / float(ceiling), 0.0, 1.0), 8.0),
			Color("#7fd3e0" if String(row.get("kind", "")) == "bloc" else "#c8b070"))
		_text(Vector2(bar_x, row_y + 22.0), "%d / %d" % [support, ceiling], 10, Color("#d8c898"))
		var action := ""
		if String(row.get("kind", "")) == "bloc":
			action = "%d contribution → +%d support" % [int(row.get("cost", 0)), int(row.get("gain", 0))]
		else:
			action = "Needs %d support and the station of %s" % [SectPolitics.threshold(),
				Hierarchy.title(SectPolitics.min_rank())]
		if not enabled and String(row.get("reason", "")) != "":
			action += "   — " + String(row.get("reason", ""))
		_text(Vector2(x + 280.0, row_y + 20.0), _fit(action, 10, 340.0), 10,
			MUTED if enabled else Color("#8a7070"))
		row_y += 68.0

	_text(Vector2(x + 24.0, y + h - 22.0), "↑/↓ choose   ·   ENTER lobby / call the vote   ·   F3 / E / ESC — close",
		10, Color("#7b8b94"))


## The player's hall: founding choices before the hall exists, then the daily
## levy and live recruitment beside the roster. Status is always read fresh.
func draw_player_sect(player: Player) -> void:
	if not bool(host.player_sect_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.86))
	var _pr := _page_rect(880.0, 560.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.98), Color("#c8b070", 0.45))
	var founded := not Game.player_sect.is_empty()
	if founded:
		_text(Vector2(x + 24.0, y + 34.0), _fit(String(Game.player_sect.get("name", "YOUR SECT")), 22, 520.0),
			22, ACCENT)
		_text(Vector2(x + 24.0, y + 58.0), PlayerSect.summary_line(Game.player_sect), 11, MUTED)
	else:
		_text(Vector2(x + 24.0, y + 34.0), "FOUND A SECT", 22, ACCENT)
		_text(Vector2(x + 24.0, y + 58.0), "Your own hall, your own creed. The choice cannot be taken back.",
			11, MUTED)
		var missing := PlayerSect.can_found(Game.player_sect, Game.spirit_stones, host._player_rank_id())
		var need := "Ready to found." if missing.is_empty() else "Needs " + ", ".join(missing)
		_text(Vector2(x + 24.0, y + 78.0), _fit(need, 11, w - 48.0), 11,
			Color("#a8d8c0") if missing.is_empty() else Color("#d8a080"))
		draw_line(Vector2(x + 20.0, y + 94.0), Vector2(x + w - 20.0, y + 94.0), Color("#2b343a"), 1.0)

	var rows: Array = host.player_sect_rows()
	var cursor := clampi(int(host.player_sect_index), 0, maxi(0, rows.size() - 1))
	var row_y := y + 112.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var enabled := bool(row.get("enabled", false))
		if i == cursor:
			draw_rect(Rect2(x + 18.0, row_y - 14.0, 520.0, 48.0), Color("#1b2328", 0.92))
		_text(Vector2(x + 28.0, row_y), _fit(String(row.get("label", "?")), 13, 490.0), 13,
			ACCENT if i == cursor else (INK if enabled else Color("#6f7f88")))
		_text(Vector2(x + 28.0, row_y + 17.0), _fit(String(row.get("detail", "")), 10, 490.0), 10,
			MUTED if enabled else Color("#8a7070"))
		var blurb := String(row.get("blurb", ""))
		if not enabled and String(row.get("reason", "")) != "":
			blurb = String(row.get("reason", ""))
		_text(Vector2(x + 28.0, row_y + 31.0), _fit(blurb, 10, 490.0), 10, Color("#7b8b94"))
		row_y += 52.0

	if founded:
		draw_line(Vector2(x + 556.0, y + 106.0), Vector2(x + 556.0, y + h - 44.0), Color("#2b343a"), 1.0)
		_text(Vector2(x + 576.0, y + 126.0), "ROSTER", 12, ACCENT)
		_text(Vector2(x + 576.0, y + 148.0), "%d / %d members · %d stones" % [
			PlayerSect.member_count(Game.player_sect), PlayerSect.capacity(Game.player_sect),
			int(Game.player_sect.get("treasury", 0))], 10, Color("#d8c898"))
		var steward: Dictionary = host.player_sect_steward()
		var steward_line := "Steward: the hall waits."
		if not steward.is_empty():
			steward_line = "Steward: %s (%s)" % [String(steward.get("name", "?")), String(steward.get("rank", ""))]
		_text(Vector2(x + 576.0, y + 166.0), _fit(steward_line, 10, 260.0), 10, Color("#a8d8c0"))
		_text(Vector2(x + 576.0, y + 188.0), "MEMBERS", 11, ACCENT)
		var members: Array = host.player_sect_members()
		var member_y := y + 206.0
		if members.is_empty():
			_text(Vector2(x + 576.0, member_y), "No one has joined yet.", 10, MUTED)
		for i in mini(members.size(), 5):
			var member: Dictionary = members[i]
			_text(Vector2(x + 576.0, member_y), _fit("%s — %s" % [String(member.get("name", "?")),
				String(member.get("rank", ""))], 10, 260.0), 10, INK)
			_text(Vector2(x + 576.0, member_y + 13.0), Realms.name_of(int(member.get("realm", 1))), 9, MUTED)
			member_y += 32.0
		if members.size() > 5:
			_text(Vector2(x + 576.0, member_y), "and %d more" % (members.size() - 5), 9, MUTED)
		_text(Vector2(x + 576.0, y + 390.0), "HALL REPORT", 11, ACCENT)
		var log_value: Variant = Game.player_sect.get("log", [])
		var log_lines: Array = []
		if typeof(log_value) == TYPE_ARRAY:
			log_lines = log_value
		var log_y := y + 408.0
		if log_lines.is_empty():
			_text(Vector2(x + 576.0, log_y), "No days have passed yet.", 9, MUTED)
		for i in mini(log_lines.size(), 6):
			_text(Vector2(x + 576.0, log_y), _fit(String(log_lines[log_lines.size() - 1 - i]), 9, 270.0), 9, MUTED)
			log_y += 15.0

	_text(Vector2(x + 24.0, y + h - 22.0), "↑/↓ choose   ·   ENTER found / recruit   ·   the hall levies and pays itself   ·   F4 / E / ESC — close",
		10, Color("#7b8b94"))


## The twelve houses' own stories: every arc, its live chapter, that house's
## regard, and the two stances once a chapter's test is paid. A frozen reading
## screen like the ledger, because a house's future should not be decided
## mid-swing.
func draw_storylines(_player: Player) -> void:
	if not bool(host.storylines_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.86))
	var _pr := _page_rect(1040.0, 652.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0d1216", 0.98), Color("#c8b070", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "SECT STORYLINES", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "Twelve houses, one story each — the same stakes, never the same work.", 11, MUTED)
	var active := 0
	var finished := 0
	if host.storylines != null:
		active = host.storylines.accepted_ids().size()
		finished = host.storylines.completed_ids().size()
	_text(Vector2(x + 24.0, y + 78.0), "%d open · regard is the house's memory of you · %d complete" % [
		active, finished], 11, Color("#d8c898"))
	draw_line(Vector2(x + 20.0, y + 94.0), Vector2(x + w - 20.0, y + 94.0), Color("#2b343a"), 1.0)

	var rows: Array = host.storyline_rows()
	var cursor := clampi(int(host.storyline_index), 0, maxi(0, rows.size() - 1))
	var row_y := y + 112.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var kind := String(row.get("kind", "info"))
		var status := String(row.get("status", "locked"))
		var selected := i == cursor
		var indent := 34.0 if kind == "choice" else 0.0
		if selected:
			draw_rect(Rect2(x + 18.0, row_y - 13.0, w - 36.0, 34.0), Color("#1b2328", 0.92))
		var colour := Color("#6f7f88")
		if status == "completed":
			colour = Color("#7f9098")
		elif status == "decision" or status == "choice":
			colour = Color("#e0c880")
		elif status == "active":
			colour = Color("#a8d8c0")
		elif status == "available":
			colour = Color("#7fd3e0")
		if kind == "choice":
			_text(Vector2(x + 32.0 + indent, row_y), _fit("› " + String(row.get("label", "")), 12, 640.0), 12,
				Color("#e0c880") if selected else Color("#c8b8a0"))
			_text(Vector2(x + 32.0 + indent, row_y + 14.0), _fit(String(row.get("reason", "")), 10, 640.0), 10,
				Color("#a8d8c0"))
		else:
			_text(Vector2(x + 28.0, row_y), _fit(String(row.get("label", "?")), 12, 620.0), 12,
				ACCENT if selected else colour)
			var detail := String(row.get("detail", ""))
			var reason := String(row.get("reason", ""))
			if reason != "":
				detail += "   — " + reason
			_text(Vector2(x + 28.0, row_y + 14.0), _fit(detail, 10, 720.0), 10, MUTED)
			var badge := "REGARD %d" % int(row.get("regard", 0))
			if bool(row.get("local", false)):
				badge = "YOUR GATE · " + badge
			_text(Vector2(x + w - 24.0 - _text_width(badge, 10), row_y), badge, 10,
				Color("#d8c898") if bool(row.get("local", false)) else Color("#7f9098"))
		row_y += 36.0

	_text(Vector2(x + 24.0, y + h - 22.0), "↑/↓ choose   ·   ENTER take a stance   ·   F6 / E / ESC — close",
		10, Color("#7b8b94"))


## The archive: four questions, each a chain of four records. A record is only
## printed once it is discovered; the one after it shows what the world still
## has to prove. A reading screen, frozen like the ledger.
func draw_narrative(_player: Player) -> void:
	if not bool(host.narrative_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#06080a", 0.88))
	var _pr := _page_rect(1100.0, 664.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0c1114", 0.98), Color("#8fb0c0", 0.42))
	_text(Vector2(x + 24.0, y + 34.0), "THE ARCHIVE", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "Four questions the province never answered. No prophecy, no chosen reader.", 11, MUTED)
	var total := 0
	var count := 0
	if host.narrative != null:
		total = host.narrative.total_count()
		count = host.narrative.known.size()
	_text(Vector2(x + 24.0, y + 78.0), "%d of %d records recovered · opening the archive also reads the world" % [
		count, total], 11, Color("#c8d8e0"))
	draw_line(Vector2(x + 20.0, y + 94.0), Vector2(x + w - 20.0, y + 94.0), Color("#2b343a"), 1.0)

	var threads: Array = host.narrative_threads()
	var thread_cursor := clampi(int(host.narrative_thread_index), 0, maxi(0, threads.size() - 1))
	var card_y := y + 112.0
	for i in threads.size():
		var thread_row: Dictionary = threads[i]
		var selected := i == thread_cursor
		var colour := Color(String(thread_row.get("colour", "#b8b8b8")))
		if selected:
			draw_rect(Rect2(x + 18.0, card_y - 6.0, 336.0, 112.0), Color("#162026", 0.96))
			draw_rect(Rect2(x + 18.0, card_y - 6.0, 3.0, 112.0), colour)
		_text(Vector2(x + 30.0, card_y + 14.0), _fit(String(thread_row.get("name", "?")), 13, 240.0), 13,
			colour if selected else Color("#a8b8c0"))
		var progress := String(thread_row.get("progress", ""))
		_text(Vector2(x + 344.0 - _text_width(progress, 10), card_y + 14.0), progress, 10, MUTED)
		_text(Vector2(x + 30.0, card_y + 34.0), _fit(String(thread_row.get("question", "")), 10, 310.0), 10,
			Color("#8fa2ab"))
		var blurb_lines := _wrapped(String(thread_row.get("blurb", "")), 9, 306.0)
		for line_index in mini(blurb_lines.size(), 2):
			_text(Vector2(x + 30.0, card_y + 54.0 + float(line_index) * 13.0), blurb_lines[line_index], 9,
				Color("#6f7f88"))
		var known_count := int(thread_row.get("known", 0))
		if known_count == int(thread_row.get("total", 0)) and known_count > 0:
			_text(Vector2(x + 30.0, card_y + 92.0), "THREAD COMPLETE", 9, colour.lerp(Color("#ffffff"), 0.35))
		card_y += 122.0

	var fragments: Array = host.narrative_thread_fragments()
	var fragment_cursor := clampi(int(host.narrative_revelation_index), 0, maxi(0, fragments.size() - 1))
	var row_y := y + 112.0
	for i in fragments.size():
		var row: Dictionary = fragments[i]
		var selected := i == fragment_cursor
		var known := bool(row.get("known", false))
		if selected:
			draw_rect(Rect2(x + 376.0, row_y - 10.0, 700.0, 62.0), Color("#162026", 0.96))
		var title_colour := Color("#e6eef2") if known else Color("#6f7f88")
		if bool(row.get("next", false)):
			title_colour = Color("#e0c880")
		_text(Vector2(x + 388.0, row_y + 8.0), "%02d" % (i + 1), 11, Color("#4f5f68"))
		_text(Vector2(x + 420.0, row_y + 8.0), _fit(String(row.get("title", "?")), 13, 470.0), 13, title_colour)
		var status := "UNRECORDED"
		if known:
			status = "RECORDED"
		elif bool(row.get("next", false)):
			status = "NEXT"
		_text(Vector2(x + 1064.0 - _text_width(status, 10), row_y + 8.0), status, 10,
			Color("#a8d8c0") if known else (Color("#e0c880") if status == "NEXT" else Color("#4f5f68")))
		var line := String(row.get("summary", "")) if known else String(row.get("hint", ""))
		_text(Vector2(x + 420.0, row_y + 27.0), _fit(line, 10, 620.0), 10,
			Color("#8fa2ab") if known else Color("#6f7f88"))
		row_y += 66.0

	var detail_rect := Rect2(x + 376.0, y + 392.0, 700.0, 218.0)
	UiFrame.card(self, detail_rect, Color("#0a0f12", 0.94), Color("#2b343a"))
	if not fragments.is_empty():
		var detail: Dictionary = fragments[fragment_cursor]
		var detail_known := bool(detail.get("known", false))
		_text(Vector2(x + 396.0, y + 420.0), _fit(String(detail.get("title", "")), 15, 640.0), 15,
			Color("#e6eef2") if detail_known else Color("#8fa2ab"))
		var detail_lines: PackedStringArray
		if detail_known:
			_text(Vector2(x + 396.0, y + 440.0), _fit("Source: " + String(detail.get("source", "")), 9, 650.0), 9,
				Color("#6f7f88"))
			detail_lines = _wrapped(String(detail.get("text", "")), 11, 640.0)
		else:
			_text(Vector2(x + 396.0, y + 440.0), "This page has not been found yet.", 10, Color("#6f7f88"))
			detail_lines = _wrapped(String(detail.get("hint", "")), 11, 640.0)
		var text_y := y + 466.0
		for line_index in mini(detail_lines.size(), 7):
			_text(Vector2(x + 396.0, text_y + float(line_index) * 18.0), detail_lines[line_index], 11,
				Color("#c8d4da") if detail_known else Color("#8fa2ab"))

	_text(Vector2(x + 24.0, y + h - 22.0), "←/→ thread   ·   ↑/↓ record   ·   F7 / E / ESC — close",
		10, Color("#7b8b94"))


## The blank page: four resolutions, each page's proof and price, and the
## epilogue a written save keeps. A reading screen, frozen like the archive.
func draw_endgame(_player: Player) -> void:
	if host == null or not bool(host.endgame_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.9))
	var _pr := _page_rect(1100.0, 664.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0c1012", 0.98), Color("#c8b070", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "THE BLANK PAGE", 22, Color("#e0d0a0"))
	_text(Vector2(x + 24.0, y + 58.0), "The book's last page is blank because the reader writes it. It is written once.", 11, MUTED)
	_text(Vector2(x + 24.0, y + 80.0), _fit("%s  ·  %s" % [
		String(host.endgame_progress()), String(host.endgame.threshold_summary())], 10, 1040.0), 10,
		Color("#a8b8c0"))

	var chosen: Dictionary = host.endgame_epilogue()
	if not chosen.is_empty():
		_draw_epilogue(chosen, x, y, w)
	elif not bool(host.endgame_ready()):
		_draw_page_unready(x, y, w)
	else:
		_draw_page_choices(x, y, w)

	_text(Vector2(x + 24.0, y + h - 22.0), "F8 / E / ESC — close", 10, Color("#7b8b94"))


func _draw_epilogue(chosen: Dictionary, x: float, y: float, w: float) -> void:
	var colour := Color(String(chosen.get("colour", "#c8d8e0")))
	_text(Vector2(x + 24.0, y + 112.0), "THE PAGE IS WRITTEN", 11, ACCENT)
	_text(Vector2(x + 24.0, y + 156.0), _fit(String(chosen.get("title", "")), 30, 1000.0), 30, colour)
	_text(Vector2(x + 24.0, y + 186.0), _fit(String(chosen.get("approach", "")), 13, 1010.0), 13,
		Color("#d8e4ea"))
	var promise_y := y + 216.0
	_text(Vector2(x + 24.0, promise_y), "WHAT IT PROMISED", 9, Color("#7f9098"))
	var promise := _wrapped(String(chosen.get("promise", "")), 11, 1010.0)
	for i in mini(promise.size(), 2):
		_text(Vector2(x + 24.0, promise_y + 17.0 + float(i) * 15.0), promise[i], 11,
			Color("#a8c8b8"))
	var cost_y := promise_y + 58.0
	_text(Vector2(x + 24.0, cost_y), "WHAT IT COST", 9, Color("#7f9098"))
	var cost := _wrapped(String(chosen.get("cost", "")), 11, 1010.0)
	for i in mini(cost.size(), 2):
		_text(Vector2(x + 24.0, cost_y + 17.0 + float(i) * 15.0), cost[i], 11,
			Color("#d8a8a0"))
	var epi_y := cost_y + 60.0
	draw_line(Vector2(x + 24.0, epi_y - 14.0), Vector2(x + w - 24.0, epi_y - 14.0),
		Color("#2b343a"), 1.0)
	var epilogue := _wrapped(String(chosen.get("epilogue", "")), 12, 1010.0)
	for i in mini(epilogue.size(), 12):
		_text(Vector2(x + 24.0, epi_y + 10.0 + float(i) * 20.0), epilogue[i], 12,
			Color("#d8e4ea"))


func _draw_page_unready(x: float, y: float, w: float) -> void:
	_text(Vector2(x + 24.0, y + 118.0), "THE PAGE WILL NOT TURN", 11, Color("#e0a080"))
	var intro := _wrapped("Each thread ends where the four questions meet. The page opens only when all four final records are recovered.", 11, 1010.0)
	for i in mini(intro.size(), 2):
		_text(Vector2(x + 24.0, y + 144.0 + float(i) * 16.0), intro[i], 11, Color("#8fa2ab"))
	var rows: Array = host.endgame_missing()
	var list_y := y + 202.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		draw_rect(Rect2(x + 24.0, list_y - 16.0, w - 48.0, 72.0), Color("#0a0f12", 0.94))
		_text(Vector2(x + 40.0, list_y + 2.0), "%02d" % (i + 1), 10, Color("#4f5f68"))
		_text(Vector2(x + 70.0, list_y + 2.0), _fit(String(row.get("title", "?")), 14, 620.0), 14,
			Color("#c8d4da"))
		_text(Vector2(x + 70.0, list_y + 23.0), _fit(String(row.get("summary", "")), 10, 900.0), 10,
			Color("#7f9098"))
		_text(Vector2(x + w - 178.0, list_y + 2.0), "UNRECOVERED", 9, Color("#6f7f88"))
		list_y += 82.0


func _draw_page_choices(x: float, y: float, w: float) -> void:
	var rows: Array = host.endgame_rows()
	if rows.is_empty():
		return
	var cursor := clampi(int(host.endgame_index), 0, rows.size() - 1)
	var list_y := y + 116.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var selected := i == cursor
		var colour := Color(String(row.get("colour", "#c8d8e0")))
		var unlocked := bool(row.get("unlocked", false))
		if selected:
			draw_rect(Rect2(x + 18.0, list_y - 10.0, 430.0, 104.0), Color("#162026", 0.96))
			draw_rect(Rect2(x + 18.0, list_y - 10.0, 3.0, 104.0), colour)
		var title_colour := colour if selected else (Color("#c8d4da") if unlocked else Color("#6f7f88"))
		_text(Vector2(x + 32.0, list_y + 14.0), _fit(String(row.get("title", "?")), 15, 390.0), 15, title_colour)
		_text(Vector2(x + 32.0, list_y + 36.0), _fit("Asks: " + String(row.get("proof", "")), 10, 390.0), 10,
			Color("#8fa2ab") if unlocked else Color("#6f7f88"))
		_text(Vector2(x + 32.0, list_y + 58.0), "READY" if unlocked else "CLOSED", 9,
			ACCENT if unlocked else Color("#a86f6f"))
		list_y += 114.0

	var chosen_row: Dictionary = rows[cursor]
	var colour := Color(String(chosen_row.get("colour", "#c8d8e0")))
	var px := x + 476.0
	var pw := 600.0
	var py := y + 108.0
	UiFrame.card(self, Rect2(px, py, pw, 512.0), Color("#0a0f12", 0.94), Color("#2b343a"))
	_text(Vector2(px + 22.0, py + 32.0), _fit(String(chosen_row.get("title", "")), 19, pw - 44.0), 19, colour)
	var cy := py + 56.0
	var approach := _wrapped(String(chosen_row.get("approach", "")), 12, pw - 44.0)
	for i in mini(approach.size(), 2):
		_text(Vector2(px + 22.0, cy + float(i) * 16.0), approach[i], 12, Color("#d8e4ea"))
	cy += 44.0
	_text(Vector2(px + 22.0, cy), "WHAT IT PROMISES", 9, Color("#7f9098"))
	var promise := _wrapped(String(chosen_row.get("promise", "")), 11, pw - 44.0)
	for i in mini(promise.size(), 3):
		_text(Vector2(px + 22.0, cy + 18.0 + float(i) * 15.0), promise[i], 11, Color("#a8c8b8"))
	cy += 72.0
	_text(Vector2(px + 22.0, cy), "WHAT IT COSTS", 9, Color("#7f9098"))
	var cost := _wrapped(String(chosen_row.get("cost", "")), 11, pw - 44.0)
	for i in mini(cost.size(), 3):
		_text(Vector2(px + 22.0, cy + 18.0 + float(i) * 15.0), cost[i], 11, Color("#d8a8a0"))
	cy += 76.0
	draw_line(Vector2(px + 22.0, cy - 14.0), Vector2(px + pw - 22.0, cy - 14.0), Color("#2b343a"), 1.0)
	_text(Vector2(px + 22.0, cy + 10.0), "WHAT THE PAGE ASKS", 9, Color("#7f9098"))
	_text(Vector2(px + 22.0, cy + 30.0), _fit(String(chosen_row.get("proof", "")), 12, pw - 44.0), 12,
		Color("#d8c898"))

	var status_y := cy + 58.0
	if not bool(chosen_row.get("unlocked", false)):
		var reason := _wrapped(String(chosen_row.get("reason", "")), 11, pw - 44.0)
		for i in mini(reason.size(), 2):
			_text(Vector2(px + 22.0, status_y + float(i) * 16.0), reason[i], 11, Color("#e08f8f"))
	elif int(host.endgame_confirm_index) == cursor:
		_text(Vector2(px + 22.0, status_y), "Press ENTER again to write this page.", 12, Color("#e8c060"))
		_text(Vector2(px + 22.0, status_y + 18.0), "It cannot be unwritten, and no other page will be offered.", 10,
			Color("#c8a860"))
	else:
		_text(Vector2(px + 22.0, status_y), "ENTER considers this page. A second ENTER writes it.", 11, ACCENT)
	_text(Vector2(px + 22.0, py + 482.0), "One life, one page. The province keeps whatever is written.", 9,
		Color("#6f7f88"))


## The character sheet: six cards of live body data, all read from the same
## objects that fight, craft and climb. A read-only screen, frozen like the
## ledger, so no number here can drift from the run.
func draw_character(_player: Player) -> void:
	if host == null or not bool(host.character_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.9))
	var _pr := _page_rect(1120.0, 664.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0c1012", 0.98), Color("#9fe0c0", 0.42))
	_text(Vector2(x + 24.0, y + 34.0), "CHARACTER SHEET", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "Everything the body carries, read from the run itself.", 11, MUTED)
	_text(Vector2(x + w - 250.0, y + 34.0), "C / E / ESC — close", 10, Color("#7b8b94"))

	var sections: Array = host.character_sections()
	var card_w := 348.0
	var card_h := 250.0
	for i in mini(sections.size(), 6):
		var section: Dictionary = sections[i]
		var column := i % 3
		var row_index := 0 if i < 3 else 1
		var cx := x + 24.0 + float(column) * (card_w + 12.0)
		var cy := y + 96.0 + float(row_index) * (card_h + 12.0)
		UiFrame.card(self, Rect2(cx, cy, card_w, card_h), Color("#0a0f12", 0.94), Color("#2b343a"))
		var colour := Color(String(section.get("colour", "#9fe0c0")))
		_text(Vector2(cx + 14.0, cy + 24.0), String(section.get("title", "")), 12, colour)
		draw_line(Vector2(cx + 14.0, cy + 32.0), Vector2(cx + card_w - 14.0, cy + 32.0),
			Color("#2b343a"), 1.0)
		var line_y := cy + 48.0
		var lines: Array = section.get("lines", [])
		for line_value in lines:
			var wrapped := _wrapped(String(line_value), 10, card_w - 28.0)
			for piece in wrapped:
				if line_y > cy + card_h - 10.0:
					break
				_text(Vector2(cx + 14.0, line_y), piece, 10, Color("#c8d4da"))
				line_y += 14.0
			if line_y > cy + card_h - 10.0:
				break


## Settings and accessibility: two pages, every switch applied the moment it is
## changed and written to `user://options.cfg`, never to the run's save.
func draw_settings(_player: Player) -> void:
	if host == null or not bool(host.settings_open):
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.9))
	var _pr := _page_rect(1000.0, 600.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0c1012", 0.98), Color("#9fe0c0", 0.45))
	_text(Vector2(x + 24.0, y + 34.0), "SETTINGS & ACCESSIBILITY", 22, ACCENT)
	_text(Vector2(x + 24.0, y + 58.0), "These belong to you, not to the run: they survive every new life.", 11, MUTED)

	var tab_names: Array[String] = ["DISPLAY", "KEYBINDS"]
	var tab := clampi(int(host.settings_tab), 0, 1)
	for i in tab_names.size():
		var tab_rect := settings_tab_rect(i)
		UiFrame.plaque(self, tab_rect, Color("#10161a", 0.95),
			UiFrame.BRONZE if i == tab else UiFrame.BRONZE_DIM)
		_text(tab_rect.position + Vector2(12.0, 17.0), tab_names[i], 12,
			ACCENT if i == tab else Color("#7b8b94"))
	if String(host.settings_rebind_action) != "":
		_text(Vector2(x + 360.0, y + 84.0), "PRESS A KEY — ESC cancels, BACKSPACE unbinds", 11,
			Color("#e8c060"))

	var rows: Array = host.settings_rows()
	if rows.is_empty():
		_text(Vector2(x + 24.0, y + 120.0), "Nothing to configure.", 11, MUTED)
		return
	var cursor := clampi(int(host.settings_index), 0, rows.size() - 1)
	var first := maxi(0, cursor - 11)
	var row_y := y + 116.0
	for i in range(first, mini(rows.size(), first + 12)):
		var row: Dictionary = rows[i]
		var selected := i == cursor
		if selected:
			draw_rect(Rect2(x + 18.0, row_y - 14.0, 520.0, 30.0), Color("#162026", 0.96))
		_text(Vector2(x + 30.0, row_y), _fit(String(row.get("label", "?")), 12, 350.0), 12,
			ACCENT if selected else INK)
		var value := String(row.get("value", ""))
		if String(host.settings_rebind_action) == String(row.get("action", "")):
			value = "press a key…"
		var value_colour := Color("#a8d8c0") if value == "ON" else MUTED
		if value == "OFF":
			value_colour = Color("#a86f6f")
		elif value != "ON" and value != "OFF":
			value_colour = Color("#d8c898")
		_text(Vector2(x + 524.0 - _text_width(value, 11), row_y), value, 11, value_colour)
		row_y += 30.0

	var chosen: Dictionary = rows[cursor]
	var px := x + 568.0
	var pw := 408.0
	var py := y + 104.0
	UiFrame.card(self, Rect2(px, py, pw, 430.0), Color("#0a0f12", 0.94), Color("#2b343a"))
	_text(Vector2(px + 20.0, py + 30.0), _fit(String(chosen.get("label", "")), 16, pw - 40.0), 16, ACCENT)
	var detail := _wrapped(String(chosen.get("detail", "")), 11, pw - 40.0)
	var detail_y := py + 56.0
	for line in detail:
		if detail_y > py + 330.0:
			break
		_text(Vector2(px + 20.0, detail_y), line, 11, Color("#a8b8c0"))
		detail_y += 16.0
	_text(Vector2(px + 20.0, py + 350.0), "Current: " + String(chosen.get("value", "")), 11,
		Color("#d8c898"))
	_text(Vector2(px + 20.0, py + 376.0), String(chosen.get("hint", "")), 10, Color("#7f9098"))

	_text(Vector2(x + 24.0, y + h - 22.0),
		"TAB page   ·   ↑/↓ choose   ·   ←/→ adjust   ·   ENTER change   ·   mouse works too   ·   X / E / ESC — close",
		10, Color("#7b8b94"))


## Draw-time word wrap for the archive's prose. No layout node, no reflow pass:
## the same line breaks are used for every frame of the reading screen.
func _wrapped(text: String, font_size: int, max_width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line == "" else line + " " + word
		if _text_width(candidate, font_size) <= max_width:
			line = candidate
			continue
		if line != "":
			lines.append(line)
		line = word
	if line != "":
		lines.append(line)
	return lines


## The active bar only: six slots, each with its art's own cooldown sweep.
## Occupancy of the other two bars and any art off the bars are named on the
## line beneath, so the readout never hides a known technique.
func draw_techniques(player: Player) -> void:
	var x := 24.0
	var y := size.y - 96.0
	var slot_size := Vector2(112.0, 46.0)
	_panel(Rect2(x - 12.0, y - 24.0, slot_size.x * 6.0 + 24.0, 92.0))
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
	_panel(Rect2(w - 316.0 - 12.0, y - 22.0, 316.0, 170.0))
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
	UiFrame.page(self, panel, Color("#0b1014", 0.97), Color("#7fd3e0", 0.45))
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
		UiFrame.card(self, rect, Color("#111a1f"), Color("#243039"))
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
	UiFrame.page(self, panel, Color("#0b1014", 0.97), Color("#e0a060", 0.45))
	var origin := panel.position
	_text(origin + Vector2(22.0, 32.0), "AZURE FORGE", 18, Color("#e8b070"))
	var modes: Array[String] = ["FORGE", "REFINE", "UPGRADE", "ENCHANT", "FUSE", "PERSONALIZE", "REFORGE", "DISASSEMBLE"]
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
		var label := String(entry.get("text", "?")) if (mode == 6 and String(host.forge_reforge_item) != "") else (String(entry.get("name", "?")) if mode == 0 else Items.label(entry))
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
	if mode == 2:
		var up_cost := Crafting.upgrade_cost(chosen)
		var up_check: Dictionary = Crafting.check(up_cost, player.inventory, Game.spirit_stones, player.cultivation.realm)
		_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(up_cost), 11, 360.0), 11, Color("#d8c070"))
		cy += 20.0
		_text(Vector2(cx, cy), _fit("Item level %d → %d · failure %d%%, and failure strains the piece." % [
			int(chosen.get("ilvl", 1)), int(chosen.get("ilvl", 1)) + 1,
			int(round(float(up_cost.get("failure_chance", 0.0)) * 100.0))], 11, 360.0), 11, Color("#7f9098"))
		cy += 32.0
		if bool(chosen.get("unique", false)):
			_text(Vector2(cx, cy), "An authored relic refuses a smith.", 11, Color("#e08f8f"))
		elif not bool(up_check.get("ok", false)):
			_text(Vector2(cx, cy), _fit("Needs %s." % String(up_check.get("reason", "more")), 11, 360.0), 11, Color("#e08f8f"))
		else:
			_text(Vector2(cx, cy), "ENTER raises it one level.", 12, ACCENT)
		return
	if mode == 3:
		var marked_id := String(host.forge_enchant_item)
		var en_check: Dictionary = Crafting.check(rules, player.inventory, Game.spirit_stones, player.cultivation.realm)
		_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(rules), 11, 360.0), 11, Color("#d8c070"))
		cy += 20.0
		if marked_id == "":
			_text(Vector2(cx, cy), _fit("Failure %d%% — the piece keeps what it had." % int(round(float(rules.get("failure_chance", 0.0)) * 100.0)), 11, 360.0), 11, Color("#7f9098"))
			cy += 32.0
			if bool(chosen.get("unique", false)):
				_text(Vector2(cx, cy), "An authored relic refuses a smith.", 11, Color("#e08f8f"))
			else:
				_text(Vector2(cx, cy), "ENTER chooses this piece, then the enchantment.", 12, ACCENT)
			return
		var marked: Dictionary = {}
		for candidate in host.gear_candidates():
			if String((candidate as Dictionary).get("id", "")) == marked_id:
				marked = candidate
				break
		var current: Dictionary = marked.get("enchant", {})
		var for_line := "For %s (item level %d)." % [String(marked.get("name", "the piece")), int(marked.get("ilvl", 1))]
		if not current.is_empty():
			for_line += " Now carries: " + String(current.get("text", ""))
		_text(Vector2(cx, cy), _fit(for_line, 11, 360.0), 11, Color("#7f9098"))
		cy += 32.0
		if not bool(en_check.get("ok", false)):
			_text(Vector2(cx, cy), _fit("Needs %s." % String(en_check.get("reason", "more")), 11, 360.0), 11, Color("#e08f8f"))
		else:
			_text(Vector2(cx, cy), "ENTER lays this enchantment.", 12, ACCENT)
		return
	if mode == 4:
		var chassis_id := String(host.forge_fuse_chassis)
		var fu_check: Dictionary = Crafting.check(rules, player.inventory, Game.spirit_stones, player.cultivation.realm)
		_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(rules), 11, 360.0), 11, Color("#d8c070"))
		cy += 20.0
		if chassis_id == "":
			_text(Vector2(cx, cy), _fit("Failure %d%% — the fed piece is lost either way." % int(round(float(rules.get("failure_chance", 0.0)) * 100.0)), 11, 360.0), 11, Color("#7f9098"))
			cy += 32.0
			if bool(chosen.get("unique", false)):
				_text(Vector2(cx, cy), "An authored relic refuses a smith.", 11, Color("#e08f8f"))
			else:
				_text(Vector2(cx, cy), "ENTER chooses the piece that will take in another.", 12, ACCENT)
			return
		var chassis: Dictionary = {}
		for candidate in host.gear_candidates():
			if String((candidate as Dictionary).get("id", "")) == chassis_id:
				chassis = candidate
				break
		_text(Vector2(cx, cy), _fit("Feeding into: %s. The chosen piece is consumed, win or lose." % String(chassis.get("name", "the piece")), 11, 360.0), 11, Color("#7f9098"))
		cy += 32.0
		if not bool(fu_check.get("ok", false)):
			_text(Vector2(cx, cy), _fit("Needs %s." % String(fu_check.get("reason", "more")), 11, 360.0), 11, Color("#e08f8f"))
		elif String(chosen.get("slot", "")) != String(chassis.get("slot", "")):
			_text(Vector2(cx, cy), "The two pieces must share a slot.", 11, Color("#e08f8f"))
		else:
			_text(Vector2(cx, cy), "ENTER fuses the chosen piece into it.", 12, ACCENT)
		return
	if mode == 5:
		_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(rules), 11, 360.0), 11, Color("#d8c070"))
		cy += 20.0
		_text(Vector2(cx, cy), _fit(String(rules.get("desc", "")), 11, 360.0), 11, Color("#7f9098"))
		cy += 32.0
		if bool(chosen.get("unique", false)):
			_text(Vector2(cx, cy), "An authored relic already carries its name.", 11, Color("#e08f8f"))
		else:
			_text(Vector2(cx, cy), "ENTER names this piece.", 12, ACCENT)
		return
	if mode == 6:
		var reforge_id := String(host.forge_reforge_item)
		var rf_check: Dictionary = Crafting.check(rules, player.inventory, Game.spirit_stones, player.cultivation.realm)
		_text(Vector2(cx, cy), _fit("Costs: " + Crafting.requirement_text(rules), 11, 360.0), 11, Color("#d8c070"))
		cy += 20.0
		if reforge_id == "":
			_text(Vector2(cx, cy), _fit("Failure %d%% — the affix stands." % int(round(float(rules.get("failure_chance", 0.0)) * 100.0)), 11, 360.0), 11, Color("#7f9098"))
			cy += 32.0
			if bool(chosen.get("unique", false)):
				_text(Vector2(cx, cy), "An authored relic refuses a smith.", 11, Color("#e08f8f"))
			else:
				_text(Vector2(cx, cy), "ENTER chooses this piece, then the affix.", 12, ACCENT)
			return
		var reforge_host: Dictionary = {}
		for candidate in host.gear_candidates():
			if String((candidate as Dictionary).get("id", "")) == reforge_id:
				reforge_host = candidate
				break
		_text(Vector2(cx, cy), _fit("On %s: this one affix is struck out and rolled anew." % String(reforge_host.get("name", "the piece")), 11, 360.0), 11, Color("#7f9098"))
		cy += 32.0
		if not bool(rf_check.get("ok", false)):
			_text(Vector2(cx, cy), _fit("Needs %s." % String(rf_check.get("reason", "more")), 11, 360.0), 11, Color("#e08f8f"))
		else:
			_text(Vector2(cx, cy), "ENTER reforges this affix.", 12, ACCENT)
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
	UiFrame.page(self, panel, Color("#0b1014", 0.97), Color("#8fd8a0", 0.45))
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
	UiFrame.page(self, Rect2(x - 12.0, y - 22.0, width, 302.0), PANEL_BG, Color("#5f7f8c", 0.45))
	_text(Vector2(x, y), _fit("%s — %s" % [npc.display_name, npc.role], 15, 408.0), 15, ACCENT)
	y += 20.0
	var sect_part := ""
	if String(npc.sect_id) != "":
		sect_part = " · " + String(npc.sect_id)
	var realm_name := String(DB.realm(npc.realm).get("name", "Realm %d" % npc.realm))
	_text(Vector2(x, y), _fit("Realm %d — %s%s · nerve %s" % [
		npc.realm, realm_name, sect_part, npc.nerve_label()], 11, 408.0), 11, MUTED)
	y += 17.0
	# Where the person stands on the ladder and how close the next rung is. This
	# is derived from the seed and the day, not saved.
	var cultivation := npc.progress_line()
	if cultivation != "":
		_text(Vector2(x, y), _fit(cultivation, 11, 408.0), 11, Color("#a8d8c0"))
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
	# Which house this body answers to, and how that house currently reads the
	# player: a guard's welcome is not only personal.
	var faction := npc.faction_line()
	if faction != "":
		_text(Vector2(x, y), _fit(faction, 11, 408.0), 11, Color("#c8b8e8"))
		y += 16.0
	# The seat in the hall, which is a different question from the house's regard.
	var station := npc.rank_line()
	if station != "":
		_text(Vector2(x, y), _fit(station, 11, 408.0), 11, Color("#d8c898"))
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
	UiFrame.page(self, panel, Color("#0b1014", 0.97), Color("#c8b070", 0.45))
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
	UiFrame.plaque(self, Rect2(pos, Vector2(width, 28.0)), Color("#0d1216", 0.85), Color("#7fd3e0", 0.5))
	_text(pos + Vector2(14.0, 19.0), prompt, 14, INK)


func draw_realm_banner() -> void:
	if String(host.phase) != "realm":
		return
	var realm_name := "Hidden realm"
	if host.realm_instance != null and is_instance_valid(host.realm_instance):
		realm_name = String(host.realm_instance.realm_name)
	var text := "HIDDEN REALM — %s" % realm_name
	var width := _text_width(text, 16) + 28.0
	var pos := Vector2(size.x * 0.5 - width * 0.5, 22.0)
	draw_rect(Rect2(pos, Vector2(width, 28.0)), Color("#241a38", 0.85))
	_text(pos + Vector2(14.0, 19.0), text, 16, Color("#c8b8ff"))


## The altar trial is a live countdown, not a toast the player has to remember.
func draw_inheritance_trial() -> void:
	var text: String = host.inheritance_trial_line()
	if text == "":
		return
	var width := _text_width(text, 15) + 28.0
	var pos := Vector2(size.x * 0.5 - width * 0.5, 56.0)
	UiFrame.plaque(self, Rect2(pos, Vector2(width, 28.0)), Color("#18140f", 0.88), Color("#e0c060", 0.7), 1.5)
	_text(pos + Vector2(14.0, 19.0), text, 15, Color("#f0d890"))


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
	UiFrame.plaque(self, Rect2(pos, Vector2(width, 30.0)), Color("#120d18", 0.85), Color(color, 0.7), 1.5)
	_text(pos + Vector2(16.0, 20.0), text, 16, color)


func draw_toasts() -> void:
	# Clear of the skill bar and the help block, which own the bottom band.
	var y := size.y - 248.0
	var x := size.x * 0.5
	for toast in _toasts:
		var alpha := clampf(float(toast["ttl"]), 0.0, 1.0)
		var text := String(toast["text"])
		var width := _text_width(text, 13)
		UiFrame.plaque(self, Rect2(x - width * 0.5 - 10.0, y - 13.0, width + 20.0, 18.0),
			Color(PANEL_BG, alpha * 0.9), Color(UiFrame.BRONZE_DIM, alpha))
		_text(Vector2(x - width * 0.5, y), text, 13, Color(INK, alpha))
		y -= 19.0


func draw_help() -> void:
	var lines := "WASD move · SHIFT sprint · LMB technique · RMB weapon strike · CTRL guard · SPACE dodge · F meditate · G tribulation · E interact · P party · H bind · L captives · J chronicle · K standings · Y sects · N ranks · O ledger · 7 council · 0 sect · . stories · , archive · Z blank page · C sheet · X settings · 1-6 slot · Q cycle · [ ] bar · B bars · I satchel (U drinks a pill) · M map · 8 save · 9 load · ` mute · ? hide"
	var trade := "At a merchant: 1-6 buy/sell · TAB switch · E close · T travel · M map"
	var pad := "Gamepad: left stick move · right stick aim · X attack · LS click guard · A dodge · B interact · Y meditate · RB sprint · LB shop · DPAD travel/waypoint"
	# The skill bar owns the bottom 120 px. Help lives above it, wrapped to the
	# window, instead of being drawn through the bar and each other.
	var rows: Array[String] = []
	for text in [lines, pad, trade]:
		for row in _wrapped(String(text), 10, size.x - 48.0):
			rows.append(String(row))
	var row_height := 14.0
	var top := size.y - 152.0 - row_height * float(rows.size())
	UiFrame.panel(self, Rect2(12.0, top - 12.0, size.x - 24.0, row_height * float(rows.size()) + 18.0),
		Color("#070b0d", 0.55))
	for i in rows.size():
		var colour := Color("#7b8b94") if i < rows.size() - 2 else Color("#6b7b84")
		_text(Vector2(24.0, top + row_height * float(i) + 10.0), rows[i], 10, colour)


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


const MM_RADIUS := 76.0
const MM_RANGE := 950.0
var _mm_colours: Dictionary = {}


func _minimap_center() -> Vector2:
	return Vector2(size.x - MM_RADIUS - 22.0, size.y - MM_RADIUS - 22.0)


## The minimap, bottom-right: the streamed ground sampled tile by tile,
## herbs and sites from the chunk payloads, the people of the world as
## dots, and the chosen waypoint in gold. Everything on it is read live
## from the same data the world itself is built from.
func draw_minimap(player: Player) -> void:
	if host == null:
		return
	var manager: Object = host.get("chunks")
	if manager == null:
		return
	var chunks: Dictionary = manager.get("chunks")
	var centre := _minimap_center()
	draw_circle(centre, MM_RADIUS + 6.0, Color("#05070a", 0.60))
	var step := 64.0
	var px := step / MM_RANGE * MM_RADIUS + 0.6
	for wy in range(-int(MM_RANGE), int(MM_RANGE) + 1, int(step)):
		for wx in range(-int(MM_RANGE), int(MM_RANGE) + 1, int(step)):
			var off := Vector2(float(wx), float(wy))
			if off.length() > MM_RANGE - step * 0.5:
				continue
			var colour := _mm_ground_colour(chunks, player.global_position + off)
			if colour.a <= 0.0:
				continue
			var at := centre + off / MM_RANGE * MM_RADIUS
			draw_rect(Rect2(at - Vector2(px, px) * 0.5, Vector2(px, px)), colour)
	for coord in chunks.keys():
		var chunk := chunks[coord] as Node2D
		if chunk == null:
			continue
		var origin := chunk.global_position
		for herb in chunk.get("herbs"):
			var at: Variant = _mm_point(centre, player.global_position,
				origin + Vector2((herb as Dictionary).get("pos", Vector2.ZERO)))
			if at != null:
				draw_circle(at, 1.6, Color("#7fd8a0"))
		for poi in chunk.get("pois"):
			var at: Variant = _mm_point(centre, player.global_position,
				origin + Vector2((poi as Dictionary).get("pos", Vector2.ZERO)))
			if at != null:
				_mm_diamond(at, 3.0, UiFrame.BRONZE)
	var npcs: Array = host.get("npcs")
	for npc in npcs:
		var body := npc as Node2D
		if body == null or not is_instance_valid(body):
			continue
		var at: Variant = _mm_point(centre, player.global_position, body.global_position)
		if at != null:
			draw_circle(at, 2.6, Color("#9fe0c0"))
			draw_arc(at, 2.6, 0.0, TAU, 12, Color("#0c1410", 0.8), 1.0)
	for body in get_tree().get_nodes_in_group("enemy"):
		var node := body as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var at: Variant = _mm_point(centre, player.global_position, node.global_position)
		if at != null:
			draw_circle(at, 2.6, Color("#e0584c"))
	var target: Vector2 = host.waypoint_position
	if target != Vector2.ZERO:
		var rel := target - player.global_position
		if rel.length() > MM_RANGE:
			rel = rel.normalized() * (MM_RANGE - 26.0)
		_mm_diamond(centre + rel / MM_RANGE * MM_RADIUS, 3.6, Color("#ffd97f"))
	var facing: Vector2 = player.facing_direction()
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN
	var dir := facing.normalized()
	var side := dir.orthogonal()
	var tri := PackedVector2Array([
		centre + dir * 7.0, centre - dir * 5.0 + side * 4.0, centre - dir * 5.0 - side * 4.0])
	draw_colored_polygon(tri, Color("#ffe9b0"))
	draw_arc(centre, MM_RADIUS + 2.0, 0.0, TAU, 72, UiFrame.BRONZE_DIM, 2.0)
	draw_arc(centre, MM_RADIUS + 5.0, -2.6, -1.2, 16, UiFrame.BRONZE, 1.5)
	_text_centred(centre + Vector2(0.0, -MM_RADIUS - 9.0), "N", 9, MUTED)


## A world position on the minimap, or null when it lies beyond the rim.
func _mm_point(centre: Vector2, origin: Vector2, world_pos: Vector2) -> Variant:
	var rel := world_pos - origin
	if rel.length() > MM_RANGE:
		return null
	return centre + rel / MM_RANGE * MM_RADIUS


func _mm_diamond(at: Vector2, r: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), colour)


## The ground colour under a world position: the average of the actual
## tile painted there, cached per tileset source, with the chunk's own
## palette as the fallback when tiles are off.
func _mm_ground_colour(chunks: Dictionary, world_pos: Vector2) -> Color:
	var coord := Vector2i(floori(world_pos.x / 1024.0), floori(world_pos.y / 1024.0))
	var chunk := chunks.get(coord) as Node2D
	if chunk == null:
		return Color(0, 0, 0, 0)
	var layer := chunk.get_node_or_null("GroundTiles") as TileMapLayer
	if layer != null and layer.tile_set != null:
		var cell := layer.local_to_map(layer.to_local(world_pos))
		var source := layer.get_cell_source_id(cell)
		if source >= 0:
			return _mm_source_colour(layer.tile_set, source)
	var palette: Array = chunk.get("palette")
	if palette != null and not palette.is_empty():
		return Color(palette[0], 0.9)
	return Color("#22301f", 0.9)


func _mm_source_colour(tile_set: TileSet, source_id: int) -> Color:
	var key := "%d:%d" % [tile_set.get_instance_id(), source_id]
	if _mm_colours.has(key):
		return _mm_colours[key]
	var colour := Color("#2c3a2a")
	var source := tile_set.get_source(source_id) as TileSetAtlasSource
	if source != null and source.texture != null:
		var image := source.texture.get_image()
		if image != null and image.get_width() > 0:
			image = image.duplicate()
			image.resize(8, 8, Image.INTERPOLATE_BILINEAR)
			var sum := Vector3.ZERO
			var n := 0
			for yy in range(8):
				for xx in range(8):
					var pxl := image.get_pixel(xx, yy)
					if pxl.a > 0.1:
						sum += Vector3(pxl.r, pxl.g, pxl.b)
						n += 1
			if n > 0:
				sum /= float(n)
				colour = Color(sum.x * 0.92, sum.y * 0.92, sum.z * 0.92)
	colour.a = 0.92
	_mm_colours[key] = colour
	return colour


## The door, drawn beside the minimap: one plaque that opens the menu.
func menu_button_rect() -> Rect2:
	var centre := _minimap_center()
	return Rect2(centre.x - MM_RADIUS - 98.0, size.y - 46.0, 86.0, 30.0)


func draw_menu_button() -> void:
	var rect := menu_button_rect()
	var open := host != null and bool(host.get("menu_open"))
	UiFrame.plaque(self, rect, Color(PANEL_BG, 0.92), UiFrame.BRONZE if open else UiFrame.BRONZE_DIM)
	_text_centred(rect.get_center() + Vector2(0.0, 1.0), "MENU", 11, ACCENT if open else INK)
	_text_centred(rect.get_center() + Vector2(0.0, 12.0), "Esc", 8, MUTED)


## The menu itself: every system behind one door, grouped the way the
## systems group themselves, each row carrying the key that also opens
## it directly. The key help lives at its foot, where it is looked for.
func draw_menu() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Color("#05080a", 0.9))
	var _pr := _page_rect(720.0, 660.0)
	var w := _pr.size.x
	var h := _pr.size.y
	var x := _pr.position.x
	var y := _pr.position.y
	UiFrame.page(self, Rect2(x, y, w, h), Color("#0c1012", 0.98), Color("#9fe0c0", 0.42))
	_text(Vector2(x + 28.0, y + 42.0), "MENU", 24, ACCENT)
	_text(Vector2(x + 28.0, y + 64.0), "Every system behind one door.  Up / Down choose, Enter opens, Esc closes.", 12, MUTED)
	_text(Vector2(x + w - 118.0, y + 42.0), "Esc — close", 11, MUTED)
	var entries: Array = host.menu_entries()
	var selected := int(host.get("menu_index"))
	var ry := y + 88.0
	var seen := -1
	for entry in entries:
		var row: Dictionary = entry
		if row.has("header"):
			_text(Vector2(x + 28.0, ry + 12.0), String(row["header"]), 11, Color("#c8a860"))
			UiFrame.divider(self, x + 118.0, x + w - 28.0, ry + 8.0)
			ry += 24.0
			continue
		seen += 1
		var rect := Rect2(x + 24.0, ry, w - 48.0, 24.0)
		if seen == selected:
			UiFrame.plaque(self, rect, Color(ACCENT, 0.10), UiFrame.BRONZE)
		_text(Vector2(x + 40.0, ry + 16.0), String(row.get("label", "")), 13,
			INK if seen == selected else Color("#c3ced4"))
		var key := String(row.get("key", ""))
		if key != "":
			var kw := _text_width(key, 10)
			UiFrame.plaque(self, Rect2(x + w - 44.0 - kw - 14.0, ry + 3.0, kw + 14.0, 18.0),
				Color("#10161a", 0.9), UiFrame.BRONZE_DIM)
			_text(Vector2(x + w - 44.0 - kw - 7.0, ry + 16.0), key, 10, Color("#d8c070"))
		ry += 24.0
	_text(Vector2(x + 28.0, y + h - 38.0),
		"8 save · 9 load · ` mute · ? key help · E interact · Space dodge · Shift sprint · LMB art · RMB guard", 10, MUTED)
	_text(Vector2(x + 28.0, y + h - 20.0),
		"Merchants, forges, storage and roads open their own pages where you find them.", 10, MUTED)


## While the player cultivates, the way back out is written on screen.
func draw_cultivating(player: Player) -> void:
	if not player.is_meditating():
		return
	var label := "CULTIVATING"
	var hint := " — F to stop · step to rise"
	var w := _text_width(label, 11) + _text_width(hint, 11) + 24.0
	var rect := Rect2(16.0, 118.0, w, 26.0)
	UiFrame.plaque(self, rect, Color("#0d1216", 0.92), UiFrame.BRONZE)
	_text(rect.position + Vector2(12.0, 17.0), label, 11, ACCENT)
	_text(rect.position + Vector2(12.0 + _text_width(label, 11), 17.0), hint, 11, INK)


## The settings page's tab chips, shared by its draw and its hit tests.
func settings_tab_rect(i: int) -> Rect2:
	var rect := _page_rect(1000.0, 600.0)
	return Rect2(rect.position.x + 24.0 + float(i) * 150.0, rect.position.y + 68.0, 132.0, 24.0)


## The settings row under `pos`, mirroring draw_settings' window, or -1.
func settings_row_at(pos: Vector2) -> int:
	if host == null:
		return -1
	var rect := _page_rect(1000.0, 600.0)
	var rows: Array = host.settings_rows()
	if rows.is_empty():
		return -1
	var cursor := clampi(int(host.get("settings_index")), 0, rows.size() - 1)
	var first := maxi(0, cursor - 11)
	for i in range(first, mini(rows.size(), first + 12)):
		var row_rect := Rect2(rect.position.x + 18.0,
			rect.position.y + 116.0 + float(i - first) * 30.0 - 14.0, 520.0, 30.0)
		if row_rect.has_point(pos):
			return i
	return -1


# ---------------------------------------------------------------- mouse ----
## The mouse, alongside the keys. Hover highlights, the wheel walks the
## open list, a click chooses — and in the world, the MENU plaque and the
## skill bar answer a click. Only events the HUD actually uses are
## accepted; everything else falls through to the game untouched.

const LIST_PAGES := {
	"ledger": {"open": "sect_ledger_open", "index": "sect_ledger_index", "rows": "sect_ledger_rows",
		"activate": "_sect_ledger_activate", "size": Vector2(820.0, 500.0), "top": 112.0,
		"step": 50.0, "off": -14.0, "height": 44.0, "width": -36.0},
	"council": {"open": "council_open", "index": "council_index", "rows": "council_rows",
		"activate": "_council_activate", "size": Vector2(860.0, 520.0), "top": 112.0,
		"step": 68.0, "off": -14.0, "height": 60.0, "width": -36.0},
	"sect_seat": {"open": "sect_seat_open", "index": "sect_seat_index", "rows": "sect_seat_rows",
		"activate": "_sect_seat_activate", "size": Vector2(860.0, 540.0), "top": 112.0,
		"step": 50.0, "off": -14.0, "height": 44.0, "width": -36.0},
	"player_sect": {"open": "player_sect_open", "index": "player_sect_index", "rows": "player_sect_rows",
		"activate": "_player_sect_activate", "size": Vector2(880.0, 560.0), "top": 112.0,
		"step": 52.0, "off": -14.0, "height": 48.0, "width": 520.0},
	"storylines": {"open": "storylines_open", "index": "storyline_index", "rows": "storyline_rows",
		"activate": "_storylines_activate", "size": Vector2(1040.0, 652.0), "top": 112.0,
		"step": 36.0, "off": -13.0, "height": 34.0, "width": -36.0},
}


func menu_panel_rect() -> Rect2:
	return _page_rect(720.0, 660.0)


## The selectable menu row under `pos`, or -1. Mirrors draw_menu's layout.
func menu_hit(pos: Vector2) -> int:
	if host == null:
		return -1
	var rect := menu_panel_rect()
	var entries: Array = host.menu_entries()
	var ry := rect.position.y + 88.0
	var seen := -1
	for entry in entries:
		var row: Dictionary = entry
		if row.has("header"):
			ry += 24.0
			continue
		seen += 1
		if Rect2(rect.position.x + 24.0, ry, rect.size.x - 48.0, 24.0).has_point(pos):
			return seen
		ry += 24.0
	return -1


## A row of a list page under `pos`, or -1. Mirrors the page's own draw.
func _list_hit(page_key: String, pos: Vector2) -> int:
	var cfg: Dictionary = LIST_PAGES[page_key]
	var rows: Array = host.call(String(cfg["rows"]))
	var rect := _page_rect((cfg["size"] as Vector2).x, (cfg["size"] as Vector2).y)
	var width := float(cfg["width"])
	if width < 0.0:
		width = rect.size.x + width
	for i in rows.size():
		var row_rect := Rect2(rect.position.x + 18.0,
			rect.position.y + float(cfg["top"]) + float(i) * float(cfg["step"]) + float(cfg["off"]),
			width, float(cfg["height"]))
		if row_rect.has_point(pos):
			return i
	return -1


## The HUD skill slot under `pos`, or -1. Mirrors draw_techniques.
func technique_slot_at(pos: Vector2) -> int:
	for i in range(6):
		if Rect2(Vector2(24.0 + float(i) * 118.0, size.y - 94.0), Vector2(112.0, 46.0)).has_point(pos):
			return i
	return -1


func _any_page_open() -> bool:
	if host == null:
		return false
	for flag in ["character_open", "settings_open", "gear_open", "shop_open", "travel_open",
			"bars_open", "storage_open", "forge_open", "alchemy_open", "factions_open",
			"sects_open", "hierarchy_open", "sect_ledger_open", "council_open", "sect_seat_open",
			"player_sect_open", "storylines_open", "narrative_open", "endgame_open",
			"captives_open", "chronicle_open"]:
		if bool(host.get(flag)):
			return true
	var wm: Object = host.get("world_map")
	return wm != null and bool(wm.get("visible"))


func _gui_input(event: InputEvent) -> void:
	if host == null or String(host.get("phase")) != "play":
		return
	if event is InputEventMouseMotion:
		if bool(host.get("menu_open")):
			var hovered := menu_hit((event as InputEventMouseMotion).position)
			if hovered >= 0 and hovered != int(host.get("menu_index")):
				host.set("menu_index", hovered)
				queue_redraw()
		return
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var button := (event as InputEventMouseButton).button_index
	var pos := (event as InputEventMouseButton).position
	if button == MOUSE_BUTTON_WHEEL_DOWN or button == MOUSE_BUTTON_WHEEL_UP:
		var dir := 1 if button == MOUSE_BUTTON_WHEEL_DOWN else -1
		if bool(host.get("menu_open")):
			host.set("menu_index", clampi(int(host.get("menu_index")) + dir, 0, host.menu_selectable_count() - 1))
			queue_redraw()
			accept_event()
			return
		if bool(host.get("settings_open")):
			if String(host.get("settings_rebind_action")) == "":
				var srows: Array = host.settings_rows()
				if not srows.is_empty():
					host.set("settings_index", clampi(int(host.get("settings_index")) + dir, 0, srows.size() - 1))
					queue_redraw()
			accept_event()
			return
		for page_key in LIST_PAGES.keys():
			var cfg: Dictionary = LIST_PAGES[page_key]
			if bool(host.get(String(cfg["open"]))):
				var rows: Array = host.call(String(cfg["rows"]))
				if not rows.is_empty():
					host.set(String(cfg["index"]), clampi(int(host.get(String(cfg["index"]))) + dir, 0, rows.size() - 1))
					queue_redraw()
				accept_event()
				return
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if bool(host.get("menu_open")):
		var idx := menu_hit(pos)
		if idx >= 0:
			host.set("menu_index", idx)
			host._menu_activate()
		elif not menu_panel_rect().has_point(pos):
			host._close_menu()
		accept_event()
		return
	if bool(host.get("settings_open")):
		if String(host.get("settings_rebind_action")) == "":
			for i in range(2):
				if settings_tab_rect(i).has_point(pos):
					if int(host.get("settings_tab")) != i:
						host.set("settings_tab", i)
						host.set("settings_index", 0)
						queue_redraw()
					accept_event()
					return
			var srow := settings_row_at(pos)
			if srow >= 0:
				if srow == int(host.get("settings_index")):
					host._settings_activate(srow)
				else:
					host.set("settings_index", srow)
					queue_redraw()
				accept_event()
		return
	for page_key in LIST_PAGES.keys():
		var cfg: Dictionary = LIST_PAGES[page_key]
		if bool(host.get(String(cfg["open"]))):
			var row := _list_hit(page_key, pos)
			if row >= 0:
				if row == int(host.get(String(cfg["index"]))):
					host.call(String(cfg["activate"]), row)
				else:
					host.set(String(cfg["index"]), row)
					queue_redraw()
				accept_event()
			return
	if _any_page_open():
		return
	if menu_button_rect().has_point(pos):
		host._open_menu()
		accept_event()
		return
	if technique_slot_at(pos) >= 0:
		host.toggle_bars()
		accept_event()
		return
