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
##
##     godot --headless --path game --script res://tests/test_export.gd

const PRESETS := "res://export_presets.cfg"
# sha256 of the v2 level files that stay as v2 wrote them (1-3 and 2-2 get
# the secret exits' retrofits, WLS's), less the signs the sign cut took
# (their '@' to '.', their hints gone or reworded; 1-4's one sign stays).
const V2_SHA := {
	"1-1": "7a804439e3938f49b111c37d4fe3592634169987ff4cbbd80499f4fdc17b5802",
	"1-2": "26d5dd350ba41b118f5116a9d75a966e275db68f0ce2ea7a14aef2944f00f7b4",
	"1-4": "a720f34fa5c98dfa8d5eea6d8de9f3f50449627df4293a02e0b2c83e86e29162",
	"2-1": "4d47de6f10acd91ca8b94644d109422543e25cecbce3e6cb341fb88c530f5239",
	"2-3": "a30199c6c3e349b5acec870cf3e0404623f499e6221b3063f260e12aa6e9c7c4",
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
	_check(ver.is_valid_int() and int(ver) >= 2, "the App Store build number is past TestFlight's first (%s)" % ver)
