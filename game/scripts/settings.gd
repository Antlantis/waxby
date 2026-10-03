extends RefCounted
## The small settings file the whole game shares, user://settings.json (every
## save slot shares it too; Game keeps "last_slot" there). Sfx
## keeps "muted", "volume" and "music_muted" there; other scripts may add
## their own keys. Each writer merges only its own keys over what is on disk,
## so no one's keys get lost and nobody writes back a stale copy of someone
## else's. A write only lands whole (write_whole), and the file it replaced
## is kept as settings.json.bak, which read() falls back to.
##
##     const SettingsLib := preload("res://scripts/settings.gd")
##     var saved: Dictionary = SettingsLib.read()
##     SettingsLib.write({"haptics": false})

const PATH := "user://settings.json"


static func read(path: String = PATH) -> Dictionary:
	## Everything in the file, or when it is missing or not a JSON object,
	## in its backup (path.bak: the last good file before the latest write),
	## or {}.
	var got = parse_file(path)
	if got is Dictionary:
		return got
	got = parse_file(path + ".bak")
	return got if got is Dictionary else {}


static func parse_file(path: String):
	## A JSON file's contents, or null when it is missing or not JSON.
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return null
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null


static func write(values: Dictionary, path: String = PATH) -> void:
	## Merge values over what is on disk now and save the lot (write_whole:
	## every save slot shares this file, and it says which slot opens).
	var main_ok: bool = parse_file(path) is Dictionary
	var all := read(path)
	all.merge(values, true)
	write_whole(path, JSON.stringify(all), main_ok)


static func write_whole(path: String, text: String, backup := true) -> bool:
	## text to path, safely: written to path.tmp first and moved over path
	## only when the whole of it went down (store_string true, no file error,
	## the full length), so a kill mid-write or a full disk leaves the old
	## file as it was (and no .tmp behind). With backup, the file it
	## replaces is copied to path.bak first (the saves and the settings keep
	## their last good file there; don't back up a file that couldn't be
	## read over a good backup). False if nothing was written.
	var tmp := path + ".tmp"
	var gtmp := ProjectSettings.globalize_path(tmp)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var ok := f.store_string(text)
	f.flush()
	ok = ok and f.get_error() == OK and f.get_length() == text.to_utf8_buffer().size()
	f.close()
	if not ok:
		DirAccess.remove_absolute(gtmp)
		return false
	var gpath := ProjectSettings.globalize_path(path)
	if backup and FileAccess.file_exists(path):
		DirAccess.copy_absolute(gpath, gpath + ".bak")
	if DirAccess.rename_absolute(gtmp, gpath) != OK:
		DirAccess.remove_absolute(gtmp)
		return false
	return true
