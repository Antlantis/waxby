extends SceneTree
## What the phone build needs that the Mac hides (contract.md §1, §15):
##   - every .txt and .json the game reads at run time (everything under game/
##     but tests/) matches export_presets.cfg's include_filter, taking "*" not
##     to cross "/" (the levels/*/*.txt trap: the Descent's rooms);
##   - level ids are exact, case and all: every registry entry's file is named
##     byte for byte as its id (the iOS PCK is case-sensitive, the Mac isn't);
##   - every script under scripts/ parses (a file that fails to parse fails);
##   - the v2 level files nobody retrofits are still v2's, byte for byte, but
##     for the signs the sign cut took, until Build 2 redraws one (a level
##     that declares its own cast, roster:, is held to that instead);
##   - no draw_circle / draw_colored_polygon / draw_polyline in the v3 drawing
##     code (feature modules, painters, backdrop styles, ambient, edge lines);
##   - both iOS presets open Documents to the Files app (the playlog), and the
##     App Store one carries a TestFlight build number past the first.
##   - Build 5's release pass: the one switch (tools/store_preset.py, which
##     tools/ios_release.sh --store runs) turns the App Store preset's Files
##     access, file sharing and "playtest" file log off and changes nothing
##     else; file logging is off in a release build without "playtest"; the
##     plist extras repeat nothing the template writes; no empty usage
##     string; the launch screen is Waxby's dark (no Godot logo: a blank
##     image on the title's colour, the boot splash's image off, the same
##     colour); the App Store build is iPhone-only, build 5 or later, and
##     leaves the lab levels out; the sound is an Ambient session (the Silent
##     switch); the version the game shows is the preset's.
##
##     godot --headless --path game --script res://tests/test_export.gd

const PRESETS := "res://export_presets.cfg"
# sha256 of the v2 level files that stay as v2 wrote them, less the signs
# the sign cut took (their '@' to '.', their hints gone or reworded; 1-4's
# one sign stays): the two bosses. Build 2 re-cut the six regular levels of
# Worlds 1-2 (tools/levels/w1.py, w2.py: their shapes, rosters and twists),
# so they left this table; test_core, test_content and tests/level_rules.gd
# hold them to their own roster:, threat:, roles: and shape now.
const V2_SHA := {
	"1-4": "a720f34fa5c98dfa8d5eea6d8de9f3f50449627df4293a02e0b2c83e86e29162",
	"2-4": "c419ee42c070ef3f531b6e91e2ad0817b7903e763cde08a21657e746fb1e5d02",
}
const NO_POLY_DIRS := ["res://scripts/features", "res://scripts/tiles", "res://scripts/backdrops"]
const NO_POLY_FILES := ["res://scripts/ambient.gd", "res://scripts/edge_lines.gd"]

var _passed := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_filters()
	_test_ids()
	_test_scripts()
	_test_v2_levels()
	_test_no_polys()
	_test_files_app()
	_test_release()
	print("test_export: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _filters(key: String) -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS) != OK:
		return []
	var out := []
	for part in str(cfg.get_value("preset.0", key, "")).split(","):
		var f := part.strip_edges()
		if f != "":
			out.append(f)
	return out


static func glob(path: String, pattern: String) -> bool:
	## pattern's "*" matches within one path segment only (never "/").
	var ps := path.split("/")
	var qs := pattern.split("/")
	if ps.size() != qs.size():
		return false
	for i in ps.size():
		if not ps[i].match(qs[i]):
			return false
	return true


func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		_walk(dir.path_join(sub), out)


func _test_filters() -> void:
	var inc := _filters("include_filter")
	_check(inc.has("levels/*/*.txt"), "the include filter has levels/*/*.txt (the modes' rooms)")
	var files := []
	_walk("res://", files)
	var n := 0
	for f in files:
		var rel := str(f).trim_prefix("res://")
		if rel.begins_with("/"):
			rel = rel.substr(1)
		if not (rel.ends_with(".txt") or rel.ends_with(".json")) or rel.begins_with("tests/") or rel.begins_with(".godot/"):
			continue
		n += 1
		var ok := false
		for pat in inc:
			if glob(rel, pat):
				ok = true
				break
		_check(ok, "%s is in the export (include_filter)" % rel)
	print("  %d data files checked against the include filter" % n)
	# The saves the tests read (tests/fixtures: v1_save, v2_save, and the
	# owner's own two slots, byte copies from his phone) must never ship.
	var exc := _filters("exclude_filter")
	_check(exc.has("tests/*"), "the exclude filter has tests/* (the save fixtures stay out)")
	var fx := 0
	for f in files:
		var rel := str(f).trim_prefix("res://")
		if rel.begins_with("/"):
			rel = rel.substr(1)
		if not rel.begins_with("tests/fixtures/"):
			continue
		fx += 1
		# Godot's own filters let "*" cross "/": exclusion is tested that way,
		# and the include filter both ways.
		var inc_hit := false
		for pat in inc:
			if glob(rel, pat) or rel.match(str(pat)):
				inc_hit = true
		var exc_hit := false
		for pat in exc:
			if rel.match(str(pat)):
				exc_hit = true
		_check(not inc_hit and exc_hit, "%s stays out of the export" % rel)
	_check(fx >= 1, "the save fixtures are there to check (%d)" % fx)


func _registry() -> Array:
	var g = root.get_node_or_null("Game")
	var out := []
	if g == null:
		return out
	var consts: Dictionary = (g.get_script() as Script).get_script_constant_map()
	for key in ["ALL_LEVELS", "SECRET_LEVELS"]:
		var reg = consts.get(key, g.get(key))
		if reg is Array:
			out.append_array(reg)
	return out


func _test_ids() -> void:
	var names := {}
	for f in DirAccess.get_files_at("res://levels"):
		names[f] = true
	for info in _registry():
		var id := str(info.get("id", ""))
		var path := str(info.get("path", ""))
		_check(path == "res://levels/%s.txt" % id, "%s's path is res://levels/%s.txt (%s)" % [id, id, path])
		if FileAccess.file_exists(path):
			_check(names.has("%s.txt" % id), "the file for %s is named exactly %s.txt (case and all)" % [id, id])
	for f in names:
		if not str(f).ends_with(".txt"):
			continue
		var base := str(f).get_basename()
		_check(base == base.strip_edges() and not base.contains(" "), "level file %s has no stray spaces" % f)
		if base.length() == 3 and base[1] == "-":
			_check(base[2] == "S" or base[2].is_valid_int(), "%s: a secret level's id ends in a capital S" % f)


func _test_scripts() -> void:
	var files := []
	_walk("res://scripts", files)
	var n := 0
	for f in files:
		if not str(f).ends_with(".gd"):
			continue
		n += 1
		var s = load(f)
		_check(s != null and (s as Script).can_instantiate(), "%s parses" % f)
	print("  %d scripts parse" % n)


func _test_v2_levels() -> void:
	var LevelData = load("res://scripts/level_data.gd")
	for id in V2_SHA:
		var path := "res://levels/%s.txt" % id
		if LevelData.load_file(path).headers.has("roster"):
			# Build 2 redrew it: test_w* and tests/level_rules.gd hold it to
			# its own roster: and threat: now, not to v2's bytes.
			print("  %s declares its roster (Build 2): no longer v2's, so not pinned" % id)
			continue
		var sha := FileAccess.get_sha256(path)
		_check(sha == V2_SHA[id], "%s is still v2's, byte for byte" % id)


func _test_no_polys() -> void:
	var files := []
	for d in NO_POLY_DIRS:
		_walk(d, files)
	for f in NO_POLY_FILES:
		if FileAccess.file_exists(f):
			files.append(f)
	var rx := RegEx.create_from_string("\\b(draw_circle|draw_colored_polygon|draw_polyline)\\s*\\(")
	for f in files:
		if not str(f).ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(f)
		var hits := []
		var ln := 0
		for line in text.split("\n"):
			ln += 1
			var code := line.split("#")[0] if not line.strip_edges().begins_with("##") else ""
			if rx.search(code) != null:
				hits.append(ln)
		_check(hits.is_empty(), "%s draws no circles or polygons directly (lines %s)" % [f, hits])


func _test_files_app() -> void:
	## Documents (playlog.json, the saves) shows in the Files app on every
	## build, TestFlight's too: Godot's own user_data options fill the
	## template's LSSupportsOpeningDocumentsInPlace and UIFileSharingEnabled
	## (the template always writes both, so the plist extras mustn't repeat
	## them as false).
	var cfg := ConfigFile.new()
	_check(cfg.load(PRESETS) == OK, "export_presets.cfg loads")
	var store := ""
	for sec in cfg.get_sections():
		if not (sec.begins_with("preset.") and sec.count(".") == 1) or str(cfg.get_value(sec, "platform", "")) != "iOS":
			continue
		var pname := str(cfg.get_value(sec, "name", ""))
		var o := sec + ".options"
		_check(bool(cfg.get_value(o, "user_data/accessible_from_files_app", false)), "%s: Documents opens in place (Files app)" % pname)
		_check(bool(cfg.get_value(o, "user_data/accessible_from_itunes_sharing", false)), "%s: file sharing is on" % pname)
		var extra := str(cfg.get_value(o, "application/additional_plist_content", ""))
		for key in ["UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace"]:
			_check(not extra.contains(key), "%s: the plist extras leave %s to the option" % [pname, key])
		if pname == "iOS App Store":
			store = o
	_check(store != "", "there is an iOS App Store preset")
	var ver := str(cfg.get_value(store, "application/version", "")) if store != "" else ""
	_check(ver.is_valid_int() and int(ver) >= 5, "the App Store build number is build 5's or later (%s)" % ver)


# ---------------------------------------------------------------- build 5's release pass

const TEMPLATE_KEYS := ["ITSAppUsesNonExemptEncryption", "CADisableMinimumFrameDurationOnPhone", "UIFileSharingEnabled",
		"LSSupportsOpeningDocumentsInPlace", "UILaunchStoryboardName", "UIRequiredDeviceCapabilities"]
const LAB_EXCLUDES := ["levels/lab-*", "levels/tall/*"]


func _presets() -> Dictionary:
	## {preset name: [its section, the ConfigFile]}.
	var cfg := ConfigFile.new()
	cfg.load(PRESETS)
	var out := {}
	for sec in cfg.get_sections():
		if sec.begins_with("preset.") and sec.count(".") == 1:
			out[str(cfg.get_value(sec, "name", ""))] = sec
	return {"cfg": cfg, "by_name": out}


func _test_release() -> void:
	var p := _presets()
	var cfg: ConfigFile = p["cfg"]
	var by_name: Dictionary = p["by_name"]
	_check(by_name.has("iOS") and by_name.has("iOS App Store"), "both iOS presets are there")
	if not (by_name.has("iOS") and by_name.has("iOS App Store")):
		return
	var store: String = by_name["iOS App Store"]
	var so := store + ".options"
	for pname in by_name:
		var sec: String = by_name[pname]
		var o := sec + ".options"
		# The template already writes these: the extras mustn't say them twice.
		var extra := str(cfg.get_value(o, "application/additional_plist_content", ""))
		for key in TEMPLATE_KEYS:
			_check(not extra.contains(key), "%s: the plist extras don't repeat %s" % [pname, key])
		for k in ["camera", "microphone", "photolibrary"]:
			_check(str(cfg.get_value(o, "privacy/%s_usage_description" % k, "")).strip_edges() != "", "%s: the %s usage string isn't empty" % [pname, k])
		# The launch screen: a blank image on the title's dark, never Godot's logo.
		for sc in ["@2x", "@3x"]:
			var img := str(cfg.get_value(o, "storyboard/custom_image" + sc, ""))
			_check(img != "" and FileAccess.file_exists(img), "%s: the launch screen's %s image is Waxby's own (%s)" % [pname, sc, img])
			var im := Image.new()
			var blank := img != "" and FileAccess.file_exists(img) and im.load_png_from_buffer(FileAccess.get_file_as_bytes(img)) == OK
			if blank:
				for y in im.get_height():
					for x in im.get_width():
						blank = blank and im.get_pixel(x, y).a < 0.01
			_check(blank, "%s: it's see-through: the launch screen is its background colour alone" % pname)
		_check(bool(cfg.get_value(o, "storyboard/use_custom_bg_color", false)) and (cfg.get_value(o, "storyboard/custom_bg_color", Color.WHITE) as Color).is_equal_approx(Color("0e0a14")),
				"%s: the launch screen is the title's dark (0e0a14)" % pname)
		_check(str(cfg.get_value(sec, "custom_features", "")).split(",").has("playtest"), "%s: a playtest build (its file log on)" % pname)
		_check(str(cfg.get_value(sec, "exclude_filter", "")).contains("override.cfg"), "%s: a worktree's override.cfg never ships" % pname)
	# Godot's boot splash: no image, the same dark.
	_check(ProjectSettings.get_setting("application/boot_splash/show_image", true) == false, "the boot splash shows no image (no Godot logo)")
	_check((ProjectSettings.get_setting("application/boot_splash/bg_color", Color.WHITE) as Color).is_equal_approx(Color("0e0a14")), "and the title's dark behind it")
	# The App Store build: iPhone only, the labs left out.
	_check(int(cfg.get_value(so, "application/targeted_device_family", -1)) == 0, "the App Store build is iPhone-only")
	var exc: Array = Array(str(cfg.get_value(store, "exclude_filter", "")).split(",")).map(func(f): return str(f).strip_edges())
	for f in LAB_EXCLUDES:
		_check(exc.has(f), "the App Store build leaves out %s" % f)
	var files := []
	_walk("res://levels", files)
	var out_n := 0
	for f in files:
		var rel := str(f).trim_prefix("res://")
		var base := rel.get_file()
		var dropped := false
		for pat in exc:
			dropped = dropped or rel.match(str(pat))
		if base.begins_with("lab-"):
			out_n += 1
			_check(dropped, "%s stays out of the App Store build" % rel)
		elif rel.ends_with(".txt"):
			_check(not dropped, "%s ships in the App Store build" % rel)
	_check(out_n >= 20, "the labs are there to leave out (%d)" % out_n)
	var dev_exc := str(cfg.get_value(by_name["iOS"], "exclude_filter", ""))
	_check(not dev_exc.contains("lab-") and not dev_exc.contains("tall"), "the debug build keeps them (the feel lab, the tall perf runs)")
	# The version the game shows is the build's.
	_check(str(ProjectSettings.get_setting("application/config/version", "")) == str(cfg.get_value(so, "application/short_version", "?")),
			"application/config/version is the App Store's version (%s)" % cfg.get_value(so, "application/short_version", "?"))
	# Sound: an Ambient session (the Silent switch silences it; the player's music mixes).
	_check(int(ProjectSettings.get_setting("audio/general/ios/session_category", -1)) == 0, "the iOS audio session is Ambient")
	# File logging: off in a release build, on with "playtest", a debug build or on a Mac.
	var plain := ConfigFile.new()
	_check(plain.load("res://project.godot") == OK, "project.godot reads")
	_check(plain.get_value("debug", "file_logging/enable_file_logging", true) == false, "file logging is off by default (a release build)")
	for feat in ["playtest", "debug", "pc"]:
		_check(plain.get_value("debug", "file_logging/enable_file_logging." + feat, false) == true, "and on with %s" % feat)
	_test_store_switch(cfg, store)


func _test_store_switch(cfg: ConfigFile, store: String) -> void:
	## tools/store_preset.py, as tools/ios_release.sh --store runs it: the App
	## Store preset's Files access, file sharing and "playtest" off; nothing
	## else changed (the build number above all), the other preset untouched.
	var game_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var repo := game_dir.get_base_dir()
	var script := repo.path_join("tools/store_preset.py")
	_check(FileAccess.file_exists(script), "tools/store_preset.py is there")
	var sh := FileAccess.get_file_as_string(repo.path_join("tools/ios_release.sh"))
	_check(sh.contains("--store") and sh.contains("store_preset.py --apply") and sh.contains("UIFileSharingEnabled"), "ios_release.sh --store runs it and checks the plist")
	var out := []
	var code := OS.execute("python3", [script, game_dir.path_join("export_presets.cfg")], out, true)
	_check(code == 0 and out.size() > 0, "store_preset.py runs (%d)" % code)
	if code != 0 or out.is_empty():
		print("  ", out)
		return
	var sub := ConfigFile.new()
	_check(sub.parse(str(out[0])) == OK, "its presets parse")
	var so := store + ".options"
	_check(sub.get_value(so, "user_data/accessible_from_files_app", true) == false and sub.get_value(so, "user_data/accessible_from_itunes_sharing", true) == false,
			"the submission's Files access and file sharing are off")
	_check(not str(sub.get_value(store, "custom_features", "playtest")).split(",").has("playtest"), "and it has no playtest feature (no file log)")
	var changed := []
	for sec in cfg.get_sections():
		for key in cfg.get_section_keys(sec):
			if (sec == so and key.begins_with("user_data/accessible_from")) or (sec == store and key == "custom_features"):
				continue
			if not sub.has_section_key(sec, key) or str(sub.get_value(sec, key)) != str(cfg.get_value(sec, key)):
				changed.append("%s/%s" % [sec, key])
	_check(changed.is_empty(), "and nothing else changes (%s)" % [changed.slice(0, 5)])
	_check(str(sub.get_value(so, "application/version", "")) == str(cfg.get_value(so, "application/version", "?")), "the same build number")
