extends RefCounted
## WAXBY's story as data: every scene, beat, bark and after-line, plus the
## small helpers that resolve them for a calling. cutscene.gd plays the
## scenes; the HUD shows the barks; the results screen shows the after-lines.
## Ids match art/story/panels.json. Every line is at most 80 characters with
## the longest calling name filled in (tests/test_story.gd checks).
##
## v3 (spec §6): six worlds, the turn after 2-4 (the_pull), the descent
## through the Bone Orchard, the Frozen Carillon, the Shattered Sanctum and
## the Hushdeep, the finale (boss_6_after, homecoming, lullaby), the modes'
## hosts and the Lost Wicks. v2's ending and post_credits are retired.
##
## SCENE {"shots": [SHOT...], "music": track, "overlay": true, "next": id,
##        "barks": [bark keys played over the live level afterwards],
##        "bark_delay": s, "finale": id (main plays it after the results),
##        "resume": true (a finale after which main runs the player's choice)}
## SHOT  {"panel": id, "in": "fade|cut|flash", "figs": {anchor: fig_id},
##        "fig_alpha": {anchor: a}, "actor": anchor, "actor_lit": false,
##        "lights_off": [ids], "lights_on": [ids], "light_r": {id: mult},
##        "cam": [[x,y,z],[x,y,z]], "time": s, "music": track, "motes": kind,
##        "if": flag, "unless": flag (the shot plays only then), "beats": [BEAT...]}
## BEAT  ["who:mood", "text"] | ["who:mood", "text", {"shout": true, "at": "top|mid|low"}]
##       ["wick", "@slot"] (CLASS_LINES[slot][calling]) | {"do": cue, ...}
##       (a cue may carry "if": flag: it runs only when the flag is set)
## "{calling}" in a text becomes the calling's name, "{hero}" the hero's own
## name: the save's (Game.hero_name, asked for at the oath and changed on the
## Sheet), Waxby until then. The hero's speaker id is "wick": Wick is a title
## (any keeper who carries the flame is one, as Taper tells him at the oath),
## kept where the role is the point ("No Wick goes down alone again"); his
## name plate says his own name. Hollin says it in his warmest lines to him;
## Mother Taper calls him sprout, and says it only when it counts (her
## welcome at the oath, homecoming's "Well done").
## A panel light may carry "off": true (dark until a cue lights it), "color"
## (its tint) and "hush": true (a light that eats light).
##
## Never references the Game autoload by name (tests preload this file):
## it reaches it through the tree when it needs it.

const Classes := preload("res://scripts/classes.gd")

const HERO_NAME := "Waxby"      # the hero's name until the player gives him one (and what a bad one falls back to)
const NAME_MAX := 12           # a name's most characters (every line fits in MAX_LINE with one this long)
const MAX_LINE := 80
const MAX_SIGN := 56           # a sign's inscription (the HUD's hint slot)
const DESCENT_SCRIPT := "res://scripts/modes/descent.gd"   # the Endless Descent (MO), once it's in the build

const CAST := {
	"narrator":  {"name": "", "color": "f4ead6", "voice": 0.0, "style": "narrate"},
	"taper":     {"name": "Mother Taper", "color": "f2c75a", "voice": 1.6, "blip": "talk", "side": "right"},
	"waxley":    {"name": "Waxley", "color": "f7b64a", "voice": 0.85, "blip": "talk", "side": "right"},
	"tollgrave": {"name": "Old Tollgrave", "color": "7ef0c8", "voice": 0.5, "blip": "talk_low", "side": "right"},
	"snuffer":   {"name": "The Snuffer", "color": "c9c2f0", "voice": 0.7, "blip": "talk_breath", "side": "right"},
	"hollin":    {"name": "Hollin", "color": "a8b8d0", "voice": 1.25, "blip": "talk", "side": "right"},
	"hush":      {"name": "", "color": "9a90c8", "voice": 0.0, "style": "hush"},
	"wick":      {"name": HERO_NAME, "color": "@class", "voice": "@class", "blip": "talk", "side": "left"},
	# v3 (spec §6.5.1: the Rootmother shows as Mother Gravebough; the saint speaks as "saint")
	"rootmother": {"name": "Mother Gravebough", "color": "9fc46a", "voice": 0.55, "blip": "talk_wood", "side": "right"},
	"yarrow":     {"name": "Mother Yarrow", "color": "d8e8a0", "voice": 1.35, "blip": "talk_wood", "side": "right"},
	"tinker":     {"name": "The Tinker of Hours", "color": "8ccfe8", "voice": 0.65, "blip": "talk_tick", "side": "right"},
	"tickwell":   {"name": "Master Tickwell", "color": "e0b870", "voice": 1.5, "blip": "talk_tick", "side": "right"},
	"saint":      {"name": "The Prism Saint", "color": "eef0ff", "voice": 1.3, "blip": "talk_glass", "side": "right"},
	"tessel":     {"name": "Tessel", "color": "ff9ab8", "voice": 1.4, "blip": "talk_glass", "side": "right"},
	# The Lost Wicks (the secret levels): they share one portrait, echo_glow.
	"lamplighter": {"name": "The Lamplighter", "color": "e8d8a0", "voice": 0.8, "blip": "talk", "side": "right", "face": "echo"},
	"oldchandler": {"name": "The Old Chandler", "color": "e8d8a0", "voice": 0.75, "blip": "talk", "side": "right", "face": "echo"},
	"gardenboy":   {"name": "The Gardener's Boy", "color": "e8d8a0", "voice": 1.3, "blip": "talk", "side": "right", "face": "echo"},
	"rook":        {"name": "Brother Rook", "color": "e8d8a0", "voice": 0.9, "blip": "talk", "side": "right", "face": "echo"},
	"solder":      {"name": "Sister Solder", "color": "e8d8a0", "voice": 1.1, "blip": "talk", "side": "right", "face": "echo"},
	"abbess":      {"name": "The Iron Abbess", "color": "e8d8a0", "voice": 0.7, "blip": "talk_low", "side": "right", "face": "echo"},
}
# The first mood is the default.
const MOODS := {"taper": ["warm", "worried", "stern", "sad", "proud", "faint"], "waxley": ["grin", "shifty", "shock"],
	"tollgrave": ["hushed", "kind"], "snuffer": ["cold", "wrath"], "hollin": ["lost", "relit", "worried", "grin"],
	"wick": ["normal", "happy", "fierce", "hurt"], "narrator": [""], "hush": ["open"],
	"rootmother": ["keeping", "wrath"], "yarrow": ["gentle", "merry"], "tinker": ["ticking", "wrath"],
	"tickwell": ["dazed", "kind"], "saint": ["serene", "wrath"], "tessel": ["gentle", "sad"],
	"lamplighter": ["glow"], "oldchandler": ["glow"], "gardenboy": ["glow"], "rook": ["glow"], "solder": ["glow"],
	"abbess": ["glow"]}
# The Lost Wick at the end of each world's secret level (lost_wick_<w>).
const LOST_WICKS := {1: "lamplighter", 2: "oldchandler", 3: "gardenboy", 4: "rook", 5: "solder", 6: "abbess"}

# Every cue and the parameters it needs (optional ones are left out: a card's
# "at", top|mid|low, else it goes wherever no one is standing; an sfx's
# "vol"; a chain's "snuff"; a hold's "nudge" and "nudge_at"; a chooser's
# "prompt", and the name entry's). choose_name asks the hero's name (the
# oath's entry: the line before it, the question, stays up under it, and the
# cue's "prompt" heads the entry, where a phone's keyboard can't cover it).
const CUES := {
	"wait": ["t"], "cam": ["to", "t"], "snuff": ["light"], "ignite": ["light"], "light": ["light", "r", "t"],
	"chain": ["lights", "gap"], "fig": ["fig", "t"], "pose": ["fig", "frame"], "walk": ["to", "t"],
	"face": ["dir"], "mood": ["mood"], "burst": ["at", "n", "color"], "shake": ["amt"], "flash": [],
	"sfx": ["name"], "music": ["track"], "haptic": ["ms"], "dawn": ["t"], "iris": ["on", "t"],
	"card": ["sub", "title"], "boss_card": ["name", "title", "portrait"], "choose_class": [], "credits": [],
	"hold": ["light", "into", "t", "prompt"], "choose_name": [],
}
# The motes a shot may name (a panel's own, or the shot's).
const MOTES := ["", "dust", "snow", "embers", "wax", "moths", "spores", "rime", "shards", "fireflies"]

# The Tales screen's names for the scenes worth replaying.
const TITLES := {
	"intro": "The Night the Bells Stopped", "oath": "The Last Flame", "meet_waxley": "A Customer!",
	"beat_1_2": "Someone Below", "boss_1_before": "The Bell Warden", "boss_1_after": "The Bell Rings",
	"world_2": "Down into Wax", "boss_2_before": "The Hollow Wick", "boss_2_after": "Every Bell",
	"the_pull": "Not Yet",
	"world_3": "Down Through the Roots", "boss_3_before": "The Bone Gardener", "boss_3_after": "Holding On",
	"world_4": "The Upside-Down Tower", "boss_4_before": "The Frozen Minute", "boss_4_after": "Midnight",
	"world_5": "A Chapel of Glass", "boss_5_before": "The First Light", "boss_5_after": "A Girl with a Candle",
	"world_6": "The Bottom of the World", "boss_6_before": "The Hungry Quiet", "boss_6_after": "Everyone Else's",
	"homecoming": "Homecoming", "lullaby": "Again",
	"waxworks_open": "The Waxworks", "trials_open": "The Vigil Trials", "descent_open": "The Hush Dreams",
}
# The Tales in story order: [tab, scene]. Tabs 1-6 are the worlds, 7 the
# finale and the modes ("After").
const TALES := [
	[1, "intro"], [1, "oath"], [1, "meet_waxley"], [1, "beat_1_2"], [1, "boss_1_before"], [1, "boss_1_after"],
	[2, "world_2"], [2, "boss_2_before"], [2, "boss_2_after"], [2, "the_pull"],
	[3, "world_3"], [3, "boss_3_before"], [3, "boss_3_after"],
	[4, "world_4"], [4, "boss_4_before"], [4, "boss_4_after"],
	[5, "world_5"], [5, "boss_5_before"], [5, "boss_5_after"],
	[6, "world_6"], [6, "boss_6_before"], [6, "boss_6_after"],
	[7, "homecoming"], [7, "lullaby"], [7, "waxworks_open"], [7, "trials_open"], [7, "descent_open"],
]
const TALE_TABS := {1: "World 1", 2: "World 2", 3: "World 3", 4: "World 4", 5: "World 5", 6: "World 6", 7: "After"}

# The scene that opens a world, played the first time the player goes in.
const WORLD_OPENERS := {2: "world_2", 3: "world_3", 4: "world_4", 5: "world_5", 6: "world_6"}


const SCENES_W1 := {
	"intro": {"music": "story", "shots": [
		{"panel": "glass_legend", "in": "fade", "cam": [[0.167, 0.56, 1.14], [0.167, 0.5, 1.0]], "time": 6.0,
		 "beats": [
			["narrator", "Deep under the hill lives the Hush, a hungry quiet that eats light and sound."],
			{"do": "cam", "to": [0.5, 0.5, 1.0], "t": 2.2}, {"do": "wait", "t": 1.0},
			["narrator", "Evenbell was built over it. Its bells fanned a flame that kept the Hush asleep."],
			{"do": "cam", "to": [0.833, 0.5, 1.0], "t": 2.2},
			{"do": "sfx", "name": "bell", "pitch": 0.5}, {"do": "wait", "t": 1.0},
			["narrator", "Then one winter night, every bell went silent, and Evenbell sank into the hill."],
		]},
		{"panel": "lanternfold", "in": "fade", "cam": [[0.3, 0.5, 1.12], [0.62, 0.47, 1.0]], "time": 8.0, "beats": [
			["narrator", "Now the lamps of the town above go out. One more every night."],
			{"do": "snuff", "light": "lamp6"}, {"do": "wait", "t": 0.8},
			{"do": "snuff", "light": "lamp3"}, {"do": "wait", "t": 0.9},
		]},
		{"panel": "chapel", "in": "fade", "figs": {"taper": "taper_stand", "novice": "novice_back"},
		 "light_r": {"taper.head": 0.5}, "cam": [[0.5, 0.5, 1.0], [0.42, 0.53, 1.16]], "time": 8.0, "beats": [
			["taper:warm", "There you are, sprout. My flame's too short to go down there."],
			["taper:stern", "And yours isn't lit yet. So. Let's fix one of those."],
		]},
	]},

	# Choose, Taper's reaction, the lighting and the hero's oath; then the
	# name (Taper asks, the player answers in the entry; the hero's plate is
	# blank till then), the title explained (any keeper who carries the flame
	# is a Wick) as she welcomes him by it, and the send-off. No spire, no iris.
	"oath": {"music": "story", "shots": [
		{"panel": "callings", "in": "fade",
		 "lights_off": ["plinth_knight", "plinth_founder", "plinth_witch", "plinth_runner", "plinth_sexton"],
		 "cam": [[0.5, 0.44, 1.14], [0.5, 0.5, 1.0]], "time": 3.0, "beats": [
			{"do": "choose_class", "prompt": "Pick the calling that fits your hands. Not your pride."},
			["taper:proud", "@taper_react"],
		]},
		{"panel": "chapel", "in": "fade", "figs": {"taper": "taper_stand"}, "actor": "actor", "actor_lit": false,
		 "light_r": {"taper.head": 0.5}, "cam": [[0.5, 0.5, 1.0], [0.53, 0.52, 1.18]], "time": 5.0, "beats": [
			{"do": "wait", "t": 0.7},
			{"do": "ignite", "light": "actor"}, {"do": "mood", "mood": "happy"}, {"do": "haptic", "ms": 30},
			{"do": "wait", "t": 0.6},
			["wick:happy", "@oath"],
			{"do": "mood", "mood": ""},
			["taper:warm", "Tell the flame your name, sprout."],
			{"do": "choose_name", "prompt": "Tell the flame your name"},
			["taper:proud", "Carry the flame and you're a Wick. Every keeper is. Welcome, {hero}."],
			["taper:warm", "Now go and ring the bells, sprout. Give Evenbell its breath back."],
			# On the floor under the hero, clear of his flame whatever his calling.
			{"do": "card", "sub": "World 1", "title": "The Sunken Cathedral", "at": "low"},
		]},
	]},

	"meet_waxley": {"overlay": true, "shots": [{"beats": [
		["waxley:grin", "A customer! A live one! Waxley, chandler: candles, charms and holy relics."],
		["wick", "@waxley"],
		["waxley:shifty", "Embers only, friend. No credit, no refunds, no questions."],
	]}]},

	# A new calling made from the Callings screen: Taper has a word for it
	# (Hollin does, while she rests: REST_SUBS).
	"new_calling": {"overlay": true, "shots": [{"beats": [
		["taper:proud", "@taper_react"],
	]}]},

	# Two barks over the live level; play never stops.
	"beat_1_1": {"overlay": true, "barks": ["beat_1_1_a", "beat_1_1_b"], "bark_delay": 3.2},

	"beat_1_2": {"overlay": true, "barks": ["beat_1_2_a", "beat_1_2_b"], "shots": [
		{"panel": "crypt_row", "in": "fade", "figs": {"far": "snuffer_reach"},
		 "cam": [[0.5, 0.5, 1.0], [0.57, 0.46, 1.28]], "time": 7.0, "beats": [
			{"do": "wait", "t": 0.5},
			{"do": "snuff", "light": "c8"}, {"do": "wait", "t": 0.35},
			{"do": "snuff", "light": "c7"}, {"do": "wait", "t": 0.3},
			{"do": "snuff", "light": "c6"}, {"do": "wait", "t": 0.25},
			{"do": "snuff", "light": "c5"},
			["snuffer:cold", "Another little light. How brave. How tiring."],
			["snuffer:cold", "Go home, little Wick. It's so much quieter without you."],
			{"do": "fig", "fig": "far", "alpha": 0.0, "t": 1.0}, {"do": "wait", "t": 0.7},
		]},
		{"in": "fade", "beats": [
			["taper:worried", "That shape... No. Old eyes, that's all."],
		]},
	]},

	"beat_1_3": {"overlay": true, "barks": ["beat_1_3_a", "beat_1_3_b"], "shots": [{"beats": [
		["taper:warm", "The choir loft. When the bells stopped, a thousand candles fell here."],
		["taper:sad", "I sent a Wick down once before. Hollin. He never came back."],
		["wick", "@beat_1_3"],
	]}]},

	"beat_1_4": {"overlay": true, "shots": [{"beats": [
		["taper:warm", "The bell tower. Old Tollgrave rang that bell for three hundred years."],
		["taper:warm", "Kind old bones. Deaf as a post."],
		["taper:worried", "If the Hush has him, aim for his head while the bell is stuck."],
	]}]},

	# Seen once; a retry goes straight to the fight (world.gd checks Game.seen).
	"boss_1_before": {"overlay": true, "shots": [
		{"panel": "belfry", "in": "cut", "figs": {"boss": "tollgrave_boss"}, "lights_off": ["boss.eyes"],
		 "cam": [[0.5, 0.5, 1.0], [0.53, 0.55, 1.3]], "time": 6.0, "beats": [
			{"do": "sfx", "name": "boss_slam", "pitch": 0.6}, {"do": "shake", "amt": 4.0}, {"do": "wait", "t": 0.6},
			{"do": "ignite", "light": "boss.eyes"},
			["tollgrave:hushed", "...hush. The bell. Must. Stay. Quiet."],
			["wick:fierce", "@boss_1"],
			["tollgrave:hushed", "QUIET!", {"shout": true}],
			{"do": "shake", "amt": 8.0},
			{"do": "boss_card", "name": "Old Tollgrave", "title": "The Bell Warden", "portrait": "tollgrave:hushed"},
		]},
	]},

	"boss_1_after": {"music": "story", "shots": [
		{"panel": "belfry", "in": "fade", "figs": {"sit": "tollgrave_sit"}, "actor": "actor_after",
		 "cam": [[0.5, 0.5, 1.0], [0.5, 0.55, 1.12]], "time": 8.0, "beats": [
			{"do": "ignite", "light": "bell_beam"},
			["tollgrave:kind", "Oh. Oh my. The bell. I can hear the bell!"],
			["tollgrave:kind", "Little light... did I hit you? I'm terribly sorry."],
			["wick", "@tollgrave"],
			["tollgrave:kind", "A tall one came. A cone for a head. He poured the quiet into my bell."],
			["tollgrave:kind", "Then he went down. To the Tallow Deep. To the Undercandle."],
		]},
		# The taunt: the belfry again, cold, the Snuffer framed in the broken window
		# against the moon; he drops out of it.
		{"panel": "belfry", "in": "fade", "music": "hush", "figs": {"sill": "snuffer_stand"},
		 "lights_off": ["bell_beam"], "light_r": {"moon1": 0.5, "moon2": 0.5},
		 "cam": [[0.5, 0.5, 1.0], [0.7, 0.55, 1.2]], "time": 7.0, "beats": [
			["snuffer:cold", "One bell. One little breath. The Undercandle coughs. You call it hope."],
			["snuffer:cold", "Come down, then. The deeper you go, the quieter it gets."],
			{"do": "fig", "fig": "sill", "move": [0, 50], "alpha": 0.0, "t": 0.7},   # he drops out of the window
			{"do": "sfx", "name": "whoosh", "pitch": 0.7}, {"do": "wait", "t": 0.9},
		]},
		{"panel": "lanternfold", "in": "fade", "music": "story", "lights_off": ["lamp3", "lamp6", "lamp1", "lamp8"],
		 "cam": [[0.55, 0.5, 1.16], [0.55, 0.5, 1.0]], "time": 6.0, "beats": [
			["taper:stern", "Sprout. Every flame of the Vigil was lit from the Undercandle."],
			["taper:worried", "If it goes out, so does mine. So does yours."],
			{"do": "ignite", "light": "lamp3"},
			["narrator", "Up in Lanternfold, one lamp flickered back to life."],
		]},
	]},
}

const SCENES_W2 := {
	# Waxley and the hero at the lip of the Deep; then the camera leaves them
	# and looks out over it for the words.
	"world_2": {"music": "story", "shots": [
		{"panel": "tallow_vista", "in": "fade", "figs": {"waxley": "waxley_pack"}, "actor": "edge",
		 "cam": [[0.18, 0.5, 1.16], [0.22, 0.5, 1.12]], "time": 6.0, "motes": "wax", "beats": [
			["waxley:shock", "You're going down there? Into the Tallow Deep? Marvelous!"],
			["waxley:grin", "My old guild hall's down there. Mountains of stock! I'm coming with you."],
			["wick", "@world_2"],
			{"do": "cam", "to": [0.66, 0.6, 1.0], "t": 4.5},
			["narrator", "A thousand years of candles had melted and run down here, into hills of wax."],
			["narrator", "And at the very bottom, small and tired, burned the Undercandle."],
			{"do": "card", "sub": "World 2", "title": "The Tallow Deep"},
		]},
	]},

	"beat_2_1": {"overlay": true, "shots": [{"beats": [
		["taper:stern", "Soft wax underfoot. It sinks if you dawdle. Keep moving."],
		["taper:worried", "And mind the drips, sprout. Some of them are alive."],
		["wick", "@beat_2_1"],
	]}]},

	# The helm itself is a prop in 2-2; the line works at the door or beside it.
	"beat_2_2": {"overlay": true, "barks": ["beat_2_2_a"], "shots": [{"beats": [
		["taper:sad", "Hollin's old candle-helm is down here somewhere. I buckled it on him myself."],
		["taper:sad", "Forty winters ago. He was littler than you."],
		["wick", "@beat_2_2"],
	]}]},

	# The moths play over the live level.
	"beat_2_3": {"overlay": true, "barks": ["beat_2_3_a", "beat_2_3_b"], "shots": [{"motes": "moths", "beats": [
		["snuffer:cold", "Aren't you tired? Always afraid it'll go out. Put it down. It's so quiet."],
		["wick:fierce", "@beat_2_3"],
		["snuffer:wrath", "Then come down and have it taken.", {"shout": true}],
	]}]},

	"beat_2_4": {"overlay": true, "shots": [{"beats": [
		["taper:warm", "The Undercandle. I was a novice the last time I saw it."],
		["taper:worried", "It's so small now."],
	]}]},

	"boss_2_before": {"overlay": true, "barks": ["boss_2_a"], "bark_delay": 1.2, "shots": [
		{"panel": "undercandle", "in": "fade", "figs": {"boss": "snuffer_reach"}, "light_r": {"under_flame": 0.35},
		 "cam": [[0.5, 0.3, 1.0], [0.6, 0.62, 1.25]], "time": 7.0, "beats": [
			{"do": "wait", "t": 1.2},
			["taper:sad", "Hollin. It's me. It's Mother. Come home."],
			["snuffer:cold", "There's no one in here, Mother. Not for forty winters."],
			["wick:fierce", "@boss_2"],
			{"do": "shake", "amt": 8.0},
			{"do": "boss_card", "name": "The Snuffer", "title": "The Hollow Wick", "portrait": "snuffer:wrath"},
		]},
	]},

	# v3: the same as v2 through Hollin's "Oh. It's warm.", then every bell.
	# The shake, boss_die and "...not yet." move to the_pull, which main plays
	# when the player leaves the results (or on a v2 save's next map).
	"boss_2_after": {"music": "hush", "finale": "the_pull", "shots": [
		{"panel": "undercandle", "in": "fade", "figs": {"cone": "cone_broken", "hollin": "hollin_cold"},
		 "actor": "actor_near", "light_r": {"under_flame": 0.35},
		 "cam": [[0.5, 0.6, 1.0], [0.5, 0.8, 1.38]], "time": 6.0, "beats": [
			["narrator", "The cone split in two. Inside was only a small, cold boy."],
			["hollin:lost", "It's so cold. I forgot what warm was."],
			["hollin:lost", "Don't. Mine went out. It can't be lit again."],
			["wick", "@share"],
			{"do": "walk", "to": 0.47, "t": 0.75},   # close, his weapon clear of Hollin
			{"do": "wait", "t": 0.8},
			{"do": "pose", "fig": "hollin", "frame": "hollin_warm"},
			{"do": "ignite", "light": "hollin.head"}, {"do": "haptic", "ms": 40},
			["hollin:relit", "Oh. It's warm. It's so warm."],
			{"do": "wait", "t": 0.6},
		]},
		{"panel": "bells_all", "in": "flash", "music": "dawn", "cam": [[0.5, 0.9, 1.0], [0.5, 0.1, 1.0]], "time": 8.0,
		 "beats": [
			{"do": "ignite", "light": "under_flame"},
			{"do": "chain", "lights": ["bell1", "bell2", "bell3", "bell4", "bell5", "bell6", "bell7", "bell8"],
			 "gap": 0.45, "sfx": "bell"},
			{"do": "wait", "t": 1.2},
			["narrator", "And every bell in Evenbell rang at once."],
		]},
	]},

	# The turn. The Hush answers. "resume": after it, the player's Onward /
	# Replay / Map runs (Onward goes on into world_3 and 3-1).
	"the_pull": {"music": "hush", "resume": true, "shots": [
		# The Undercandle, just relit and warm: the camera on its flame. Then
		# something rises out of the dark below and closes on it, and drags it
		# down past the two of them, out through the floor.
		{"panel": "undercandle", "in": "fade", "figs": {"hollin": "hollin_warm", "grasp": "hush_grasp"},
		 "fig_alpha": {"grasp": 0.0}, "actor": "actor_near", "lights_off": ["under_flame"],
		 "cam": [[0.5, 0.3, 1.0], [0.5, 0.3, 1.0]], "time": 0.0, "beats": [
			{"do": "light", "light": "under_warm", "r": 1.0, "t": 0.0},
			{"do": "fig", "fig": "grasp", "move": [0, 360], "t": 0.0},   # down in the dark, out of sight
			{"do": "wait", "t": 1.2},
			{"do": "sfx", "name": "bell_choke"}, {"do": "shake", "amt": 6.0}, {"do": "haptic", "ms": 40},
			["hush", "...not yet.", {"at": "mid"}],   # over the candle: its flame above, their faces below
			# It rises up the candle, and its fingers close on the flame...
			{"do": "fig", "fig": "grasp", "alpha": 1.0, "move": [0, -360], "t": 1.5}, {"do": "wait", "t": 1.6},
			{"do": "light", "light": "under_warm", "r": 0.0, "t": 0.25}, {"do": "light", "light": "grasp.stolen", "r": 1.0, "t": 0.25},
			{"do": "wait", "t": 0.5},
			# ...and drags it down past them, out through the floor.
			{"do": "fig", "fig": "grasp", "move": [0, 600], "t": 1.8},
			{"do": "cam", "to": [0.5, 0.62, 1.14], "t": 1.8},
			{"do": "sfx", "name": "pull"}, {"do": "shake", "amt": 10.0}, {"do": "haptic", "ms": 60},
			{"do": "wait", "t": 1.1},
			{"do": "light", "light": "grasp.stolen", "r": 0.0, "t": 0.7},   # gone under the floor with it
			{"do": "wait", "t": 1.6},
			["hush", "little lights. i am so much deeper than your candle.", {"at": "top"}],
		]},
		# Above: every lamp at once.
		{"panel": "lanternfold", "in": "cut", "music": "", "cam": [[0.5, 0.5, 1.04], [0.5, 0.5, 1.0]], "time": 4.0,
		 "beats": [
			{"do": "wait", "t": 0.6},
			{"do": "chain", "lights": ["lamp1", "lamp2", "lamp3", "lamp4", "lamp5", "lamp6", "lamp7", "lamp8"],
			 "gap": 0.08, "snuff": true},
			{"do": "wait", "t": 1.0},
			["narrator", "Every lamp in Lanternfold went out at once."],
		]},
		# The chapel: Taper's flame falls to an ember.
		{"panel": "chapel", "in": "fade", "figs": {"taper": "taper_chair"}, "light_r": {"taper.head": 0.6},
		 "lights_off": ["lectern1", "lectern2", "lectern3", "hearth"],
		 "cam": [[0.42, 0.52, 1.1], [0.36, 0.55, 1.24]], "time": 6.0, "beats": [
			{"do": "light", "light": "taper.head", "r": 0.15, "t": 1.6}, {"do": "wait", "t": 1.0},
			["taper:faint", "Oh. There it goes."],
			["taper:faint", "Not out, sprout. I'd feel it. Taken. Dragged down deep."],
		]},
		# Back below, in the dark, with Hollin.
		{"panel": "undercandle", "in": "fade", "music": "story", "figs": {"hollin": "hollin_warm"}, "actor": "actor_near",
		 "lights_off": ["under_flame", "reed1", "reed2", "reed3", "reed4"],
		 "cam": [[0.5, 0.78, 1.3], [0.5, 0.8, 1.38]], "time": 6.0, "beats": [
			["hollin:worried", "Without it, Mother's ember won't last long. I'll go up to her."],
			["hollin:relit", "We share a flame now. I'll hear you through the smoke, like she does."],
			["wick", "@the_pull"],
			["hollin:relit", "Then go, Wick. I'll keep her lit. You keep yours."],
		]},
	]},
}

const SCENES_W3 := {
	"world_3": {"music": "story", "shots": [
		{"panel": "orchard_vista", "in": "fade", "figs": {"waxley": "waxley_pack", "cone": "cone_broken"},
		 "actor": "edge", "cam": [[0.18, 0.55, 1.14], [0.22, 0.55, 1.1]], "time": 6.0, "beats": [
			["narrator", "Beneath the Undercandle lay the Vigil's dead, and on every grave grew a tree."],
			["waxley:grin", "I kept the cone, by the way. Salvage! Somebody will buy it."],
			["wick", "@world_3"],
			{"do": "cam", "to": [0.62, 0.62, 1.0], "t": 4.5},   # along the scorch, down through the roots
			["hollin:worried", "It dragged the light down through those roots. Follow the scorch, Wick."],
			{"do": "card", "sub": "World 3", "title": "The Bone Orchard"},
		]},
	]},

	# 3-1 The Bramble Gate: two barks, play never stops.
	"beat_3_1": {"overlay": true, "barks": ["beat_3_1_a", "beat_3_1_b"], "bark_delay": 3.2},

	# 3-2 The Hanging Ossuary
	"beat_3_2": {"overlay": true, "shots": [{"beats": [
		["taper:faint", "These trees... Mother Yarrow planted most of them. She taught me."],
		["taper:faint", "She called all her novices 'sprout.' I stole it from her."],
		["wick", "@beat_3_2"],
	]}]},

	# 3-3 The Sporewood: her voice, over the live level, in drifting spores.
	"beat_3_3": {"overlay": true, "barks": ["beat_3_3_a", "beat_3_3_b"], "shots": [{"motes": "spores", "beats": [
		["rootmother:keeping", "Another sprout in my garden. Stay, little one. Everyone stays."],
		["taper:faint", "Sprout? I learned that word from... Oh. Mother Yarrow."],
	]}]},

	# 3-4 The Heartwood (the rule hint: spec §6.5.2)
	"beat_3_4": {"overlay": true, "shots": [{"beats": [
		["taper:faint", "The Heartwood. Her grave's in the middle. She's holding the way shut."],
		["hollin:worried", "Her heart runs through the roots. Hit it where it blooms."],
	]}]},

	"boss_3_before": {"overlay": true, "barks": ["boss_3_a"], "bark_delay": 1.2, "shots": [
		{"panel": "heartwood", "in": "cut", "figs": {"boss": "rootmother_boss"}, "lights_off": ["boss.eyes"],
		 "cam": [[0.5, 0.45, 1.0], [0.58, 0.52, 1.22]], "time": 6.0, "beats": [
			{"do": "sfx", "name": "boss_slam", "pitch": 0.5}, {"do": "shake", "amt": 4.0}, {"do": "wait", "t": 0.6},
			{"do": "ignite", "light": "boss.eyes"},
			["rootmother:keeping", "Hush now, sprout. I lost every one of them once. Never again."],
			["wick:fierce", "@boss_3"],
			["rootmother:wrath", "No one leaves my garden. STAY!", {"shout": true}],
			{"do": "shake", "amt": 8.0},
			{"do": "boss_card", "name": "Mother Gravebough", "title": "The Bone Gardener", "portrait": "rootmother:wrath"},
		]},
	]},

	"boss_3_after": {"music": "story", "shots": [
		# The roots open; the caged lights warm; her spirit steps out of the grave.
		{"panel": "heartwood", "in": "fade", "figs": {"boss": "rootmother_open", "spirit": "yarrow_spirit"},
		 "fig_alpha": {"spirit": 0.0}, "actor": "actor",
		 "cam": [[0.5, 0.5, 1.0], [0.46, 0.63, 1.16]], "time": 8.0, "beats": [
			{"do": "chain", "lights": ["cage1", "cage2", "cage3", "cage4", "cage5", "cage6"], "gap": 0.3, "snuff": true},
			{"do": "chain", "lights": ["kept1", "kept2", "kept3", "kept4", "kept5", "kept6"], "gap": 0.3},
			{"do": "wait", "t": 1.2},
			{"do": "fig", "fig": "spirit", "alpha": 1.0, "t": 1.2}, {"do": "ignite", "light": "spirit.head"},
			["yarrow:gentle", "Oh. I was holding on so tight, I forgot what for."],
			["taper:faint", "Mother Yarrow. It's me. Your sprout."],
			["yarrow:merry", "Little Taper! Look at you. So old! And still so short."],
			["wick", "@yarrow"],
		]},
		# The goodbye: the kept lights rise and follow the Wick. Her flask is
		# the Second Draught's face (spec §6.5.3).
		{"panel": "heartwood", "in": "fade", "figs": {"boss": "rootmother_open", "spirit": "yarrow_spirit"},
		 "fig_alpha": {"boss": 0.5}, "actor": "actor", "lights_off": ["cage1", "cage2", "cage3", "cage4", "cage5", "cage6"],
		 "lights_on": ["kept1", "kept2", "kept3", "kept4", "kept5", "kept6", "spirit.head"],
		 "motes": "fireflies", "cam": [[0.46, 0.63, 1.16], [0.45, 0.63, 1.2]], "time": 12.0, "beats": [
			# Held on the two of them while she says goodbye; then up to the lights.
			["yarrow:gentle", "Holding on isn't keeping, sprouts. Let them go. Let me go too."],
			["yarrow:gentle", "My roots will open the way down. Take my little ones with you."],
			["yarrow:merry", "Here. My old flask. It always had one more drink in it than you'd think."],
			# (the fades start with the rise: every cue here runs at once)
			{"do": "fig", "fig": "spirit", "alpha": 0.0, "move": [0, -80], "t": 2.0},
			{"do": "fig", "fig": "boss", "alpha": 0.0, "t": 2.5},
			{"do": "cam", "to": [0.5, 0.36, 1.0], "t": 3.2}, {"do": "wait", "t": 1.2},
			["narrator", "Every light she had kept rose, and followed the Wick down.", {"at": "top"}],   # (the camera has him low)
		]},
	]},
}

const SCENES_W4 := {
	"world_4": {"music": "story", "shots": [
		{"panel": "carillon_vista", "in": "fade", "figs": {"waxley": "waxley_pack"}, "actor": "edge",
		 "cam": [[0.5, 0.22, 1.12], [0.5, 0.24, 1.08]], "time": 5.0, "motes": "rime", "beats": [
			["waxley:shock", "Cold! Wax cracks in the cold, friend. So does Waxley."],
			{"do": "cam", "to": [0.5, 0.74, 1.0], "t": 5.0},   # down the hanging tower
			["narrator", "Below the orchard hung Evenbell's secret: a bell tower built upside down."],
			["hollin:worried", "Its bells rang down, for the Hush. When they rang, it slept."],
			["hollin:worried", "I stopped them first, forty winters ago. I'm sorry, {hero}."],
			["wick", "@world_4"],
			{"do": "card", "sub": "World 4", "title": "The Frozen Carillon"},
		]},
	]},

	# 4-1 The Rime Stair
	"beat_4_1": {"overlay": true, "barks": ["beat_4_1_a", "beat_4_1_b"], "bark_delay": 3.2},

	# 4-2 The Escapement
	"beat_4_2": {"overlay": true, "barks": ["beat_4_2_a"], "shots": [{"beats": [
		["tinker:ticking", "Tick. Late. Tick. Late. I was one minute late."],
		["hollin:worried", "Someone's still down here. Still winding."],
	]}]},

	# 4-3 The Hall of Weights: Taper's confession, and the promise the finale keeps.
	"beat_4_3": {"overlay": true, "barks": ["beat_4_3_a"], "shots": [{"beats": [
		["taper:faint", "Sprout. I sent Hollin down alone. I was too frightened to go myself."],
		["hollin:worried", "You didn't know, Mother."],
		["taper:faint", "I knew enough. No Wick goes down alone again. Remember I said so."],
	]}]},

	# 4-4 The Hour Chamber
	"beat_4_4": {"overlay": true, "barks": ["beat_4_4_a"], "shots": [{"beats": [
		["taper:faint", "Master Tickwell kept these bells. Fussy little man. Never once late."],
		["hollin:worried", "Then why does he think he was?"],
	]}]},

	"boss_4_before": {"overlay": true, "barks": ["boss_4_a"], "bark_delay": 1.2, "shots": [
		{"panel": "escapement", "in": "cut", "figs": {"boss": "tinker_boss"}, "lights_off": ["boss.eyes"],
		 "cam": [[0.5, 0.5, 1.0], [0.56, 0.45, 1.25]], "time": 6.0, "beats": [
			{"do": "sfx", "name": "clock_strike", "pitch": 0.5}, {"do": "shake", "amt": 3.0}, {"do": "wait", "t": 0.6},
			{"do": "ignite", "light": "boss.eyes"},
			["tinker:ticking", "One minute to midnight. Hold it here, and I'm never late."],
			["wick:fierce", "@boss_4"],
			["tinker:wrath", "DON'T. TOUCH. THE HANDS.", {"shout": true}],
			{"do": "shake", "amt": 8.0},
			{"do": "boss_card", "name": "The Tinker of Hours", "title": "The Frozen Minute", "portrait": "tinker:wrath"},
		]},
	]},

	"boss_4_after": {"music": "story", "shots": [
		# The case on its back cracks open; a tiny old man is left; midnight strikes.
		{"panel": "escapement", "in": "fade", "figs": {"boss": "tinker_boss", "tickwell": "tickwell"},
		 "fig_alpha": {"tickwell": 0.0}, "lights_off": ["boss.eyes", "tickwell.watch"], "actor": "actor",
		 "cam": [[0.5, 0.5, 1.0], [0.62, 0.55, 1.16]], "time": 8.0, "beats": [
			{"do": "sfx", "name": "ice_crack"}, {"do": "shake", "amt": 6.0},
			{"do": "fig", "fig": "boss", "alpha": 0.0, "t": 0.9}, {"do": "fig", "fig": "tickwell", "alpha": 1.0, "t": 0.9},
			{"do": "wait", "t": 0.8},
			{"do": "sfx", "name": "clock_strike"}, {"do": "ignite", "light": "tickwell.watch"}, {"do": "wait", "t": 0.8},
			["tickwell:dazed", "Midnight? It's midnight. It's already tomorrow."],
			["tickwell:dazed", "Forty winters? It was one minute. I just didn't want it to be my fault."],
			["hollin:worried", "It wasn't your fault, Master Tickwell. It was mine."],
			["tickwell:kind", "Then we'll both ring the next one. That's all anyone can do."],
			["wick", "@tickwell"],
		]},
		# The bench: the snuffer becomes a bell, and the Downward Bells ring.
		{"panel": "escapement", "in": "fade", "music": "lullaby",
		 "figs": {"tickwell": "tickwell", "waxley_bench": "waxley_pack", "bench": "cone_broken"}, "actor": "actor_bench",
		 "cam": [[0.6, 0.56, 1.14], [0.61, 0.56, 1.16]], "time": 4.0, "beats": [
			{"do": "light", "light": "bench_lamp", "r": 1.0, "t": 0.4},
			["waxley:shifty", "A craftsman! Could you do anything with this? Slightly used."],
			{"do": "cam", "to": [0.7, 0.6, 1.5], "t": 2.2},   # in on Tickwell at his bench (the panel's right edge holds it there)
			["tickwell:kind", "A snuffer? Hm. Turn it upside down, and it's a bell."],
			{"do": "ignite", "light": "forge"},
			{"do": "sfx", "name": "anvil"}, {"do": "wait", "t": 0.35},
			{"do": "sfx", "name": "anvil", "pitch": 1.12}, {"do": "wait", "t": 0.35},
			{"do": "sfx", "name": "anvil", "pitch": 1.26}, {"do": "burst", "at": "bench", "n": 24, "color": "ffb05a"},
			{"do": "pose", "fig": "bench", "frame": "cone_bell"}, {"do": "wait", "t": 0.5},
			["tickwell:kind", "There. A bell for Hollin. For the next one."],
			{"do": "sfx", "name": "lull"}, {"do": "wait", "t": 2.4},
			["narrator", "And the upside-down bells rang into the dark for the first time in forty years."],
		]},
	]},
}

const SCENES_W5 := {
	"world_5": {"music": "story", "shots": [
		{"panel": "sanctum_vista", "in": "fade", "figs": {"waxley": "waxley_pack"}, "actor": "edge",
		 "cam": [[0.16, 0.55, 1.14], [0.2, 0.55, 1.1]], "time": 5.0, "beats": [
			["waxley:shock", "Heights. No. I'll mind the shop. From right here. Forever."],
			{"do": "cam", "to": [0.62, 0.48, 1.0], "t": 5.0},
			["narrator", "Deeper still lay the Sanctum, a chapel of glass. It hung in pieces now."],
			["taper:faint", "Sprout... I'm going to rest my voice now. Hollin will talk your ear off."],
			["hollin:grin", "I will! She's all right. Just tired. I've got her ember in my hands."],
			["wick", "@world_5"],
			{"do": "card", "sub": "World 5", "title": "The Shattered Sanctum"},
		]},
	]},

	# 5-1 The Floating Aisle
	"beat_5_1": {"overlay": true, "barks": ["beat_5_1_a", "beat_5_1_b"], "bark_delay": 3.2},

	# 5-2 The Gale Gallery: her voice from the glass.
	"beat_5_2": {"overlay": true, "shots": [{"beats": [
		["saint:serene", "What a small, smoky little light. Doesn't it embarrass you?"],
		["wick", "@beat_5_2"],
		["saint:serene", "Up here, light is pure. No smoke. No flicker. No fear."],
	]}]},

	# 5-3 The Dawnglass Bridges
	"beat_5_3": {"overlay": true, "barks": ["beat_5_3_a"], "shots": [{"motes": "shards", "beats": [
		["hollin:worried", "These windows tell the legend. The first keeper. The saint up there."],
		["hollin:worried", "The Vigil prayed to her for a thousand years. What's the Hush done to her?"],
	]}]},

	# 5-4 The Lightwell (the rule hint: spec §6.5.2)
	"beat_5_4": {"overlay": true, "shots": [{"beats": [
		["hollin:worried", "When her light locks, get behind a mirror."],
	]}]},

	"boss_5_before": {"overlay": true, "barks": ["boss_5_a"], "bark_delay": 1.2, "shots": [
		{"panel": "glass_throne", "in": "cut", "figs": {"saint": "saint_boss"}, "lights_off": ["saint.eyes"],
		 "cam": [[0.5, 0.45, 1.0], [0.5, 0.42, 1.22]], "time": 6.0, "beats": [
			{"do": "sfx", "name": "glass_chime", "pitch": 1.5}, {"do": "wait", "t": 0.5},
			{"do": "ignite", "light": "saint.eyes"},
			["saint:serene", "I was the first light. Put out that sooty flame, and I'll show you light."],
			["wick:fierce", "@boss_5"],
			["saint:wrath", "OUT, LITTLE CANDLE!", {"shout": true}],
			{"do": "shake", "amt": 8.0},
			{"do": "boss_card", "name": "The Prism Saint", "title": "The First Light", "portrait": "saint:wrath"},
		]},
	]},

	"boss_5_after": {"music": "story", "shots": [
		# Her cold light fails. He stands behind her glass, and she lights up in colour.
		# (The glass_throne "actor" anchor sits at depth 0.96, just behind the saint.)
		{"panel": "glass_throne", "in": "fade", "figs": {"saint": "saint_boss"}, "actor": "actor",
		 "lights_off": ["saint.eyes", "saint.halo", "saint.prism"],
		 "cam": [[0.5, 0.5, 1.0], [0.5, 0.48, 1.12]], "time": 8.0, "beats": [
			{"do": "light", "light": "rose_center", "r": 0.0, "t": 1.2}, {"do": "wait", "t": 1.0},
			["narrator", "The cold light went out of her. She was only dark glass now."],
			{"do": "walk", "to": 0.5, "t": 1.2},
			{"do": "pose", "fig": "saint", "frame": "tessel_lit"},
			{"do": "chain", "lights": ["pane1", "pane2", "pane3", "pane4", "pane5", "pane6"], "gap": 0.22, "sfx": "glass_chime"},
			{"do": "ignite", "light": "saint.heart"}, {"do": "wait", "t": 0.6},
			["tessel:gentle", "Oh. Oh, look. The colors."],
			["tessel:gentle", "It was never me that shone. It was the candle behind the glass."],
			["wick", "@tessel"],
			["tessel:gentle", "Before the windows, I was just a girl with a candle. Tessel. Like you."],
		]},
		# The window no one was shown: the truth.
		{"panel": "glass_truth", "in": "fade", "cam": [[0.5, 0.56, 1.12], [0.5, 0.5, 1.0]], "time": 9.0, "beats": [
			["tessel:sad", "I found the Hush. It wasn't a monster. Just a dark that never saw a light."],
			["tessel:sad", "I couldn't beat it. So I sang to it, and it slept."],
			["tessel:sad", "It isn't cruel, little keeper. It's cold. No one ever gave it anything."],
			["hollin:worried", "...I know. I lived inside it."],
		]},
		# The stair.
		{"panel": "glass_throne", "in": "fade", "figs": {"saint": "tessel_lit"}, "actor": "actor",
		 "lights_off": ["rose_center"],
		 "lights_on": ["pane1", "pane2", "pane3", "pane4", "pane5", "pane6", "saint.heart"],
		 "cam": [[0.5, 0.48, 1.12], [0.5, 0.72, 1.0]], "time": 6.0, "beats": [
			["tessel:gentle", "Go down. My glass will make you a stair."],
			{"do": "chain", "lights": ["step1", "step2", "step3", "step4"], "gap": 0.35, "sfx": "glass_chime"},
			{"do": "wait", "t": 1.6},
		]},
	]},
}

const SCENES_W6 := {
	# No motes: the stillness is the point.
	"world_6": {"music": "hush", "shots": [
		{"panel": "hushdeep_vista", "in": "fade", "actor": "edge", "motes": "",
		 "cam": [[0.22, 0.55, 1.14], [0.6, 0.52, 1.0]], "time": 9.0, "beats": [
			{"do": "wait", "t": 1.2},
			["narrator", "At the bottom of the world lay a lake. It was not water. It was quiet."],
			["hush", "come down, little light. there is no more down than this.", {"at": "top"}],
			["hollin:worried", "Down there, Wick, yours is the only flame. Keep it loud."],
			["wick", "@world_6"],
			{"do": "card", "sub": "World 6", "title": "The Hushdeep"},
		]},
	]},

	# 6-1 The Black Shore
	"beat_6_1": {"overlay": true, "barks": ["beat_6_1_a", "beat_6_1_b"], "bark_delay": 3.6},

	# 6-2 The Drowned Bells: the question each calling answers in its own words.
	"beat_6_2": {"overlay": true, "shots": [{"beats": [
		["hush", "you keep bringing me little lights. they all go out. every one."],
		["hush", "why is yours different?"],
		["wick", "@beat_6_2"],
	]}]},

	# 6-3 The Long Quiet: Hollin goes to fetch everyone (unsaid). Waxby is alone from here.
	"beat_6_3": {"overlay": true, "shots": [{"beats": [
		["hollin:worried", "{hero}, I have to go quiet a while. Something to do. Don't be scared."],
		["hush", "alone again, little light."],
	]}]},

	# 6-4 The Heart of the Hush
	"beat_6_4": {"overlay": true, "shots": [{"beats": [
		["hush", "your old candle's flame is here. inside me. come and take it."],
	]}]},

	"boss_6_before": {"overlay": true, "shots": [
		{"panel": "hushdeep_heart", "in": "fade", "figs": {"eye": "hush_eye"}, "actor": "actor",
		 "cam": [[0.62, 0.55, 1.0], [0.74, 0.5, 1.12]], "time": 7.0, "beats": [
			{"do": "fig", "fig": "eye", "scale_y": 0.02, "t": 0.0}, {"do": "wait", "t": 1.0},
			{"do": "fig", "fig": "eye", "scale_y": 1.0, "t": 1.6}, {"do": "sfx", "name": "pull", "pitch": 0.6},
			{"do": "light", "light": "eye.pupil", "r": 1.0, "t": 1.0},   # the stolen flame, a glint in its eye
			["hush", "i ate the sound of every bell. i ate your candle's flame. still hungry.", {"at": "top"}],
			["wick:fierce", "@boss_6"],
			["hush", "be quiet now.", {"at": "top"}],
			{"do": "shake", "amt": 10.0}, {"do": "haptic", "ms": 60},
			{"do": "boss_card", "name": "The Hush", "title": "The Hungry Quiet", "portrait": "hush:open"},
		]},
	]},

	# The finale. After the results, main plays "homecoming" (then "lullaby").
	# With the gift given in the level (hush_finale.gd sets hush_given), it
	# plays from its second shot: the far bell.
	"boss_6_after": {"music": "", "finale": "homecoming", "shots": [
		# 1. What it swallowed went out. It asks for his. He gives it (the fallback).
		{"unless": "hush_given", "panel": "hushdeep_heart", "in": "fade", "figs": {"eye": "hush_eye", "wick": "stolen_wick"},
		 "fig_alpha": {"eye": 0.8}, "actor": "actor",
		 "cam": [[0.62, 0.6, 1.0], [0.58, 0.66, 1.18]], "time": 8.0, "beats": [
			{"do": "wait", "t": 1.2},
			["hush", "see? it went out. everything goes out.", {"at": "top"}],
			["hush", "give me yours, little light. it's all you have left.", {"at": "top"}],
			["wick", "@give"],
			{"do": "walk", "to": 0.483, "t": 1.2},   # to the cold wick (the actor_give anchor, x 870 of 1800)
			{"do": "hold", "light": "actor", "into": "wick.wick", "t": 3.0, "prompt": "Hold to give your flame",
			 "nudge": ["hush", "keep it, then. keep it all alone."], "nudge_at": 8.0},
			{"do": "wait", "t": 1.6},
			["hush", "...there. quiet at last.", {"at": "top"}],
			{"do": "wait", "t": 1.4},
		]},
		# 2. A bell far above. A tiny light at the top of the stair. Then everyone's.
		{"panel": "hushdeep_heart", "in": "cut",
		 "figs": {"eye": "hush_eye", "wick": "stolen_wick", "carry": "hollin_carry", "waxley": "waxley_pack",
				  "tollgrave": "tollgrave_stand", "tickwell": "tickwell", "town": "townsfolk_line"},
		 "fig_alpha": {"eye": 0.8}, "actor": "actor_give", "actor_lit": false,
		 "lights_off": ["carry.hollin", "carry.taper", "waxley.brim1", "waxley.brim2", "waxley.brim3", "waxley.brim4",
						"waxley.brim5", "tollgrave.eyes", "tollgrave.lantern", "tickwell.watch", "town.lamp1", "town.lamp2",
						"town.lamp3", "town.lamp4", "town.lamp5", "town.lamp6", "town.lamp7", "town.lamp8"],
		 "cam": [[0.58, 0.66, 1.18], [0.58, 0.66, 1.18]], "time": 0.0, "beats": [
			{"do": "wait", "t": 0.8},
			{"do": "sfx", "name": "bell", "pitch": 0.5, "vol": 0.6}, {"do": "wait", "t": 1.4},
			["hush", "...a bell?", {"at": "top"}],
			{"do": "cam", "to": [0.2, 0.42, 1.0], "t": 2.6}, {"do": "wait", "t": 2.6},
			{"do": "ignite", "light": "carry.taper"}, {"do": "wait", "t": 0.8},
			["taper:faint", "My flame's too short to go down there, sprout."],
			["taper:proud", "So I brought everyone else's."],
			{"do": "chain", "gap": 0.16, "lights": ["carry.hollin", "stair1", "waxley.brim1", "waxley.brim2", "waxley.brim3",
				"waxley.brim4", "waxley.brim5", "stair2", "tollgrave.eyes", "tollgrave.lantern", "stair3", "tickwell.watch",
				"stair4", "town.lamp1", "town.lamp2", "town.lamp3", "town.lamp4", "stair5", "town.lamp5", "town.lamp6",
				"town.lamp7", "town.lamp8", "stair6"]},
			{"do": "wait", "t": 2.2},
			["waxley:grin", "Everything must go! No charge. Don't tell anyone."],
		]},
		# 2b. Only with every Lost Wick's candle lit (E2).
		{"if": "lost_wicks_all", "panel": "hushdeep_heart", "in": "cut",
		 "figs": {"eye": "hush_eye", "wick": "stolen_wick", "carry": "hollin_carry", "waxley": "waxley_pack",
				  "tollgrave": "tollgrave_stand", "tickwell": "tickwell", "town": "townsfolk_line", "lost": "lost_wicks"},
		 "fig_alpha": {"eye": 0.8}, "actor": "actor_give", "actor_lit": false,
		 "lights_on": ["stair1", "stair2", "stair3", "stair4", "stair5", "stair6"],
		 "cam": [[0.3, 0.5, 1.05], [0.33, 0.52, 1.08]], "time": 5.0, "beats": [
			{"do": "chain", "lights": ["lost.w1", "lost.w2", "lost.w3", "lost.w4", "lost.w5", "lost.w6"], "gap": 0.3},
			{"do": "wait", "t": 1.0},
			["taper:proud", "And the Lost Wicks, all six. No Wick goes down alone. I said so."],
		]},
		# 3. Every light, back into his. From his, the stolen flame catches.
		{"panel": "hushdeep_heart", "in": "fade", "music": "lullaby",
		 "figs": {"eye": "hush_eye", "wick": "stolen_wick", "carry": "hollin_carry", "waxley": "waxley_pack",
				  "tollgrave": "tollgrave_stand", "tickwell": "tickwell", "town": "townsfolk_line"},
		 "fig_alpha": {"eye": 0.8}, "actor": "actor_give", "actor_lit": false,
		 "lights_on": ["stair1", "stair2", "stair3", "stair4", "stair5", "stair6"], "motes": "fireflies",
		 "cam": [[0.42, 0.58, 1.0], [0.55, 0.64, 1.16]], "time": 7.0, "beats": [
			["hollin:relit", "A flame shared is never lost, {hero}. You taught me that."],
			{"do": "burst", "at": "actor", "n": 48, "color": "ffd84a"}, {"do": "ignite", "light": "actor"},
			{"do": "mood", "mood": "happy"}, {"do": "haptic", "ms": 60},
			["wick", "@relit"],
			{"do": "mood", "mood": ""},
			{"do": "ignite", "light": "wick.wick"}, {"do": "flash"}, {"do": "shake", "amt": 6.0},
			{"do": "wait", "t": 1.2},
		]},
		# 4. The first bell ever heard down there. The Hush sleeps.
		{"panel": "hushdeep_heart", "in": "fade",
		 "figs": {"eye": "hush_eye", "wick": "stolen_wick", "carry": "hollin_carry", "waxley": "waxley_pack",
				  "tollgrave": "tollgrave_stand", "tickwell": "tickwell", "town": "townsfolk_line"},
		 "fig_alpha": {"eye": 0.8}, "actor": "actor_give",
		 "lights_on": ["stair1", "stair2", "stair3", "stair4", "stair5", "stair6", "wick.wick"], "motes": "fireflies",
		 "cam": [[0.62, 0.55, 1.0], [0.78, 0.5, 1.12]], "time": 9.0, "beats": [
			["hollin:grin", "I used to put out bells. Let me ring mine."],
			{"do": "sfx", "name": "lull"}, {"do": "wait", "t": 2.4},
			{"do": "light", "light": "eye.pupil", "r": 1.0, "t": 1.0},   # the flame, reflected in its eye
			["hush", "...oh.", {"at": "top"}],
			["hush", "...warm.", {"at": "top"}],
			{"do": "fig", "fig": "eye", "scale_y": 0.02, "t": 2.2}, {"do": "wait", "t": 1.6},
			["narrator", "And for the first time in a thousand years, the Hush was not hungry."],
		]},
	]},

	"homecoming": {"music": "evenbell", "next": "lullaby", "shots": [   # (A6: evenbell for homecoming and the credits; falls back to dawn)
		{"panel": "dawn_rise", "in": "fade", "cam": [[0.5, 0.64, 1.16], [0.5, 0.42, 1.0]], "time": 9.0, "beats": [
			{"do": "dawn", "t": 6.0},
			["narrator", "Evenbell rose out of the hill. This time, it stayed."],
			{"do": "chain", "lights": ["lamp1", "lamp2", "lamp3", "lamp4", "lamp5", "lamp6", "lamp7", "lamp8"], "gap": 0.15},
			["narrator", "And every lamp in Lanternfold came on, and stayed on."],
		]},
		# Lanternfold's square at dawn: everyone. The camera crosses them.
		{"panel": "homecoming", "in": "fade",
		 "figs": {"tollgrave": "tollgrave_stand", "taper": "taper_stand", "hollin": "hollin_warm",
				  "waxley": "waxley_pack", "tickwell": "tickwell"},
		 "actor": "actor", "light_r": {"taper.head": 2.0},
		 "cam": [[0.35, 0.54, 1.1], [0.68, 0.54, 1.1]], "time": 12.0, "beats": [
			["taper:proud", "Look at my flame! I haven't been this tall since I was your size."],
			["tollgrave:kind", "Did you hear my bell, little light? I rang it all the way down!"],
			["tickwell:kind", "Seven o'clock exactly. And breakfast is late. Typical."],
			["waxley:shifty", "Those free candles? Small misunderstanding. Invoice to follow."],
		]},
		# Close on the two of them: Mother Taper calls him by his name, not sprout.
		{"panel": "homecoming", "in": "cut",
		 "figs": {"tollgrave": "tollgrave_stand", "taper": "taper_stand", "hollin": "hollin_warm",
				  "waxley": "waxley_pack", "tickwell": "tickwell"},
		 "actor": "actor", "light_r": {"taper.head": 2.0},
		 "cam": [[0.385, 0.54, 1.2], [0.39, 0.55, 1.28]], "time": 8.0, "beats": [
			["taper:warm", "Well done, {hero}."],
			["wick", "@homecoming"],
			["taper:stern", "Now go and wash, sprout. You smell like the bottom of the world."],
			["taper:warm", "A flame shared is never lost."],
			{"do": "iris", "on": "actor", "t": 1.6}, {"do": "wait", "t": 1.8},
			{"do": "credits"},
		]},
	]},

	# After the credits. The Downward Bells ring the Lull at midnight; the Hush
	# has a candle of its own. The cards only show what the game has opened
	# (Nightfall with the Hush on Dusk; the Descent once it's in the build).
	"lullaby": {"music": "", "shots": [
		{"panel": "hush_eye", "in": "fade", "figs": {"eye": "hush_eye", "float": "deep_candle"},
		 "fig_alpha": {"float": 0.0}, "cam": [[0.5, 0.5, 1.0], [0.5, 0.52, 1.08]], "time": 9.0, "beats": [
			{"do": "fig", "fig": "eye", "scale_y": 0.02, "t": 0.0}, {"do": "wait", "t": 1.6},
			{"do": "sfx", "name": "lull", "vol": 0.5}, {"do": "wait", "t": 2.4},
			{"do": "fig", "fig": "float", "alpha": 1.0, "t": 1.2}, {"do": "ignite", "light": "float.wick"},
			{"do": "fig", "fig": "eye", "scale_y": 0.3, "t": 1.4},
			{"do": "light", "light": "eye.pupil", "r": 1.0, "t": 0.8}, {"do": "wait", "t": 0.8},
			["hush", "...again.", {"at": "low"}],
			{"do": "sfx", "name": "lull", "vol": 0.5},
			{"do": "fig", "fig": "eye", "scale_y": 0.02, "t": 1.4}, {"do": "wait", "t": 1.6},
			{"do": "card", "sub": "The Vigil continues", "title": "Nightfall", "at": "mid"},
			{"do": "wait", "t": 2.8, "if": "modes_descent"},
			{"do": "card", "sub": "The Hush is dreaming", "title": "Endless Descent", "at": "mid", "if": "modes_descent"},
		]},
	]},
}

const SCENES_MODES := {
	# The Waxworks (the boss rush), on its screen's first open. Waxley hosts;
	# Tollgrave's bell (rush_bell) announces each cast.
	"waxworks_open": {"overlay": true, "shots": [{"beats": [
		["waxley:grin", "Waxley's Waxworks! Every boss you beat, cast in wax. For practice!"],
		["waxley:shifty", "They're lifelike. Too lifelike. Mind the drips. No refunds."],
	]}]},
	# The Vigil Trials: Mother Taper hosts (Hollin while she rests: REST_SUBS).
	"trials_open": {"overlay": true, "shots": [{"beats": [
		["taper:warm", "Every calling has its lessons. Show me you've learned yours."],
		["taper:warm", "Beat the candle, and you'll earn something to wear. Go on, sprout."],
	]}]},
	"trials_open_hollin": {"overlay": true, "shots": [{"beats": [
		["hollin:grin", "Mother's Trials! A lesson for every calling. Beat the candle, win a prize!"],
	]}]},
	# Endless Descent (after the ending). Hollin hosts: the Hush's dreams.
	"descent_open": {"overlay": true, "shots": [{"beats": [
		["hollin:grin", "It's asleep, {hero}. But it dreams of everything it ever swallowed."],
		["hollin:worried", "I dreamed them for forty winters. Go as deep as you dare. Then come back."],
	]}]},
	# While Taper rests (REST_SUBS): a calling made on the map.
	"new_calling_hollin": {"overlay": true, "shots": [{"beats": [
		["hollin:grin", "A new {calling}! Mother's resting, so I'll say it for her: welcome!"],
	]}]},
}

# Every scene set, in story order: scenes() merges them.
const SETS := [SCENES_W1, SCENES_W2, SCENES_W3, SCENES_W4, SCENES_W5, SCENES_W6, SCENES_MODES]
# Retired with v3 (a v2 save's seen entries for them are harmless leftovers).
const RETIRED := ["ending", "post_credits"]


# A calling's own line: "text" or ["mood", "text"]; "_" is the default for any calling.
const CLASS_LINES := {
	"taper_react": {
		"knight": "A Candleknight. Straight back, soft heart. Good.",
		"founder": "A Bellfounder. The bells will like you. Try not to break any more.",
		"witch": "A Taperwitch. Please don't set my chapel on fire.",
		"runner": "A Sootrunner. Hand back my spoons first.",
		"sexton": "A Sexton. Be kind to the dead down there. And wipe your boots after.",
		"_": "The {calling}. Ha! I should have guessed."},
	"oath": {
		"knight": "I'll keep it lit, Mother. On my honor. And my helmet.",
		"founder": "Warm as the foundry. I'll ring every bell down there. Hard.",
		"witch": "Oh, I'll keep it lit. I'll keep everything lit.",
		"runner": ["normal", "Mine? Nobody ever gave me anything. I usually just take it."],
		"sexton": "It flickers when I breathe. I think it likes me."},
	"waxley": {
		"knight": "Good sir, are these from the cathedral's vaults?",
		"founder": "Do you sell anything to eat? Or anything to hit things with?",
		"witch": "How much for all of it?",
		"runner": ["happy", "You know I could just take these."],
		"sexton": "Your mustache is wax. May I have the drips? For the graves."},
	"beat_1_1": {
		"knight": ["fierce", "Sorry, choir! This is for your own good!"],
		"founder": "Gently? I'll use the soft end of the maul.",
		"witch": "Gently. Right. Sure.",
		"runner": "Soft feet. I'm good at soft feet.",
		"sexton": "Easy now, brothers. I'll tuck you back in afterward."},
	"beat_1_2": {
		"knight": ["hurt", "Mother? Who was that?"],
		"founder": ["fierce", "He blew them out like birthday candles. I'll flatten him."],
		"witch": ["fierce", "Did he just blow out my candles? Rude."],
		"runner": "Tall, rude, good with a pole. I don't like him.",
		"sexton": "He smelled like cold wax. Like a grave with no one in it."},
	"beat_1_3": {
		"knight": ["fierce", "Then I'll come back for both of us."],
		"founder": "Then we'll bring him home. I'll carry him if I have to.",
		"witch": "I won't go out. I'm far too stubborn.",
		"runner": "I always come back. Ask anyone I owe money.",
		"sexton": "I'll keep a place for him. Every lost one gets a place."},
	"boss_1": {
		"knight": "Sir Tollgrave! Stand aside, in the name of the Vigil!",
		"founder": "Brother, you're ringing it wrong. Let me show you.",
		"witch": "Big bell. Big skull. Big target.",
		"runner": "Right. I'll just be taking that bell, then.",
		"sexton": "Your skull is perfect. Please hold still."},
	"tollgrave": {
		"knight": ["happy", "It's quite all right, sir. Mostly."],
		"founder": ["happy", "All forgiven. Your bell's got a lovely voice."],
		"witch": "A bit. I hit you more.",
		"runner": ["happy", "Don't worry. I took your spare embers as payment."],
		"sexton": "Only a little. Rest now. You've rung long enough."},
	"world_2": {
		"knight": "Then stay close, good sir. I'll guard you. And your stock.",
		"founder": "Did the guild hall have a kitchen?",
		"witch": "Fine. You carry the snacks.",
		"runner": ["happy", "Mountains of stock, you said? Unguarded?"],
		"sexton": ["happy", "A whole guild of candle-makers. They'll need tending."]},
	"beat_2_1": {
		"knight": "Worry not, Mother. My boots have excellent grip.",
		"founder": "It smells like the foundry. Like a thousand castings.",
		"witch": ["happy", "Wax melts. I'm a Taperwitch. This will be fun."],
		"runner": "Sinking floors. My favorite kind of getaway.",
		"sexton": ["happy", "Living drips! Can I keep one? Just a small one?"]},
	"beat_2_2": {
		"knight": "So small, and he still went down. A true knight of the Vigil.",
		"founder": ["hurt", "Dented all over, I bet. I could hammer it out for him."],
		"witch": ["fierce", "Littler than me? Who let him go alone?"],
		"runner": ["hurt", "I'll find it. I'll carry it. Someone should."],
		"sexton": "It'll be empty. Empty things can be filled again."},
	"beat_2_3": {
		"knight": "My flame isn't a burden. It's a promise.",
		"founder": "Quiet? I'm a bell-maker. I hate quiet.",
		"witch": "Tired? I'm only just getting warm.",
		"runner": "You don't get to take it. I'm the thief here.",
		"sexton": "I've sat with the quiet. It's lonely. Come back up."},
	"boss_2": {
		"knight": "No one? Then who said that, good sir?",
		"founder": "Then I'll ring that cone till someone answers.",
		"witch": "Let's see what's under that hat.",
		"runner": "Nice cone. I'm stealing it.",
		"sexton": "There's always someone in there. I'll dig him out."},
	"share": {
		"knight": "A flame shared is never lost. Take mine.",
		"founder": "Can't be lit? I light cold forges every morning. Come here.",
		"witch": ["fierce", "Watch me."],
		"runner": ["normal", "Here. First thing I've ever given away."],
		"sexton": "Hold still. It's easier than it looks."},
	"level_up": {
		"knight": "Stronger! For the Vigil!",
		"founder": "Heavier swing. Good.",
		"witch": "Hotter. Good.",
		"runner": "Quicker hands. Useful.",
		"sexton": "The wisps are brighter. Look at them."},
	"level_up_8": {    # the capstones open
		"knight": "A capstone, at last! I'll choose mine at the next altar.",
		"founder": "Capstones! Something big to cast. Next altar, I pick.",
		"witch": "Capstones open. Next altar, I'm taking the loud one.",
		"runner": "Capstones. Next altar, I take the best one. Quietly.",
		"sexton": "A capstone stirs in the flame. The next altar will hear me choose."},
	"level_up_16": {   # the Deep nodes open
		"knight": "The Deep lessons of the Vigil. Teach me, next altar.",
		"founder": "Deeper skills. Time to cast heavier. Next altar, then.",
		"witch": "Deep magic, finally. The next altar's going to be fun.",
		"runner": "Deeper tricks. I knew they were hiding more.",
		"sexton": "The deep roots open. I'll learn what the old dead knew."},
	"level_up_24": {   # Mastery opens
		"knight": "Mastery! Every lesson of the Vigil, in my hands.",
		"founder": "Mastery. Now I'm a real bellfounder.",
		"witch": "Mastery! Nothing's too hot for me now.",
		"runner": "Mastery. Best thief in the deep. Officially.",
		"sexton": "Mastery. The wisps sing louder for me now."},
	# ---- v3 (the story draft §3.7). In W3, W4 and W5 one calling each is
	# written to shine: the Sexton among the graves, the Bellfounder at the
	# reforging, the Taperwitch against the cold saint.
	"the_pull": {   # Hollin: "We share a flame now. I'll hear you through the smoke..."
		"knight": "Keep her warm, Hollin. I'll bring it home, on my honor.",
		"founder": "Then I'll go down and dig it back up. With my maul, if I must.",
		"witch": ["fierce", "It stole our candle? Oh, it's going to regret that."],
		"runner": ["fierce", "Something stole from us? Nobody steals from a thief."],
		"sexton": "Keep her warm. I'll go and fetch it back. Gently."},
	"world_3": {    # Waxley's salvage; the orchard
		"knight": "A garden of graves. We'll tread softly, good sir.",
		"founder": "Is that fruit? That's not fruit. That's a skull.",
		"witch": "Who buys a broken snuffer? ...How much, though?",
		"runner": ["hurt", "Hey. I was going to steal that cone."],
		"sexton": ["happy", "They gave every grave a tree. Oh, that's lovely."]},
	"beat_3_2": {   # "I stole it from her."
		"knight": "Then I'll carry her word too, Mother. And wear it well.",
		"founder": "Sprout. It suits me. I'm still growing.",
		"witch": "A secondhand nickname? Rude. I'm keeping it.",
		"runner": ["happy", "You stole it? Mother. I've never loved you more."],
		"sexton": "Then she's still here a little. In the word."},
	"beat_3_3": {   # "Stay, little one. Everyone stays." (a bark)
		"knight": ["fierce", "Forgive me, Mother Yarrow. I can't stay. I made a promise."],
		"founder": "Stay? I'd love to. But I've got a bell to ring.",
		"witch": "Everyone stays? Hard pass.",
		"runner": "Nobody keeps me anywhere. I always find the back door.",
		"sexton": "I tend graves. I don't stay in them."},
	"boss_3": {
		"knight": "Mother Yarrow! Let them rest, in the name of the Vigil!",
		"founder": "Let go, Mother. I'm heavier than I look.",
		"witch": "Roots, huh? I've got a trick for roots. It's called fire.",
		"runner": "Nobody ever held on to me. You won't be the first.",
		"sexton": "They're tired, Mother. Let me tuck them in."},
	"yarrow": {     # after "So old! And still so short."
		"knight": "Your garden kept them safe, Mother. Now it can rest.",
		"founder": ["happy", "Your trees are lovely. I only broke a few branches."],
		"witch": "I burned some of your roots. Sorry. They started it.",
		"runner": ["happy", "I didn't take any bones. Well. One. It was loose."],
		"sexton": "They'll sleep well now. I tucked in every one."},
	"world_4": {    # Hollin: "I stopped them first... I'm sorry, {hero}."
		"knight": "Sorry's the first step, Hollin. The rest all go down.",
		"founder": "Then we'll ring them again. Upside-down bells! Who cast these?",
		"witch": "Then I'll melt them loose. Good thing I'm a walking fireplace.",
		"runner": "Everybody's stolen something, Hollin. Yours was just quieter.",
		"sexton": "You're forgiven, Hollin. It was the quiet talking, not you."},
	"beat_4_3": {   # Taper's confession (a bark)
		"knight": "You didn't send me alone, Mother. You're in my smoke.",
		"founder": "Alone? I've got a maul, a flask and two voices in my head.",
		"witch": "Noted. I'm holding you to that.",
		"runner": "Nobody sent me. I volunteered. Mostly for the loot.",
		"sexton": "He isn't alone now. And neither are you."},
	"boss_4": {
		"knight": "Master Tickwell! Time marches on, sir. And so do I.",
		"founder": "Hold it? You don't hold a bell, sir. You let it ring.",
		"witch": "One minute? I only need one. Watch.",
		"runner": "A whole minute nobody's using? Finders keepers.",
		"sexton": "Even a minute needs to rest. Let this one go."},
	"tickwell": {   # "Then we'll both ring the next one."
		"knight": "Well said, sir. And this time, we'll be early.",
		"founder": ["happy", "The next one's mine, sir. I'm a Bellfounder."],
		"witch": "Ring it loud, you two. I'll do the glowing.",
		"runner": ["happy", "Nice watch. Just saying. Very nice watch."],
		"sexton": "Forty years in one minute. You must be so tired. Sit."},
	"world_5": {    # Taper rests her voice
		"knight": "Worry not, Mother. I'll carry us from here.",
		"founder": "Sleep, Mother. I'll be quiet. I'll try to be quiet.",
		"witch": "Rest, Mother. I'll keep the smoke warm for you.",
		"runner": "Rest. I'll nick you something shiny from up here.",
		"sexton": "Sleep, Mother. I'll sit with you when I'm back."},
	"beat_5_2": {   # "Doesn't it embarrass you?"
		"knight": "Never, madam. I'd sooner be small and smoky than cold.",
		"founder": "Smoke means it's working. Ask any foundry.",
		"witch": ["fierce", "Embarrass me? I'm the prettiest fire you'll ever see."],
		"runner": "Small's good. Small fits through windows.",
		"sexton": "It flickers because it's alive. Yours doesn't."},
	"boss_5": {
		"knight": "Saint or no, madam, you'll not put out a knight's candle.",
		"founder": "Glass! I like glass. It rings when you hit it.",
		"witch": "Pure light, huh? Let's see how pure you are on fire.",
		"runner": "A whole saint made of glass. Do you know what that's worth?",
		"sexton": "You're so cold, Saint. Let me warm you."},
	"tessel": {     # "It was the candle behind the glass."
		"knight": "Every window needs a candle, my lady. Happy to oblige.",
		"founder": "You're lovely lit. Hold still. Please don't crack.",
		"witch": ["happy", "Told you. The prettiest fire you'll ever see."],
		"runner": "So the glass gets the prayers, and the candle does the work?",
		"sexton": "There you are. Warm again."},
	"world_6": {    # "yours is the only flame. Keep it loud."
		"knight": "Then let it be the loudest flame there ever was.",
		"founder": "Loud? Easy. I've been told to keep it down my whole life.",
		"witch": "The only flame? Perfect. No competition.",
		"runner": "The only light in the dark. So everything knows where I am.",
		"sexton": "So still. Like a grave no one visits. I'll visit."},
	"beat_6_2": {   # "why is yours different?" The game's question, in five answers.
		"knight": "Because I promised Mother I'd keep it lit.",
		"founder": "Because I keep it fed. Same as a forge.",
		"witch": "Because every time it goes out, somebody lights it again.",
		"runner": "Because it's shared. You'd know, if anyone ever shared with you.",
		"sexton": "It isn't different. It just isn't alone."},
	"boss_6": {
		"knight": "Then I'll give you what you can't swallow: a knight's word.",
		"founder": "Hungry? I know hungry. Hungry's no excuse.",
		"witch": ["fierce", "Hungry? Here. Eat this."],
		"runner": "You took something of ours. I'm here to take it back.",
		"sexton": "You're not hungry. You're cold. I know the difference."},
	"give": {       # the moment before the hold
		"knight": "I promised to keep it lit. I never promised to keep it.",
		"founder": "Here. Everything in the forge. Take it.",
		"witch": ["fierce", "You don't get to take my fire. I'm giving it."],
		"runner": "Second thing I've ever given away. Don't tell anyone.",
		"sexton": "Don't be scared. It only goes dark for a little while."},
	"relit": {      # everyone's light, back into his
		"knight": ["happy", "Mother! You came all the way down!"],
		"founder": ["happy", "Everyone came! Did anyone bring supper?"],
		"witch": ["happy", "Told you. Somebody always lights it again."],
		"runner": ["happy", "You all came? For me? ...It's the smoke. I'm not crying."],
		"sexton": ["happy", "Even the old ones came. Look at them all. Nobody's lost."]},
	"homecoming": { # Taper: "Well done, {hero}."
		"knight": ["happy", "Thank you, Mother. The Vigil stands."],
		"founder": ["happy", "Thank you. Is it supper now? It feels like supper."],
		"witch": ["happy", "You said my name! Say it again. Louder."],
		"runner": ["happy", "You remembered my name? ...I thought I'd always be sprout."],
		"sexton": ["happy", "My name. I'll keep it somewhere safe."]},
	"waxworks_won": {  # Waxley, when a calling beats one of his casts (the draft's trial_won)
		"knight": "A Candleknight on my podium! Here's your prize. Polish it yourself.",
		"founder": "You broke my best cast. That's coming out of your prize.",
		"witch": "Fastest fire I ever saw. Now stop melting my stock.",
		"runner": "Too fast. Suspiciously fast. I'm checking my pockets.",
		"sexton": "You beat my cast, then swept up the drips. Unsettling."},
}

# Short lines in the HUD, over live play. Once per save unless the third
# entry is "every". The comment names where each one fires.
const BARKS := {
	"first_altar": ["taper:warm", "Feel that? Altars mend a flame. And they keep your place."],    # world._light_altar
	"first_relic": ["taper:warm", "A relic! It remembers its saint. The brighter, the stronger."],
	"first_sigil": ["taper:warm", "A saint's sigil! Three hide in every hall."],
	"first_item":  ["taper:warm", "Better gear goes on you, sprout. The rest waits in your satchel."],
	"first_elite": ["taper:worried", "That one glows. The Hush is thicker in it. Careful."],
	"first_dread": ["taper:stern", "A named one. Old and nasty. Worth it, if you win."],
	"first_hurt":  ["taper:worried", "Every hurt shrinks your flame, sprout. That flame is your life."],   # world._on_hurt
	"first_snuff": ["taper:warm", "Up you get, sprout. A flame that falls can rise."],               # world._update_dead
	"first_pool":  ["taper:warm", "Your embers spilled where you fell. Go and get them back."],
	"first_douse": ["taper:worried", "Wet wick! Your light's low till it dries."],
	"low_flame":   ["taper:worried", "Your flame's low! Drink from your flask, or find an altar."],
	"special_empty_founder": ["taper:warm", "Cold bell, sprout. Hit foes to build Heat, then slam it."],   # founder.special_pressed, short of Heat
	"skill_point": ["taper:warm", "You've grown, sprout. Spend your new point at an altar, or on the Sheet."],
	"tollgrave_angry": ["tollgrave:hushed", "Ring? No. NO. HUSH!", "every"],                    # boss phase 2
	"snuffer_angry":   ["snuffer:wrath", "Why won't it go out?", "every"],                     # boss phase 2
	"snuffer_dark":    ["taper:worried", "Only your light shows him now, sprout! Keep it bright!", "every"],
	"nightfall":   ["taper:stern", "The Hush sleeps, sprout. Its halls don't. Mind your flame."],   # main: the first level past Dusk
	"level_up":    ["wick:happy", "@level_up", "every"],                                         # L5, 10, 15...
	# A level-up that opens a tier says so instead (world._level_up: the
	# capstones at 8, the Deep nodes at 16, Mastery at 24; each a hero's once).
	"level_up_8":  ["wick:happy", "@level_up_8", "every"],
	"level_up_16": ["wick:happy", "@level_up_16", "every"],
	"level_up_24": ["wick:happy", "@level_up_24", "every"],
	# The rest of the level beats, played after (or instead of) their overlay.
	"beat_1_1_a":  ["taper:warm", "Hear me, sprout? Those skeletons were our choir. Stomp them. Gently."],
	"beat_1_1_b":  ["wick", "@beat_1_1"],
	"beat_1_2_a":  ["wick", "@beat_1_2"],
	"beat_1_2_b":  ["taper:stern", "Keep moving, sprout. Bats below, and archers. Mind your head."],
	"beat_1_3_a":  ["taper:warm", "Thornbacks ahead. Spikes on top. Don't jump on them. Hit them."],
	"beat_1_3_b":  ["taper:stern", "Fire isn't the enemy, sprout. Forgotten fire is."],
	"beat_2_2_a":  ["taper:stern", "Empty helmets are what the Hush likes to wear. Remember that."],
	"beat_2_3_a":  ["taper:sad", "That voice. Oh, Hollin. My poor boy."],
	"beat_2_3_b":  ["taper:stern", "And mind the moths. They drink light. Swat them off your flame."],
	"boss_2_a":    ["taper:stern", "He's hollow. Only light gives him a body. Keep the braziers lit."],
	# ---- World 3
	"beat_3_1_a": ["taper:faint", "Sprout? My voice is thin down there. Hollin's with me. He'll help."],
	"beat_3_1_b": ["hollin:grin", "Me again! Mother says I talk too much. I don't."],
	"beat_3_3_a": ["wick", "@beat_3_3"],
	"beat_3_3_b": ["hollin:worried", "Whatever took her is holding on tight. Don't let it hold you."],
	"boss_3_a":   ["taper:faint", "Follow her heart, sprout. It blooms where she can't guard it."],     # the rule hint
	"rootmother_p2": ["rootmother:wrath", "Mine! Every bone in this garden is MINE!", "every"],       # boss_phase
	"rootmother_p3": ["taper:faint", "She's letting go, sprout. Help her let go.", "every"],         # boss_phase
	"first_vine":  ["hollin:grin", "Vines! Hold jump to climb. Arrow and jump to leap off."],  # orchard.gd
	"first_spore": ["hollin:worried", "Spores drink light! Your flame shrinks in the cloud. Get out."],
	# ---- World 4
	"beat_4_1_a": ["hollin:grin", "Brr! I can feel the cold through your smoke. Keep moving, keep warm."],
	"beat_4_1_b": ["taper:faint", "Sprout... every clock down there says the same minute."],
	"beat_4_2_a": ["hollin:worried", "Whoever it is, they're stuck. Like I was. Let's find them."],
	"beat_4_3_a": ["wick", "@beat_4_3"],
	"beat_4_4_a": ["hollin:worried", "Ring the bell the clock points at. Then hit his spring."],          # the rule hint
	"boss_4_a":   ["tinker:ticking", "Stay in the minute, little light. Nothing ends in the minute."],
	"tinker_p2":  ["tinker:wrath", "Back! Wind it back! Back, back, BACK!", "every"],                  # boss_phase
	"tinker_p3":  ["hollin:worried", "The ice is cracking! It's nearly midnight, Wick!", "every"],     # boss_phase
	"first_ice":      ["hollin:grin", "Wax-ice! You'll slide. Stop early, and don't dash onto it."],   # clockwork.gd
	"first_rime":     ["hollin:grin", "Lean on the rime. Your flame melts it. A bright flame melts faster!"],
	"first_belt":     ["hollin:grin", "Belts! Run with them and you fly. Against them, it's a slog."],
	"first_gear":     ["hollin:grin", "Gears carry you round. Ride the teeth, mind the gaps."],
	"first_pendulum": ["hollin:worried", "Pendulums swing on a beat. Count it, then go."],
	"first_swing":    ["hollin:grin", "Ride the swing out. Jump at the far end."],
	# ---- World 5 (Taper resting: Hollin only)
	"beat_5_1_a": ["hollin:grin", "Mother's asleep. It's just us now. Try not to fall off anything."],
	"beat_5_1_b": ["hollin:worried", "Glass floating over nothing. Who builds like this?"],
	"beat_5_3_a": ["hollin:grin", "Look at her in the glass. A candle on her head. Just like yours!"],
	"boss_5_a":   ["hollin:worried", "Her beam bounces off mirrors. Keep one between you."],             # the rule hint
	"saint_p2":   ["saint:wrath", "Look at me! Only at me! I am the light!", "every"],                  # boss_phase
	"saint_p3":   ["hollin:worried", "Her glass is going dark. Keep your flame lit, Wick!", "every"],   # boss_phase
	"first_wind":      ["hollin:grin", "Wind! Jump with it and it carries you. Against it... don't."],   # glass.gd
	"first_glass":     ["hollin:worried", "That glass cracked! Don't stand on it long."],
	"first_dawnglass": ["hollin:worried", "That glass only holds in a lamp's light. Your flame won't do!"],
	# ---- World 6 (from 6-3 on, Hollin is quiet: only the Hush speaks)
	"beat_6_1_a": ["hollin:worried", "So quiet I can hear your flame. Altars are few down there. Go gently."],
	"beat_6_1_b": ["hush:open", "who are you, little light?"],
	"hush_p2":    ["hush:open", "you are so small.", "every"],                                         # boss_phase
	"hush_p3":    ["hush:open", "every light goes out. every one.", "every"],                          # boss_phase
	"hush_last":  ["hush:open", "...why won't it go out?", "every"],   # hush_boss.gd, at 15%: the Snuffer's words were its words
	"first_float":     ["hollin:worried", "Floats sink under you. Hop, don't stand!"],                   # deep.gd
	"first_buoy":      ["hollin:grin", "Ring a buoy and the water holds you. Not for long!"],
	"first_grasp":     ["hollin:worried", "Ripples mean hands. Wait on the stone till they sink."],
	"first_hush_zone": ["hollin:worried", "The quiet here drinks light and sound. Don't linger in it."],
	"first_candle":    ["hollin:grin", "Old Vigil candles! Light them. They stay lit for you."],
	"first_deepdark":  ["hollin:worried", "Deeper quiet here. Stay near anything that glows."],
	# The tide is 6-3's alone, after Hollin has gone quiet (beat_6_3): the Hush
	# teaches it, gloating (spec §6.5.7 gave it to Hollin; he isn't there).
	"first_tide":      ["hush:open", "run, little light. ring your little bells. they only hold me a moment."],
	# The finale in the level (hush_finale.gd; spec §5.5.6), one at a time in
	# the top message slot, and the Dusk checkpoint (hush_boss.gd).
	"hush_give_a": ["hush:open", "see? it went out. everything goes out.", "every"],
	"hush_give_b": ["hush:open", "give me yours, little light. it's all you have left.", "every"],
	"give":        ["wick", "@give", "every"],
	"hush_keep":   ["hush:open", "keep it, then. keep it all alone.", "every"],
	"hush_quiet":  ["hush:open", "...there. quiet at last.", "every"],
	"hush_remembers": ["hush:open", "i remember where you hurt me, little light.", "every"],
	# ---- Secret levels and the Lost Wicks (secrets.gd)
	"first_secret":    ["taper:warm", "A hidden way! Old Wicks made these. Something waits at the end."],
	"first_lost_wick": ["taper:sad", "A Lost Wick. One of ours who never came home. You lit their way."],
	"first_secret_hollin":    ["hollin:grin", "A hidden way! Mother says old Wicks made these. Let's see."],   # REST_SUBS
	"first_lost_wick_hollin": ["hollin:worried", "A Lost Wick. Like I nearly was. You lit their way home, Wick."], # REST_SUBS
	"first_secret_hush":      ["hush:open", "a hidden way. someone went down it before you. she never came up."],   # HUSH_SUBS (6-S after 6-3)
	"first_lost_wick_hush":   ["hush:open", "one of yours. i had her light long ago. now she has it back."],      # HUSH_SUBS
	"lost_wick_1": ["lamplighter", "Sixty years I lit the roof lamps. Take my light down with you."],
	"lost_wick_2": ["oldchandler", "Tell young Waxley he still owes me for a gross of tapers. Ha! Go on."],
	"lost_wick_3": ["gardenboy", "I planted the very first tree. Tell Mother Yarrow it grew."],
	"lost_wick_4": ["rook", "Rooks raised me. I never learned stairs. You won't need them either."],
	"lost_wick_5": ["solder", "I leaded every pane of her window. Every one still holds. So will you."],
	"lost_wick_6": ["abbess", "I stamped once, and the Hush flinched. Stamp once for me."],
	# The optional exit hints (spec §3.9), near each odd sight: every visit
	# (secrets.gd says each once a visit, until its secret is found).
	"secret_hint_1": ["taper:warm", "Is that moonlight? We're under a hill, sprout.", "every"],
	"secret_hint_2": ["waxley:shifty", "My guild's vault? Above the third lamp. Knock hard.", "every"],
	"secret_hint_3": ["taper:faint", "Spores don't fall up. Something above is breathing.", "every"],
	"secret_hint_4": ["hollin:grin", "The steam's going up. Clocks wind from the top, you know.", "every"],
	"secret_hint_5": ["hollin:grin", "A lamp with nothing to light? Light it anyway.", "every"],
	"secret_hint_6": ["hollin:worried", "That one isn't drowned. Listen. It's still ringing.", "every"],
	# Hers, in Hollin's voice, for a player back in 1-3 or 3-3 while she rests.
	"secret_hint_1_hollin": ["hollin:grin", "Is that moonlight? We're under a hill, {hero}!", "every"],
	"secret_hint_3_hollin": ["hollin:worried", "Spores don't fall up. Something up there is breathing.", "every"],
	# ---- The modes (modes/*.gd)
	"descent_5":  ["hollin:grin", "Five rooms down. It's dreaming of the cathedral. I know this bit."],
	"descent_10": ["hollin:worried", "Ten. The dreams get stranger from here. Mind your light."],
	"descent_20": ["taper:proud", "Twenty, sprout! No Wick ever walked a dream that deep."],
	"descent_30": ["hollin:worried", "Thirty. It's dreaming of the old dark, before any light."],
	"descent_40": ["tollgrave:kind", "Forty! I can hear your flame from up here. Just about."],
	"descent_50": ["hush:open", "...deeper than me, little light?"],
	"descent_record": ["hollin:grin", "Deeper than ever! Now mind you come back up.", "every"],
	"waxworks_won":  ["waxley:grin", "@waxworks_won", "every"],
	"waxworks_lost": ["waxley:shifty", "Ooh, so close. Again? My wax is very patient. I'm not.", "every"],
	# ---- Progression and screens
	"second_capstone": ["hollin:grin", "Two flames on one wick! Mother never managed that. Don't tell her."],
	"reserve_stocked": ["waxley:shifty", "Don't ask where I got it. Really. Don't."],
	# ---- A new calling (Taper's word, or Hollin's while she rests: REST_SUBS)
	"new_keeper":        ["taper:proud", "@taper_react", "every"],
	"new_keeper_hollin": ["hollin:grin", "A new {calling}! Mother's resting, so you get me. Welcome!", "every"],
}

# The results screen's line under the level name. Taper's show her faint
# portrait while she is faint (E7); W1 and W2 keep v2's lines, 2-4's on
# purpose ("Rest." plays just before the Hush strikes).
const AFTER := {
	"1-1": ["taper:warm", "One bell. I felt the old flame breathe, all the way up here."],
	"1-2": ["taper:warm", "Two bells. The chapel candles stood up straighter tonight."],
	"1-3": ["taper:proud", "You smell like a bonfire, sprout. That's three bells."],
	"1-4": ["taper:proud", "Four bells, and old Tollgrave home. I'm proud of you."],
	"2-1": ["taper:warm", "Two lamps lit in Lanternfold now. The baker cried."],
	"2-2": ["taper:sad", "Keep his helmet safe for me, sprout."],
	"2-3": ["taper:worried", "He's close. I can feel how cold he is."],
	"2-4": ["taper:proud", "Every bell. Every lamp. Go on, sprout. Rest."],
	"3-1": ["taper:faint", "A bell under the roots. I felt it, sprout. My ember felt it."],
	"3-2": ["taper:faint", "Two bells. Mother Yarrow's trees are listening."],
	"3-3": ["hollin:worried", "Mother's asleep in her chair. She smiled when that one rang."],
	"3-4": ["taper:faint", "Goodbye, Mother Yarrow. Sleep well. I'll water your trees."],
	"4-1": ["hollin:grin", "Mother says your bells taste like breakfast. She's a bit feverish."],
	"4-2": ["hollin:worried", "Every clock up here stopped too. The whole chapel's holding its breath."],
	"4-3": ["taper:faint", "Hollin's holding my hand, sprout. Tell no one. He'll get proud."],
	"4-4": ["tickwell:kind", "Right on time. Well. Forty years late. But right on time."],
	"5-1": ["hollin:grin", "One bell! Mother would say something wise. Something about flames."],
	"5-2": ["hollin:worried", "I can hear that wind through your smoke. Hold on tight."],
	"5-3": ["hollin:worried", "She was afraid, and went anyway. I never knew the saint was so small."],
	"5-4": ["hollin:relit", "She sang it to sleep. I wish I'd known a song."],
	"6-1": ["hollin:worried", "That one reached all the way up, {hero}. Mother's ember jumped."],
	"6-2": ["hollin:worried", "It can't swallow the bells you ring. Keep ringing, Wick."],
	"6-3": ["hush:open", "you rang another. why?"],
	"6-4": ["hollin:grin", "It's asleep. Really asleep. Listen. You can hear it breathing."],
	# The secret levels (spec §6.5.10): the Lost Wicks come home.
	"1-S": ["taper:warm", "The Lamplighter! Sixty years on that roof. He's home now, sprout."],
	"2-S": ["waxley:shifty", "My old master? He said that? ...He's right. I'll pay him. Eventually."],
	"3-S": ["taper:faint", "Mother Yarrow's first boy. She'd be so pleased."],
	"4-S": ["hollin:grin", "Brother Rook! Tickwell says he rang the carillon upside down. Twice."],
	"5-S": ["hollin:worried", "Sister Solder mended Tessel's window, pane by pane. Now she can rest."],
	"6-S": ["hollin:worried", "The Iron Abbess went nearest the Hush of anyone. Until you."],
}
# A secret level taken before its world's boss (4-S opens from 4-2, 5-S from
# 5-3): its results line mustn't name who the story hasn't met yet (Tickwell
# is in the Tinker's case until boss_4_after; the saint is Tessel only from
# boss_5_after). The rev5 review. [the scene that introduces them, the line
# before it]
const AFTER_BEFORE := {
	"4-S": ["boss_4_after", ["hollin:grin", "Brother Rook! They say he rang the carillon upside down. Twice."]],
	"5-S": ["boss_5_after", ["hollin:worried", "Sister Solder mended the saint's window, pane by pane. Now she can rest."]],
}
# From 6-3 on only the Hush speaks (Hollin has gone to fetch everyone for the
# finale): 6-S taken then, and the secret barks Hollin would say.
const AFTER_HUSH := {
	"6-S": ["hush:open", "the iron one came nearest of anyone. until you."],
}
const HUSH_SUBS := {"first_secret": "first_secret_hush", "first_lost_wick": "first_lost_wick_hush"}
# While Mother Taper rests her voice (world_5 until the finale), Hollin says
# the secret levels' lines that would be hers.
const AFTER_RESTING := {
	"1-S": ["hollin:grin", "The Lamplighter! Sixty years on that roof, and he's home now."],
	"3-S": ["hollin:grin", "The Gardener's Boy! His tree grew. I'll tell Mother when she wakes."],
}

# The Vigil Trials' medal lines (spec §6.5.9): Mother Taper's, and Hollin's
# while she rests. medal_line() picks.
const MEDAL_LINES := {
	"taper": {"bronze": "Well walked. Again?", "silver": "Better. Your flame knows the way now.",
		"gold": "Beautiful. I'd ring a bell for that.", "dawn": "I've never seen it done faster. Not even by me.",
		"none": "You got there. That's the first lesson."},
	"hollin": {"bronze": "You made it! Mother would say: again.", "silver": "Better! Your flame knows the way now.",
		"gold": "Beautiful. Mother would ring a bell for that.", "dawn": "I've never seen it done faster. Not even by her.",
		"none": "You got there. That's the first lesson, she says."},
}

# The words on each level's signs (the story draft §3.10, the secrets' re-keyed
# by spec §6.5.10), for the level streams to place in their hints, in x order.
# W3 gravestones, W4 Tickwell's brass notes, W5 the windows, W6 the Hush. One
# a level at most since the sign cut (the author's review: a lore line stands
# where he stops anyway, and a later scene pays it off); 4-2 has none.
const INSCRIPTIONS := {
	"3-1": ["Here lies Brother Pim. He kept the soup warm."],
	"3-2": ["Here lies Old Hobb. Planted crooked. Grew anyway."],
	"3-3": ["Here lies nobody yet. Mother Yarrow is patient."],
	"3-4": ["Here lies Mother Yarrow. Water the trees."],
	"4-1": ["Wind at eleven. Oil at half past. NEVER be late. — T."],
	"4-2": [],
	"4-3": ["I was one minute late. If I hold it, I never was. — T."],
	"4-4": ["Hold it. Hold it. Hold it. — T."],
	"5-1": ["A girl with a candle came down alone. She was afraid."],
	"5-2": ["She went anyway, with a song and no one to sing it to."],
	"5-3": ["She sang, and the dark slept."],
	"5-4": ["They made her a saint. She would have hated that."],
	"6-1": ["no one comes here. why did you?"],
	"6-2": ["i remember a song. i do not remember how it went."],
	"6-3": ["i ate the bells. they tasted of nothing."],
	"6-4": ["come closer. closer."],
	"1-S": ["Every dusk, a lamp. Every lamp, a little braver."],
	"2-S": ["No credit. No refunds. No Wick left in the dark."],
	"3-S": ["The first tree. Planted by a boy with a trowel."],
	"4-S": ["Rooks don't take stairs. Neither did he."],
	"5-S": ["Lead holds glass. Glass holds light. Hold on."],
	"6-S": ["She stamped once. The Hush remembers."],
}

const CREDITS := [["WAXBY", "title"], ["A game by Anthony Craig", "body"], ["Made with Claude", "body"],
	["Built with Godot", "body"], ["Every picture drawn in code. Every sound, too.", "body"], ["", ""],
	["Thank you for keeping the light.", "title"]]

# After v2's credit lines, the cast (the owner's answer, decisions.md): two
# pages, each a title over its people, every one with a small portrait.
# [who, mood, name, what they are]; "{hero}" and "{calling}" fill in.
const CAST_ROLL := [
	{"title": "The Cast", "cols": 4, "people": [
		["wick", "happy", "{hero}", "the {calling}"],
		["taper", "proud", "Mother Taper", "keeper of the chapel"],
		["hollin", "grin", "Hollin", "her first Wick"],
		["waxley", "grin", "Waxley", "chandler, no refunds"],
		["tessel", "gentle", "Tessel", "the girl who sang"],
		["yarrow", "merry", "Mother Yarrow", "the gardener-abbess"],
		["tickwell", "kind", "Master Tickwell", "keeper of the Downward Bells"],
		["lamplighter", "glow", "The Lost Wicks", "{lost_home}"]]},
	{"title": "And Every Boss", "cols": 3, "people": [
		["tollgrave", "kind", "Old Tollgrave", "The Bell Warden"],
		["snuffer", "cold", "The Snuffer", "The Hollow Wick"],
		["rootmother", "keeping", "Mother Gravebough", "The Bone Gardener"],
		["tinker", "ticking", "The Tinker of Hours", "The Frozen Minute"],
		["saint", "serene", "The Prism Saint", "The First Light"],
		["hush", "open", "The Hush", "The Hungry Quiet"]]},
]


# ---------------------------------------------------------------- lookups

static func scenes() -> Dictionary:
	var all := {}
	for s in SETS:
		all.merge(s)
	return all


static func has_scene(id: String) -> bool:
	for s in SETS:
		if (s as Dictionary).has(id):
			return true
	return false


static func scene(id: String) -> Dictionary:
	for s in SETS:
		if (s as Dictionary).has(id):
			return s[id]
	return {}


static func world_opener(world: int) -> String:
	return WORLD_OPENERS.get(world, "")


static func calling_name(cls: String) -> String:
	return Classes.ALL[cls]["name"] if Classes.ALL.has(cls) else "Wick"


static func longest_calling() -> String:
	var best := ""
	for cls in Classes.ALL:
		var n: String = Classes.ALL[cls]["name"]
		if n.length() > best.length():
			best = n
	return best


static func speaker(who: String, cls: String) -> Dictionary:
	## {name, color: Color, voice, blip, side, style, face} for a speaker id;
	## the hero's colour and voice come from his calling, his name plate from
	## the save (hero_name).
	var c: Dictionary = CAST.get(who, CAST["narrator"])
	var info: Dictionary = Classes.ALL.get(cls, Classes.ALL["knight"])
	var col = c["color"]
	var voice = c["voice"]
	return {"name": hero_name() if who == "wick" else c["name"], "color": Color(info["color"] if str(col) == "@class" else col),
			"voice": float(info["voice"]) if str(voice) == "@class" else float(voice),
			"blip": c.get("blip", ""), "side": c.get("side", "right"), "style": c.get("style", "box"),
			"face": face_of(who)}


static func face_of(who: String) -> String:
	## The portrait a speaker wears: its own, or its CAST "face" alias (the
	## six Lost Wicks share echo_glow).
	return str((CAST.get(who, {}) as Dictionary).get("face", who))


static func is_line(beat) -> bool:
	return beat is Array and beat.size() >= 2


static func class_line(slot: String, cls: String) -> Array:
	## [mood, text] for a calling ("" mood = the speaker's own).
	var lines: Dictionary = CLASS_LINES.get(slot, {})
	var e = lines.get(cls, lines.get("_", ""))
	if e is Array:
		return [str(e[0]), fill(str(e[1]), cls)]
	return ["", fill(str(e), cls)]


static func fill(text: String, cls: String) -> String:
	return text.replace("{calling}", calling_name(cls)).replace("{hero}", hero_name())


# ---------------------------------------------------------------- the hero's name
# One name a save (Game.hero_name): asked for at the oath (cutscene.gd's
# choose_name), changed on the Sheet (the Stats tab's Rename), Waxby until
# then and for every save made before there was a name to give.

static func hero_name() -> String:
	## The hero's own name: the save's, else HERO_NAME (no Game: a test or a
	## tool on its own).
	var g := _game()
	if g != null and g.has_method("hero_name"):
		return str(g.hero_name())
	return HERO_NAME


static func is_name_letter(ch: String) -> bool:
	## A letter of any alphabet (Godot's Unicode identifier start: no digits,
	## marks or emoji); "_" isn't one.
	return ch.length() == 1 and ch != "_" and ch.is_valid_unicode_identifier()


static func is_name_mark(ch: String) -> bool:
	## A combining mark (an accent typed on its own, a vowel sign): part of
	## the letter it follows.
	return ch.length() == 1 and ch.unicode_at(0) >= 0x300 and not is_name_letter(ch) and ("a" + ch).is_valid_unicode_identifier()


static func name_typed(text: String) -> String:
	## What the entry keeps of a name while it's typed: letters (and the
	## marks on them), spaces, apostrophes and hyphens (a phone's curly
	## apostrophe and its dashes made plain), no space first or two together,
	## at most NAME_MAX characters. A space at the end stays (the next word
	## is coming).
	var out := ""
	for raw in text:
		var ch: String = raw
		if ch in ["’", "‘", "\u02bc", "`", "´"]:   # (curly, modifier and stray apostrophes)
			ch = "'"
		elif ch in ["\u2010", "\u2011", "\u2013", "\u2014"]:   # (the hyphens and dashes a phone types)
			ch = "-"
		elif ch in ["\t", "\u00a0"]:   # (a tab, a no-break space)
			ch = " "
		if ch == " ":
			if out == "" or out.ends_with(" "):
				continue
		elif is_name_mark(ch):
			if out == "" or not (is_name_letter(out[-1]) or is_name_mark(out[-1])):
				continue
		elif ch != "'" and ch != "-" and not is_name_letter(ch):
			continue
		if out.length() >= NAME_MAX:
			break
		out += ch
	return out


static func clean_name(text) -> String:
	## A name fit to keep: name_typed's, trimmed; one with no letter in it (an
	## empty field, junk in a save) is HERO_NAME.
	var s := name_typed(str(text) if (text is String or text is StringName) else "").strip_edges()
	for ch in s:
		if is_name_letter(ch):
			return s
	return HERO_NAME


static func resolve(beat: Array, cls: String) -> Dictionary:
	## A line beat as {who, mood, text, shout}: "@slot" texts become the
	## calling's own line (with its mood when it names one).
	var tag: String = beat[0]
	var who := tag.get_slice(":", 0)
	var mood := tag.get_slice(":", 1) if tag.contains(":") else ""
	var text: String = beat[1]
	if text.begins_with("@"):
		var cl := class_line(text.substr(1), cls)
		if cl[0] != "":
			mood = cl[0]
		text = cl[1]
	else:
		text = fill(text, cls)
	if mood == "":
		mood = (MOODS.get(who, [""]) as Array)[0]
	var opts: Dictionary = beat[2] if beat.size() > 2 and beat[2] is Dictionary else {}
	return {"who": who, "mood": mood, "text": text, "shout": bool(opts.get("shout", false)), "at": str(opts.get("at", ""))}


static func lines_of(id: String, cls: String) -> Array:
	## Every line of a scene resolved for a calling (the tests, the Tales screen).
	var out := []
	for shot in scene(id).get("shots", []):
		for b in shot.get("beats", []):
			if is_line(b):
				out.append(resolve(b, cls))
	return out


static func slots_used() -> Array:
	## Every "@slot" named anywhere in the script.
	var out := []
	var add := func(t):
		if t is String and t.begins_with("@") and not out.has(t.substr(1)):
			out.append(t.substr(1))
	for id in scenes():
		for shot in scene(id).get("shots", []):
			for b in shot.get("beats", []):
				if is_line(b):
					add.call(b[1])
	for k in BARKS:
		add.call(BARKS[k][1])
	for k in AFTER:
		add.call(AFTER[k][1])
	for k in AFTER_RESTING:
		add.call(AFTER_RESTING[k][1])
	return out


# ---------------------------------------------------------------- barks and after-lines

static func bark_line(key: String, cls: String) -> Dictionary:
	## {who, mood, text, face, portrait, name} for a bark, or {} for an
	## unknown key (name: the speaker's plate, the hero's own for his).
	## Mother Taper speaks in her faint portrait while she is faint (E7).
	if not BARKS.has(key):
		return {}
	return _shown(resolve(BARKS[key], cls), cls)


static func _shown(r: Dictionary, cls: String) -> Dictionary:
	var who: String = r["who"]
	var mood: String = r["mood"]
	if who == "taper" and taper_phase() == "faint":
		mood = "faint"
	elif who == "taper" and mood == "faint" and taper_phase() == "tall":
		mood = "warm"   # (a W3-W4 line written faint, heard after the ending: she's tall now)
	return {"who": who, "mood": mood, "text": r["text"], "face": face_of(who), "portrait": portrait_path(who, mood, cls),
			"name": str(speaker(who, cls)["name"])}


static func bark_every(key: String) -> bool:
	## True for a bark that plays every time it fires ("every" in BARKS).
	return BARKS.has(key) and BARKS[key].size() > 2 and str(BARKS[key][2]) == "every"


static func bark_once(key: String) -> bool:
	## The gate for once-only barks: true the first time one is asked for
	## (marking it seen through Game as "bark:<key>"), false after that.
	## Always false for "every" barks and unknown keys.
	if not BARKS.has(key) or bark_every(key):
		return false
	var g := _game()
	if g == null:
		return true
	if g.seen("bark:" + key):
		return false
	g.mark_seen("bark:" + key)
	return true


static func bark_heard(key: String) -> bool:
	## A once-only bark heard already (asks without marking anything).
	var g := _game()
	return g != null and not bark_every(key) and g.seen("bark:" + key)


static func take_bark(key: String, cls: String, mark := true) -> Dictionary:
	## What the HUD calls: the line to show now ({who, mood, text, face,
	## portrait, name}), or {} when it's a once-only bark heard before. Marks
	## once-only barks seen. While Mother Taper rests, her REST_SUBS lines are
	## Hollin's (and hers counts as heard, so she doesn't say it later).
	## mark false (the feel lab, which writes nothing): the line alone,
	## nothing marked, so the slot still hears it for real in its level.
	if not BARKS.has(key):
		return {}
	if not bark_every(key) and bark_heard(key):
		return {}
	var said := rest_sub(key)
	if not BARKS.has(said):
		said = key
	if not mark:
		return {} if not bark_every(said) and bark_heard(said) else bark_line(said, cls)
	if not bark_every(said) and not bark_once(said):
		return {}
	if said != key and not bark_every(key):
		bark_once(key)
	return bark_line(said, cls)


static func after_line(level_id: String, cls: String) -> Dictionary:
	## {who, mood, text, face, portrait, name} for the results screen, or {}.
	if not AFTER.has(level_id):
		return {}
	var e: Array = AFTER[level_id]
	if taper_resting() and AFTER_RESTING.has(level_id):
		e = AFTER_RESTING[level_id]
	var g := _game()
	if AFTER_BEFORE.has(level_id) and g != null and not g.seen(str(AFTER_BEFORE[level_id][0])):
		e = AFTER_BEFORE[level_id][1]
	if AFTER_HUSH.has(level_id) and hollin_quiet():
		e = AFTER_HUSH[level_id]
	return _shown(resolve(e, cls), cls)


static func medal_line(medal: String) -> Dictionary:
	## A Vigil Trial's medal line ("bronze", "silver", "gold", "dawn", "none"):
	## {who, mood, text}, Mother Taper's, or Hollin's while she rests.
	var who := "hollin" if taper_resting() else "taper"
	var lines: Dictionary = MEDAL_LINES[who]
	if not lines.has(medal):
		return {}
	var mood := "grin" if who == "hollin" else ("faint" if taper_phase() == "faint" else "proud")
	return {"who": who, "mood": mood, "text": str(lines[medal]).replace("{hero}", hero_name())}


static func lost_wick_bark(w: int) -> String:
	## The bark a world's Lost Wick says at its grave candle.
	return "lost_wick_%d" % w if LOST_WICKS.has(w) else ""


static func portrait_path(who: String, mood: String, cls: String) -> String:
	## Where a speaker's portrait lives (it may not exist yet: see cutscene.gd).
	## A CAST "face" alias wins over the speaker's own id.
	if who == "wick":
		var m := mood if ["normal", "happy", "fierce", "hurt"].has(mood) else ("hurt" if ["worried", "sad"].has(mood) else "normal")
		return "res://art/heroes/%s/portrait_%s.svg" % [cls, m]
	return "res://art/story/portraits/%s_%s.svg" % [face_of(who), mood]


# ---------------------------------------------------------------- v3: flags, Mother Taper, the rest-subs
# A flag is kept in Game's seen list as "flag:<name>" (hush_given, set by
# hush_finale.gd); lost_wicks_all is derived (every Lost Wick heard), and
# modes_descent says the Endless Descent is in this build. Mother Taper's
# flame is her state (spec §6.2): well before the_pull, faint from it until
# boss_6_after, tall after; she rests her voice from world_5 until the
# finale, and while she does rest_sub() hands her lines to Hollin.

const REST_SUBS := {"new_calling": "new_calling_hollin", "new_keeper": "new_keeper_hollin", "first_secret": "first_secret_hollin",
		"first_lost_wick": "first_lost_wick_hollin", "trials_open": "trials_open_hollin",
		"secret_hint_1": "secret_hint_1_hollin", "secret_hint_3": "secret_hint_3_hollin"}
const TAPER_FLAME := {"well": 1.0, "faint": 0.35, "tall": 2.0}


static func flag(flag_name: String) -> bool:
	## A story flag set (hush_given), or a derived one (lost_wicks_all,
	## modes_descent).
	match flag_name:
		"lost_wicks_all":
			return lost_wicks_found() >= LOST_WICKS.size()
		"modes_descent":
			return ResourceLoader.exists(DESCENT_SCRIPT)
	var g := _game()
	return g != null and g.seen("flag:" + flag_name)


static func set_flag(flag_name: String) -> void:
	## Sets a story flag for good (saved with the story seen).
	var g := _game()
	if g != null and flag_name != "":
		g.mark_seen("flag:" + flag_name)


static func lost_home() -> String:
	## The Lost Wicks' caption in the cast roll, by how many came home.
	var n := lost_wicks_found()
	if n >= LOST_WICKS.size():
		return "six old keepers, home at last"
	if n == 0:
		return "six old keepers, still waiting"
	return "%s of six, home at last" % ["", "one", "two", "three", "four", "five"][n]


static func lost_wicks_found() -> int:
	## How many Lost Wicks have come home: "lost_wick:<w>" seen (record_result
	## marks it when a secret level is cleared), or their words heard.
	var g := _game()
	if g == null:
		return 0
	var n := 0
	for w in LOST_WICKS:
		if g.seen("lost_wick:%d" % w) or g.seen("bark:lost_wick_%d" % w):
			n += 1
	return n


static func taper_phase() -> String:
	## "well" before the_pull, "faint" from it until boss_6_after, "tall" after.
	## Also tall once homecoming is seen, or the flame was given and 6-4 is
	## cleared on Dusk (the rev5 review: an app killed in boss_6_after, which
	## plays after the clear is saved, left her faint and resting for good).
	var g := _game()
	if g == null:
		return "well"
	if g.seen("boss_6_after") or g.seen("homecoming"):
		return "tall"
	if g.seen("flag:hush_given") and g.has_method("level_record") and bool((g.level_record("6-4", "dusk") as Dictionary).get("cleared", false)):
		return "tall"
	if g.seen("the_pull"):
		return "faint"
	return "well"


static func taper_state() -> Dictionary:
	## Mother Taper's state for the scenes and the HUD: {} while she is well
	## (as v2, and the Phase 0 stub contract.md §9 froze), else {state:
	## "faint" | "tall", flame, resting, mood} (mood: the portrait her barks
	## and results lines wear, "" for her own). Spec §6.2's string form,
	## "well" | "faint" | "tall", is taper_phase().
	var p := taper_phase()
	if p == "well":
		return {}
	return {"state": p, "flame": TAPER_FLAME[p], "resting": taper_resting(), "mood": "faint" if p == "faint" else ""}


static func taper_flame() -> float:
	## Her flame's strength: 1.0 well, 0.35 faint, 2.0 tall (her portrait
	## flame's height is multiplied by it).
	return float(TAPER_FLAME[taper_phase()])


static func taper_resting() -> bool:
	## True while she rests her voice: from world_5 until the finale.
	var g := _game()
	return g != null and g.seen("world_5") and taper_phase() != "tall"


static func hollin_quiet() -> bool:
	## From 6-3's beat until the finale Hollin says nothing (he's gone to fetch
	## everyone): only the Hush speaks.
	var g := _game()
	return g != null and g.seen("beat_6_3") and taper_phase() != "tall"


static func scene_taper(id: String) -> String:
	## How Mother Taper's flame burns in a scene, by where it falls in the
	## story (so a replayed tale shows her as she was then): v2's scenes well,
	## the_pull through boss_6_after faint, homecoming and lullaby tall; the
	## modes' (and a new calling's, made at any point in a save) as she is now.
	if id in ["new_calling", "new_calling_hollin"]:
		return taper_phase()
	if id in ["homecoming", "lullaby"]:
		return "tall"
	if id == "the_pull" or SCENES_W3.has(id) or SCENES_W4.has(id) or SCENES_W5.has(id) or SCENES_W6.has(id):
		return "faint"
	if SCENES_W1.has(id) or SCENES_W2.has(id):
		return "well"
	return taper_phase()


static func rest_sub(id: String) -> String:
	## The scene or bark to play for id: Hollin's stand-in (REST_SUBS) while
	## she rests, else id itself.
	if hollin_quiet() and HUSH_SUBS.has(id):
		return str(HUSH_SUBS[id])
	if taper_resting() and REST_SUBS.has(id):
		return str(REST_SUBS[id])
	return id


static func rest_base(id: String) -> String:
	## Taper's scene or bark that Hollin's `id` stands in for (REST_SUBS), or "".
	for k in REST_SUBS:
		if str(REST_SUBS[k]) == id:
			return str(k)
	return ""


static func _game() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Game")
	return null
