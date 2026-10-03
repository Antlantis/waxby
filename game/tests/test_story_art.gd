extends SceneTree
## The story art's checks (W6c; v3 A5): art/story/panels.json parses and has
## the shape the cutscene player reads; every panel, figure and portrait the
## story names is there with the light, anchor and flame ids the script uses;
## every texture exists, rasterizes, is no wider than 4096 px and follows the
## px rule; flame points sit inside their frames and carry their kind (and
## the eyes their colour and a size that puts them in their sockets); portrait
## flames are arrays and sit inside the dialogue box's crop; every speaking
## figure faces whoever it talks to; the lamps of dawn_rise stand where
## Lanternfold's do; every figure anchor stands in a pool of light; the split
## moonlight works in the engine's strict depth order; panel layers import
## without mipmaps.
## v3: the ten deeper panels, fifteen figures and seventeen portraits; the
## E6 "off" lights (none on v2's art while cutscene.gd can't read them);
## every v3 shot's staging on the phone (the draft's cameras and cues, or
## story.gd's own once it has them): the faces of whoever speaks under the
## letterbox, above the dialogue box and clear of its portrait circles, no
## one straddling the view's edge, a walk ending where the next shot picks
## the actor up; the finale's busiest shot fits MAX_LIGHTS; the credits' cast
## roll has a portrait for everyone (and every story.gd CAST_ROLL entry's);
## the bosses' story figures are the fight's (A4's frames' colours, or its
## palette until they land).
##
##     godot --headless --path game --script res://tests/test_story_art.gd

const JSON_PATH := "res://art/story/panels.json"

# What story.gd (spec 7.3, trimmed by decisions.md) asks of each panel.
const PANELS := {
	"glass_legend": {"lights": [], "anchors": []},
	"lanternfold": {"lights": ["lamp1", "lamp2", "lamp3", "lamp4", "lamp5", "lamp6", "lamp7", "lamp8", "moon"], "anchors": []},
	"chapel": {"lights": ["lectern1", "lectern2", "lectern3", "hearth", "window"], "anchors": ["taper", "novice", "actor", "hollin"]},
	"callings": {"lights": ["plinth_knight", "plinth_founder", "plinth_witch", "plinth_runner", "plinth_sexton", "sconce_l", "sconce_r"], "anchors": []},
	"crypt_row": {"lights": ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8"], "anchors": ["far"]},
	"belfry": {"lights": ["bell_beam", "moon1", "moon2", "moon3"], "anchors": ["boss", "sit", "actor_after", "sill"]},
	"tallow_vista": {"lights": ["reed1", "reed2", "reed3", "reed4", "reed5", "reed6", "reed7", "reed8", "reed9", "reed10", "reed11", "reed12", "under_far", "moth"], "anchors": ["edge", "waxley"]},
	"undercandle": {"lights": ["under_flame", "reed1", "reed2", "reed3", "reed4"], "anchors": ["boss", "cone", "hollin", "actor_near"]},
	"bells_all": {"lights": ["bell1", "bell2", "bell3", "bell4", "bell5", "bell6", "bell7", "bell8", "under_flame"], "anchors": []},
	"dawn_rise": {"lights": ["lamp1", "lamp2", "lamp3", "lamp4", "lamp5", "lamp6", "lamp7", "lamp8", "sun"], "anchors": []},
	"hush_eye": {"lights": [], "anchors": ["eye", "float"]},
	# v3 (spec 6.6, the story draft 4.2; ids as the script lights them)
	"orchard_vista": {"lights": ["scorch1", "scorch2", "scorch3", "scorch4", "scorch5", "scorch6", "glowcap1", "glowcap2",
		"glowcap3", "glowcap4", "lantern"], "anchors": ["edge", "waxley", "cone"]},
	"heartwood": {"lights": ["cage1", "cage2", "cage3", "cage4", "cage5", "cage6", "kept1", "kept2", "kept3", "kept4", "kept5",
		"kept6", "trowel"], "anchors": ["boss", "spirit", "actor"]},
	"carillon_vista": {"lights": ["clock", "bell1", "bell2", "bell3", "bell4", "scorch", "ice1", "ice2", "ice3"], "anchors": ["edge", "waxley"]},
	"escapement": {"lights": ["clock", "pend", "bench_lamp", "forge"], "anchors": ["boss", "tickwell", "bench", "actor", "waxley"]},
	"sanctum_vista": {"lights": ["beam1", "beam2", "beam3", "beam4", "beam5", "glint1", "glint2", "glint3", "glint4"], "anchors": ["edge", "waxley"]},
	"glass_throne": {"lights": ["rose_center", "pane1", "pane2", "pane3", "pane4", "pane5", "pane6", "step1", "step2", "step3", "step4"],
		"anchors": ["saint", "actor"]},
	"glass_truth": {"lights": [], "anchors": []},
	"hushdeep_vista": {"lights": ["far_flame", "stair1", "stair2", "stair3", "stair4"], "anchors": ["edge"]},
	"hushdeep_heart": {"lights": ["stair1", "stair2", "stair3", "stair4", "stair5", "stair6"],
		"anchors": ["eye", "wick", "actor", "actor_give", "carry", "waxley", "tollgrave", "tickwell", "town", "lost"]},
	"homecoming": {"lights": ["lamp1", "lamp2", "lamp3", "lamp4", "lamp5", "lamp6", "lamp7", "lamp8", "bunting1", "bunting2", "bunting3",
		"bunting4", "bunting5", "bunting6", "bunting7", "bunting8", "bunting9", "bunting10", "rose", "sun"],
		"anchors": ["tollgrave", "taper", "hollin", "actor", "waxley", "tickwell"]},
}
# The art draft's extra panels, cut in decisions.md
const CUT_V3 := ["six_bells", "evenbell_noon", "keepers_wall", "descent_stair", "trial_hall"]
# E6: lights that start every shot dark until a cue lights them (panel.light,
# or figure.flame). No v2 light gains "off" (v2 shots need no edits).
const OFF := {"heartwood": ["kept1", "kept2", "kept3", "kept4", "kept5", "kept6"],
	"escapement": ["bench_lamp", "forge"],
	"glass_throne": ["pane1", "pane2", "pane3", "pane4", "pane5", "pane6", "step1", "step2", "step3", "step4"],
	"hushdeep_heart": ["stair1", "stair2", "stair3", "stair4", "stair5", "stair6"]}
const OFF_FIGS := {"hush_grasp": ["stolen"], "yarrow_spirit": ["head"], "tessel_lit": ["heart"], "stolen_wick": ["wick"],
	"deep_candle": ["wick"], "lost_wicks": ["w1", "w2", "w3", "w4", "w5", "w6"]}
# The "off" lights added to v2's art. A player that doesn't read "off" would
# light them in W2's own scenes (boss_2_after, post_credits), so story.py
# leaves them out of the manifest until scripts/cutscene.gd reads it (E6).
const OFF_V2 := {"undercandle": ["under_warm"]}
const OFF_V2_FIGS := {"hush_eye": ["pupil"]}
const V2_PANELS := ["glass_legend", "lanternfold", "chapel", "callings", "crypt_row", "belfry", "tallow_vista", "undercandle",
	"bells_all", "dawn_rise", "hush_eye"]
const V2_FIGS := ["novice_back", "taper_stand", "taper_chair", "taper_smoke", "waxley_pack", "tollgrave_boss", "tollgrave_sit",
	"snuffer_stand", "snuffer_reach", "cone_broken", "hollin_cold", "hollin_warm", "moth_swarm", "hush_eye"]
# Anchors only a cue-lit ("off") light reaches: what the cue reveals.
const CUE_LIT := {"escapement": ["bench"], "hushdeep_heart": ["town", "waxley", "carry", "tollgrave", "tickwell", "lost"]}
const CUT := ["spire", "tower_window", "deep_mouth", "helmet", "moth_face"]
# figure -> the flame names the script lights (anchor.name)
const FIGURES := {
	"novice_back": [], "taper_stand": ["head", "lantern"], "taper_chair": ["head"], "taper_smoke": [],
	"waxley_pack": ["brim1", "brim2", "brim3", "brim4", "brim5"], "tollgrave_boss": ["eyes"], "tollgrave_sit": ["eyes"],
	"snuffer_stand": ["eyes"], "snuffer_reach": ["eyes"], "cone_broken": [], "hollin_cold": [], "hollin_warm": ["head"],
	"moth_swarm": ["eyes"], "hush_eye": [],
	# v3 (spec 6.6: prism_boss is saint_boss)
	"hush_grasp": ["stolen"], "rootmother_boss": ["eyes", "ember"], "rootmother_open": ["eyes", "ember"],
	"yarrow_spirit": ["head", "aura"], "tinker_boss": ["eyes", "heart"], "tickwell": ["watch"], "cone_bell": ["rim"],
	"saint_boss": ["eyes", "halo", "prism"], "tessel_lit": ["heart", "eyes"], "stolen_wick": ["wick"],
	"hollin_carry": ["hollin", "taper"], "tollgrave_stand": ["eyes", "lantern"],
	"townsfolk_line": ["lamp1", "lamp2", "lamp3", "lamp4", "lamp5", "lamp6", "lamp7", "lamp8"], "deep_candle": ["wick"],
	"lost_wicks": ["w1", "w2", "w3", "w4", "w5", "w6"],
}
const MOODS := {"taper": ["warm", "worried", "stern", "sad", "proud", "faint"], "waxley": ["grin", "shifty", "shock"],
	"tollgrave": ["hushed", "kind"], "snuffer": ["cold", "wrath"], "hollin": ["lost", "relit", "worried", "grin"],
	"rootmother": ["keeping", "wrath"], "yarrow": ["gentle", "merry"], "tinker": ["ticking", "wrath"], "tickwell": ["dazed", "kind"],
	"saint": ["serene", "wrath"], "tessel": ["gentle", "sad"], "hush": ["open"], "echo": ["glow"]}
# Portraits with a live flame (the rest have none: a skull, a clock, glass, the Hush)
const LIVE := {"taper": 1, "waxley": 2, "yarrow": 1, "echo": 1}
# The credits' cast roll (the owner's Q5): everyone and every boss, a small
# portrait each (the Lost Wicks share echo; Waxby is the calling's own)
const CAST_ROLL := ["taper", "hollin", "waxley", "tessel", "yarrow", "tickwell", "echo", "tollgrave", "snuffer", "rootmother",
	"tinker", "saint", "hush"]
const KINDS := ["flame", "glow", "eyes", "cold"]
# cutscene.gd draws a pair of eyes from one point and a size h, EYE_GAP h apart
const EYE_GAP := 5.2
# the dialogue box's portrait crop (cutscene.gd _portrait): UV centre and radius
const CROP_C := Vector2(64, 62)
const CROP_R := 0.42 * 128.0
# Which way every anchor that holds a speaking figure faces (figures are drawn
# facing right; flip turns them left): toward whoever they talk to.
# panel -> anchor -> [flip, the anchor they face]
const FACING := {
	"chapel": {"taper": [false, "actor"], "novice": [true, "taper"], "hollin": [true, "actor"]},
	"crypt_row": {"far": [true, ""]},
	"belfry": {"boss": [true, "actor_after"], "sit": [true, "actor_after"], "sill": [true, "actor_after"]},
	"tallow_vista": {"waxley": [true, "edge"]},
	"undercandle": {"boss": [true, "actor_near"], "hollin": [true, "actor_near"]},
	"orchard_vista": {"waxley": [true, "edge"]},
	"heartwood": {"boss": [true, "actor"], "spirit": [true, "actor"]},
	"carillon_vista": {"waxley": [true, "edge"]},
	"escapement": {"boss": [true, "actor"], "tickwell": [true, "actor"], "waxley": [false, "tickwell"]},
	"sanctum_vista": {"waxley": [false, "edge"]},
	"homecoming": {"tollgrave": [false, "taper"], "taper": [false, "actor"], "hollin": [true, "taper"], "waxley": [true, "actor"],
		"tickwell": [true, "actor"]},
}
# The phone's view (cutscene.gd _xf_raw), its letterbox, and the dialogue box
# on the phone: UI.phone_safe (a 55 px inset each side, 17.7 of the home bar)
# and shot_story's 62 px notch. The box's top is safe.end.y - 102; its portrait
# circles (r 46 and their ring) sit centred 4 below it, 70 in from the safe
# edges: the hero's on the left, everyone else's on the right.
const VIEW := Vector2(847, 390)
const LETTERBOX := 28.0
const BOX_TOP := 390.0 - 17.7 - 102.0
const PORTRAITS := {"L": [Vector2(125, BOX_TOP + 4.0), Vector2(132, BOX_TOP + 4.0)],
	"R": [Vector2(715, BOX_TOP + 4.0), Vector2(722, BOX_TOP + 4.0)]}
const PORTRAIT_R := 52.0
# A face this far under the letterbox at least (its brow and eyes clear it)
const FACE_ROOM := 16.0
# Whose face a shot must show: the figures of whoever speaks in it (their
# speaker ids), the actor when the hero speaks, and the story's focal objects
# always. Figures this tall or shorter (and the actor, always) must not
# straddle the view's edge; bosses may, in a close-up.
const SPEAKS := {"waxley_pack": ["waxley"], "hollin_warm": ["hollin"], "hollin_cold": ["hollin"], "hollin_carry": ["hollin", "taper"],
	"taper_stand": ["taper"], "taper_chair": ["taper"], "tollgrave_stand": ["tollgrave"], "tollgrave_sit": ["tollgrave"],
	"tollgrave_boss": ["tollgrave"], "tickwell": ["tickwell"], "yarrow_spirit": ["yarrow"], "rootmother_boss": ["rootmother"],
	"rootmother_open": ["rootmother"], "tinker_boss": ["tinker"], "saint_boss": ["saint"], "tessel_lit": ["tessel"],
	"snuffer_stand": ["snuffer"], "snuffer_reach": ["snuffer"]}
const FOCAL_OBJECTS := ["stolen_wick", "deep_candle"]
const SMALL_H := 240.0
# Voices the draft gives from off the frame (the shot looks elsewhere).
const OFFSCREEN := ["boss_6_after/4 carry"]
# The v3 scenes' shots as the story draft stages them (p_story.md 3.1-3.5 with
# the spec's renames, as story.gd has them): panel, figures, actor, the
# camera's two ends, and the beats that move things (cam, walk, fig) among the
# speakers. story.gd's own are read instead once it has the v3 scenes.
const DRAFT_SHOTS := [
	{"id": "boss_3_after/0", "panel": "heartwood", "figs": {"boss": "rootmother_open", "spirit": "yarrow_spirit"}, "actor": "actor", "cam": [[0.5, 0.5, 1.0], [0.46, 0.58, 1.16]],
		"beats": [{"alpha": 1.0, "do": "fig", "fig": "spirit"}, "yarrow", "taper", "yarrow", "wick"],
		"fig_alpha": {"spirit": 0.0}},
	{"id": "boss_3_after/1", "panel": "heartwood", "figs": {"boss": "rootmother_open", "spirit": "yarrow_spirit"}, "actor": "actor", "cam": [[0.46, 0.55, 1.12], [0.5, 0.36, 1.0]],
		"beats": ["yarrow", "yarrow", "yarrow", {"alpha": 0.0, "do": "fig", "fig": "spirit", "move": [0, -80]}, {"alpha": 0.0,
		"do": "fig", "fig": "boss"}, "narrator"], "fig_alpha": {"boss": 0.5}},
	{"id": "boss_3_before/0", "panel": "heartwood", "figs": {"boss": "rootmother_boss"}, "actor": "", "cam": [[0.5, 0.45, 1.0], [0.58, 0.52, 1.22]],
		"beats": ["rootmother", "wick", "rootmother"]},
	{"id": "boss_4_after/0", "panel": "escapement", "figs": {"boss": "tinker_boss", "tickwell": "tickwell"}, "actor": "actor", "cam": [[0.5, 0.5, 1.0], [0.62, 0.55, 1.16]],
		"beats": [{"alpha": 0.0, "do": "fig", "fig": "boss"}, {"alpha": 1.0, "do": "fig", "fig": "tickwell"}, "tickwell",
		"tickwell", "hollin", "tickwell", "wick"], "fig_alpha": {"tickwell": 0.0}},
	{"id": "boss_4_after/1", "panel": "escapement", "figs": {"bench": "cone_broken", "tickwell": "tickwell", "waxley": "waxley_pack"}, "actor": "actor", "cam": [[0.6, 0.55, 1.1], [0.74, 0.55, 1.22]],
		"beats": ["waxley", "tickwell", "tickwell", "narrator"]},
	{"id": "boss_4_before/0", "panel": "escapement", "figs": {"boss": "tinker_boss"}, "actor": "", "cam": [[0.5, 0.5, 1.0], [0.56, 0.45, 1.25]],
		"beats": ["tinker", "wick", "tinker"]},
	{"id": "boss_5_after/0", "panel": "glass_throne", "figs": {"saint": "saint_boss"}, "actor": "actor", "cam": [[0.5, 0.5, 1.0], [0.5, 0.48, 1.12]],
		"beats": ["narrator", {"do": "walk", "to": 0.5}, "tessel", "tessel", "wick", "tessel"]},
	{"id": "boss_5_after/1", "panel": "glass_truth", "figs": {}, "actor": "", "cam": [[0.5, 0.56, 1.12], [0.5, 0.5, 1.0]],
		"beats": ["tessel", "tessel", "tessel", "hollin"]},
	{"id": "boss_5_after/2", "panel": "glass_throne", "figs": {"saint": "tessel_lit"}, "actor": "actor", "cam": [[0.5, 0.48, 1.12], [0.5, 0.72, 1.0]],
		"beats": ["tessel"]},
	{"id": "boss_5_before/0", "panel": "glass_throne", "figs": {"saint": "saint_boss"}, "actor": "", "cam": [[0.5, 0.45, 1.0], [0.5, 0.42, 1.22]],
		"beats": ["saint", "wick", "saint"]},
	{"id": "boss_6_after/0", "panel": "hushdeep_heart", "figs": {"eye": "hush_eye", "wick": "stolen_wick"}, "actor": "actor", "cam": [[0.62, 0.6, 1.0], [0.58, 0.66, 1.18]],
		"beats": ["hush", "hush", "wick", {"do": "walk", "to": 0.483}, "hush"], "fig_alpha": {"eye": 0.8}},
	{"id": "boss_6_after/1", "panel": "hushdeep_heart", "figs": {"carry": "hollin_carry", "eye": "hush_eye", "tickwell": "tickwell", "tollgrave": "tollgrave_stand", "town": "townsfolk_line", "waxley": "waxley_pack", "wick": "stolen_wick"}, "actor": "actor_give", "cam": [[0.58, 0.66, 1.18], [0.58, 0.66, 1.18]],
		"beats": ["hush", {"do": "cam", "to": [0.2, 0.42, 1.0]}, "taper", "taper", "waxley"], "fig_alpha": {"eye": 0.8}},
	{"id": "boss_6_after/2", "panel": "hushdeep_heart", "figs": {"carry": "hollin_carry", "eye": "hush_eye", "lost": "lost_wicks", "tickwell": "tickwell", "tollgrave": "tollgrave_stand", "town": "townsfolk_line", "waxley": "waxley_pack", "wick": "stolen_wick"}, "actor": "actor_give", "cam": [[0.3, 0.5, 1.05], [0.33, 0.52, 1.08]],
		"beats": ["taper"], "fig_alpha": {"eye": 0.8}},
	{"id": "boss_6_after/3", "panel": "hushdeep_heart", "figs": {"carry": "hollin_carry", "eye": "hush_eye", "tickwell": "tickwell", "tollgrave": "tollgrave_stand", "town": "townsfolk_line", "waxley": "waxley_pack", "wick": "stolen_wick"}, "actor": "actor_give", "cam": [[0.42, 0.58, 1.0], [0.55, 0.64, 1.16]],
		"beats": ["hollin", "wick"], "fig_alpha": {"eye": 0.8}},
	{"id": "boss_6_after/4", "panel": "hushdeep_heart", "figs": {"carry": "hollin_carry", "eye": "hush_eye", "tickwell": "tickwell", "tollgrave": "tollgrave_stand", "town": "townsfolk_line", "waxley": "waxley_pack", "wick": "stolen_wick"}, "actor": "actor_give", "cam": [[0.62, 0.55, 1.0], [0.78, 0.5, 1.12]],
		"beats": ["hollin", "hush", "hush", "narrator"], "fig_alpha": {"eye": 0.8}},
	{"id": "boss_6_before/0", "panel": "hushdeep_heart", "figs": {"eye": "hush_eye"}, "actor": "actor", "cam": [[0.62, 0.55, 1.0], [0.74, 0.5, 1.12]],
		"beats": ["hush", "wick", "hush"]},
	{"id": "homecoming/1", "panel": "homecoming", "figs": {"hollin": "hollin_warm", "taper": "taper_stand", "tickwell": "tickwell", "tollgrave": "tollgrave_stand", "waxley": "waxley_pack"}, "actor": "actor", "cam": [[0.22, 0.52, 1.1], [0.68, 0.52, 1.1]],
		"beats": ["taper", "tollgrave", "tickwell", "waxley"]},
	{"id": "homecoming/2", "panel": "homecoming", "figs": {"hollin": "hollin_warm", "taper": "taper_stand", "tickwell": "tickwell", "tollgrave": "tollgrave_stand", "waxley": "waxley_pack"}, "actor": "actor", "cam": [[0.43, 0.54, 1.2], [0.44, 0.55, 1.28]],
		"beats": ["taper", "wick", "taper", "taper"]},
	{"id": "lullaby/0", "panel": "hush_eye", "figs": {"eye": "hush_eye", "float": "deep_candle"}, "actor": "", "cam": [[0.5, 0.5, 1.0], [0.5, 0.52, 1.08]],
		"beats": [{"alpha": 1.0, "do": "fig", "fig": "float"}, "hush"], "fig_alpha": {"float": 0.0}},
	{"id": "the_pull/0", "panel": "undercandle", "figs": {"grasp": "hush_grasp", "hollin": "hollin_warm"}, "actor": "actor_near", "cam": [[0.5, 0.42, 1.0], [0.5, 0.62, 1.14]],
		"beats": ["hush", {"alpha": 1.0, "do": "fig", "fig": "grasp"}, {"do": "fig", "fig": "grasp", "move": [0, 420]}, "hush"],
		"fig_alpha": {"grasp": 0.0}},
	{"id": "the_pull/1", "panel": "lanternfold", "figs": {}, "actor": "", "cam": [[0.5, 0.5, 1.04], [0.5, 0.5, 1.0]],
		"beats": ["narrator"]},
	{"id": "the_pull/2", "panel": "chapel", "figs": {"taper": "taper_chair"}, "actor": "", "cam": [[0.42, 0.52, 1.1], [0.36, 0.55, 1.24]],
		"beats": ["taper", "taper"]},
	{"id": "the_pull/3", "panel": "undercandle", "figs": {"hollin": "hollin_warm"}, "actor": "actor_near", "cam": [[0.5, 0.78, 1.3], [0.5, 0.8, 1.38]],
		"beats": ["hollin", "hollin", "wick", "hollin"]},
	{"id": "world_3/0", "panel": "orchard_vista", "figs": {"cone": "cone_broken", "waxley": "waxley_pack"}, "actor": "edge", "cam": [[0.18, 0.55, 1.14], [0.22, 0.55, 1.1]],
		"beats": ["narrator", "waxley", "wick", {"do": "cam", "to": [0.62, 0.62, 1.0]}, "hollin"]},
	{"id": "world_4/0", "panel": "carillon_vista", "figs": {"waxley": "waxley_pack"}, "actor": "edge", "cam": [[0.5, 0.22, 1.12], [0.5, 0.24, 1.08]],
		"beats": ["waxley", {"do": "cam", "to": [0.5, 0.74, 1.0]}, "narrator", "hollin", "hollin", "wick"]},
	{"id": "world_5/0", "panel": "sanctum_vista", "figs": {"waxley": "waxley_pack"}, "actor": "edge", "cam": [[0.16, 0.55, 1.14], [0.2, 0.55, 1.1]],
		"beats": ["waxley", {"do": "cam", "to": [0.62, 0.48, 1.0]}, "narrator", "taper", "hollin", "wick"]},
	{"id": "world_6/0", "panel": "hushdeep_vista", "figs": {}, "actor": "edge", "cam": [[0.22, 0.55, 1.14], [0.6, 0.52, 1.0]],
		"beats": ["narrator", "hush", "hollin", "wick"]},
]
const V3_SCENES := ["the_pull", "lullaby"]

# The finale's busiest shot (boss_6_after 2b): its panel, figures and the actor
const BUSIEST := ["hushdeep_heart", {"eye": "hush_eye", "wick": "stolen_wick", "carry": "hollin_carry", "waxley": "waxley_pack",
	"tollgrave": "tollgrave_stand", "tickwell": "tickwell", "town": "townsfolk_line", "lost": "lost_wicks"}]
const MAX_LIGHTS := 48
# No panel's layers weigh more than v2's heaviest (the belfry, 71.7 MB of RGBA)
const PANEL_MB := 72.0
# The bosses' story figures are the fight's (spec 6.6: story_rootmother,
# story_tinker and story_saint draw them with boss3/4/5.py's parts): each
# uses nearly every colour of its fight frame (A4's) when that frame is here,
# and without it wears A4's palette (colours from boss3/4/5.py's constants).
# [figure, its fight frame, A4's palette colours it wears]
const BOSS_FIGHT := [
	["rootmother_boss", "res://art/enemies/rootmother_idle.svg",
		["#1e140e", "#a8977a", "#cbbd9f", "#e8dcc2", "#6e8a44", "#c9c1c6", "#ece2c6", "#a8d0ff", "#d8f0c0"]],
	["rootmother_open", "res://art/enemies/rootmother_die.svg",
		["#1e140e", "#a8977a", "#cbbd9f", "#e8dcc2", "#6e8a44", "#f2b84b", "#f0c4cc"]],
	["tinker_boss", "res://art/enemies/tinker_idle.svg",
		["#1c1208", "#c8983a", "#8a6424", "#4a4a5a", "#d8f0fc", "#f4f0e0", "#1a2440", "#9ad8f0", "#4a5a8a"]],
	["saint_boss", "res://art/enemies/saint_idle.svg",
		["#221c30", "#f2eff8", "#d8cfee", "#bfb0e0", "#aea2cc", "#f6f2fc", "#f8f0ff", "#fff4d8"]],
	["tessel_lit", "res://art/enemies/saint_die.svg",
		["#221c30", "#f6f2fc", "#e8506a", "#f0a830", "#4aa86a", "#3a6ac8", "#e8c050", "#c860a0"]],
]
const FIGHT_SHARE := 0.9

var _passed := 0
var _failed := 0
var data: Dictionary


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var text := FileAccess.get_file_as_string(JSON_PATH)
	_check(text != "", "panels.json exists")
	var parsed = JSON.parse_string(text)
	_check(typeof(parsed) == TYPE_DICTIONARY, "panels.json parses to a dictionary")
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish()
		return
	data = parsed
	for key in ["panels", "figures", "portraits"]:
		_check(data.has(key) and typeof(data[key]) == TYPE_DICTIONARY, "panels.json has %s" % key)
	_test_panels()
	_test_off()
	_test_staged()
	_test_busiest()
	_test_facing()
	_test_split_light()
	_test_dawn_lamps()
	_test_lit_anchors()
	_test_figures()
	_test_portraits()
	_test_cast_roll()
	_test_boss_palettes()
	_test_svgs()
	_test_imports()
	_finish()


func _finish() -> void:
	print("test_story_art: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# the SVG's width/height attributes, in pixels
func svg_size(res: String) -> Vector2:
	var text := FileAccess.get_file_as_string(res)
	var head := text.substr(0, 400)
	var rw := RegEx.new()
	rw.compile('width="([0-9.]+)" height="([0-9.]+)"')
	var m := rw.search(head)
	if m == null:
		return Vector2.ZERO
	return Vector2(float(m.get_string(1)), float(m.get_string(2)))


func _test_panels() -> void:
	var panels: Dictionary = data["panels"]
	_check(panels.size() == PANELS.size(), "there are %d panels (got %d)" % [PANELS.size(), panels.size()])
	for cut in CUT + CUT_V3:
		_check(not panels.has(cut), "cut panel %s is gone" % cut)
	for pid in PANELS:
		_check(panels.has(pid), "panel %s exists" % pid)
		if not panels.has(pid):
			continue
		var pn: Dictionary = panels[pid]
		var size: Vector2 = vec(pn["size"])
		_check(size.x >= 1000 and size.y >= 460, "%s is at least 1000 x 460" % pid)
		_check(pn.has("dark") and (pn["dark"] == null or (pn["dark"] as Array).size() == 3), "%s has a dark colour or null" % pid)
		var layers: Array = pn["layers"]
		_check(layers.size() >= 1, "%s has layers" % pid)
		var total_lit := 0
		for lay in layers:
			var tex: String = lay["tex"]
			_check(tex.begins_with("res://art/story/sets/") and FileAccess.file_exists(tex), "%s layer %s exists" % [pid, tex])
			var px: float = float(lay["px"])
			var depth: float = float(lay["depth"])
			var rect: Array = lay["rect"]
			var sz := svg_size(tex)
			_check(sz.x <= 4096.0, "%s is at most 4096 px wide (%d)" % [tex, sz.x])
			_check(absf(sz.x - float(rect[2]) * px) <= 1.0 and absf(sz.y - float(rect[3]) * px) <= 1.0,
				"%s is rect x px (%s vs %s x %s)" % [tex, sz, rect, px])
			if depth <= 0.7:
				_check(px <= 2.0, "%s at depth %s uses px <= 2" % [tex, depth])
			else:
				_check(px >= 2.0, "%s at depth %s is sharp enough (px %s)" % [tex, depth, px])
			if depth > 1.0:
				# near layers reach past the panel so parallax never shows their edge
				var r := Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
				var covers := r.position.y <= 0.0 and r.end.y >= size.y
				_check(covers, "near layer %s reaches past the panel's top and bottom" % tex)
			if lay.get("lit", false):
				total_lit += 1
		var lights: Dictionary = pn["lights"]
		for lid in PANELS[pid]["lights"]:
			_check(lights.has(lid), "%s has light %s" % [pid, lid])
		for lid in lights:
			var L: Dictionary = lights[lid]
			var p := vec(L["p"])
			_check(Rect2(Vector2.ZERO, size).has_point(p), "%s light %s is inside the panel" % [pid, lid])
			_check(KINDS.has(L["kind"]), "%s light %s has a known kind" % [pid, lid])
			_check(float(L["r"]) > 0.0 and float(L["s"]) > 0.0 and float(L["s"]) <= 1.0, "%s light %s has r and s" % [pid, lid])
			if L["kind"] == "flame" or L["kind"] == "cold":
				_check(float(L.get("h", 0.0)) > 0.0, "%s flame %s has a height" % [pid, lid])
			if L["kind"] == "eyes":
				_check(float(L.get("h", 0.0)) > 0.0, "%s eyes %s have a size" % [pid, lid])
				_check(str(L.get("color", "")) != "", "%s eyes %s have a colour" % [pid, lid])
				var pts: Array = L.get("pts", [])
				if pts.size() == 2:
					_check(absf(vec(pts[0]).distance_to(vec(pts[1])) - EYE_GAP * float(L["h"])) < 0.5,
						"%s eyes %s sit EYE_GAP h apart" % [pid, lid])
			if L.has("tint"):
				_check(L.get("color", "") == L["tint"], "%s light %s gives its tint as color" % [pid, lid])
		var anchors: Dictionary = pn["anchors"]
		for aid in PANELS[pid]["anchors"]:
			_check(anchors.has(aid), "%s has anchor %s" % [pid, aid])
		for aid in anchors:
			var a: Dictionary = anchors[aid]
			_check(Rect2(Vector2.ZERO, size).has_point(vec(a["p"])), "%s anchor %s is inside the panel" % [pid, aid])
	# glass_legend: its three lancet tiles cover the whole width between them
	if panels.has("glass_legend"):
		var gl: Dictionary = panels["glass_legend"]
		var w := 0.0
		for lay in gl["layers"]:
			if String(lay["tex"]).contains("_glass_"):
				w += float(lay["rect"][2])
		_check(absf(w - 2400.0) < 0.5, "glass_legend's lancet tiles span 2400 units (%s)" % w)
		_check(gl["dark"] == null and gl.get("shimmer", false), "glass_legend has no darkness and shimmers")
	# the class picker's plinths: one light per calling id
	var classes := ["knight", "founder", "witch", "runner", "sexton"]
	var cl: Dictionary = panels.get("callings", {}).get("lights", {})
	for c in classes:
		_check(cl.has("plinth_" + c), "callings lights plinth_%s" % c)


# Whether the cutscene player reads a light's "off" (E6).
func reads_off() -> bool:
	return FileAccess.get_file_as_string("res://scripts/cutscene.gd").contains('get("off"')


# E6: the lights a v3 scene lights by cue start dark ("off"); v2's never do.
# v2's art carries an "off" light only once cutscene.gd reads "off" (else W2's
# own scenes would show it lit).
func _test_off() -> void:
	var panels: Dictionary = data["panels"]
	var figs: Dictionary = data["figures"]
	var e6 := reads_off()
	for pid in OFF:
		for lid in OFF[pid]:
			var L: Dictionary = panels.get(pid, {}).get("lights", {}).get(lid, {})
			_check(L.get("off", false) == true, "%s light %s starts off" % [pid, lid])
	for fid in OFF_FIGS:
		for name in OFF_FIGS[fid]:
			var ld: Dictionary = figs.get(fid, {}).get("light", {}).get(name, {})
			_check(ld.get("off", false) == true, "figure %s light %s starts off" % [fid, name])
	for pid in V2_PANELS:
		var lights: Dictionary = panels.get(pid, {}).get("lights", {})
		for lid in lights:
			var off: bool = lights[lid].get("off", false)
			if not e6:
				_check(not off, "v2's %s light %s isn't off while cutscene.gd can't read it (W2's scenes would show it lit)" % [pid, lid])
			elif not (OFF_V2.get(pid, []) as Array).has(lid):
				_check(not off, "v2's %s light %s is not turned off" % [pid, lid])
		for lid in OFF_V2.get(pid, []):
			if lights.has(lid):
				_check(lights[lid].get("off", false) == true, "%s light %s starts off" % [pid, lid])
			elif e6:
				print("  note: %s light %s is held back (cutscene.gd reads \"off\" now: rebuild the story art)" % [pid, lid])
	for fid in V2_FIGS:
		var fl: Dictionary = figs.get(fid, {}).get("light", {})
		for name in fl:
			var off: bool = fl[name].get("off", false)
			if not e6:
				_check(not off, "v2's figure %s light %s isn't off while cutscene.gd can't read it" % [fid, name])
			elif not (OFF_V2_FIGS.get(fid, []) as Array).has(name):
				_check(not off, "v2's figure %s light %s is not turned off" % [fid, name])
		for name in OFF_V2_FIGS.get(fid, []):
			if fl.has(name):
				_check(fl[name].get("off", false) == true and figs[fid]["flames"].has(name), "figure %s light %s starts off" % [fid, name])
			elif e6:
				print("  note: figure %s light %s is held back (rebuild the story art)" % [fid, name])
	# the undercandle's grasp closes on the flame: its stolen light sits on the
	# Undercandle's (under_warm, where under_flame burns cold)
	var uc: Dictionary = panels.get("undercandle", {})
	var gr: Dictionary = figs.get("hush_grasp", {})
	if uc.has("anchors") and uc["anchors"].has("grasp") and gr.has("flames"):
		var a: Dictionary = uc["anchors"]["grasp"]
		var k: float = float(a.get("h", gr["h"])) / 256.0
		var q: Array = gr["flames"]["stolen"]
		var at := vec(a["p"]) + (Vector2(float(q[0]), float(q[1])) - vec(gr["feet"])) * k
		var warm := vec(uc["lights"].get("under_warm", uc["lights"]["under_flame"])["p"])
		_check(at.distance_to(warm) < 24.0, "the grasp closes on the Undercandle's flame (%s vs %s)" % [at, warm])


# The camera's view of a panel plane (cutscene.gd _xf_raw, without the drift):
# where a panel point at depth d lands on the phone, as a fraction of the view.
func view_frac(size: Vector2, cam: Array, d: float, pt: Vector2) -> Vector2:
	var s0 := maxf(VIEW.x / size.x, VIEW.y / size.y)
	var z := maxf(float(cam[2]), 1.0)
	var hv := VIEW / (2.0 * s0 * z)
	var c := Vector2(float(cam[0]) * size.x, float(cam[1]) * size.y)
	c.x = size.x * 0.5 if hv.x * 2.0 >= size.x else clampf(c.x, hv.x, size.x - hv.x)
	c.y = size.y * 0.5 if hv.y * 2.0 >= size.y else clampf(c.y, hv.y, size.y - hv.y)
	var P := size * 0.5
	var sd := s0 * (1.0 + (z - 1.0) * d)
	var cd := P + (c - P) * d
	var scr := VIEW * 0.5 + (pt - cd) * sd
	return Vector2(scr.x / VIEW.x, scr.y / VIEW.y)


# The v3 shots to stage: story.gd's own once it has the v3 scenes (after the
# merge), else the draft's (DRAFT_SHOTS), in the same shape.
func v3_shots() -> Array:
	var St = load("res://scripts/story.gd")
	var sc: Dictionary = St.scenes() if St != null else {}
	if not sc.has("boss_3_after"):
		print("  staging: the draft's shots (story.gd has no v3 scenes yet)")
		return DRAFT_SHOTS
	print("  staging: story.gd's shots")
	var out := []
	for sid in sc:
		var shots: Array = (sc[sid] as Dictionary).get("shots", [])
		for i in shots.size():
			var shot: Dictionary = shots[i]
			var pid := str(shot.get("panel", ""))
			if pid == "" or not (PANELS.has(pid) and not V2_PANELS.has(pid) or V3_SCENES.has(sid)):
				continue
			var beats := []
			for bt in shot.get("beats", []):
				if bt is Array:
					beats.append(str(bt[0]).get_slice(":", 0))
				elif bt is Dictionary and ["cam", "walk", "fig"].has(str(bt.get("do", ""))):
					beats.append(bt)
			var e := {"id": "%s/%d" % [sid, i], "panel": pid, "figs": shot.get("figs", {}), "actor": str(shot.get("actor", "")),
				"cam": shot.get("cam", [[0.5, 0.5, 1.0], [0.5, 0.5, 1.0]]), "beats": beats}
			if shot.has("fig_alpha"):
				e["fig_alpha"] = shot["fig_alpha"]
			out.append(e)
	return out


# A figure's drawn box in its frame (alpha over a half), cached.
var _boxes := {}


func fig_box(fid: String) -> Rect2:
	if _boxes.has(fid):
		return _boxes[fid]
	var r := Rect2(0, 0, 256, 256)
	var f: Dictionary = data["figures"].get(fid, {})
	var img := Image.new()
	if not f.is_empty() and img.load_svg_from_string(FileAccess.get_file_as_string(f["tex"]), 128.0 / (256.0 * float(f["px"]))) == OK:
		var x0 := 999
		var y0 := 999
		var x1 := -1
		var y1 := -1
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					x0 = mini(x0, x)
					x1 = maxi(x1, x)
					y0 = mini(y0, y)
					y1 = maxi(y1, y)
		if x1 >= 0:
			r = Rect2(x0 * 2.0, y0 * 2.0, (x1 - x0 + 1) * 2.0, (y1 - y0 + 1) * 2.0)
	_boxes[fid] = r
	return r


# Where a figure's face is, in its frame: between its eyes, or (no eyes) a
# third of the way down from the top of what is drawn to the feet (the chibi
# head).
func fig_face(fid: String) -> Vector2:
	var f: Dictionary = data["figures"].get(fid, {})
	var q = f.get("flames", {}).get("eyes", null)
	if q is Array:
		return Vector2(float(q[0]), float(q[1]))
	var r := fig_box(fid)
	return Vector2(float(f["feet"][0]), r.position.y + (float(f["feet"][1]) - r.position.y) * 0.3)


func _near_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# Focal points on the phone: through every v3 shot (at the camera's start, its
# end and every cam cue's target, with the actor where walks take him and the
# figures faded in and out as the beats do it), the face of everyone who
# speaks in it (and of its focal objects) sits, whenever it is in view, under
# the letterbox and above the dialogue box, clear of the portrait circle of
# each side that speaks (the actor's face clear of them always); the actor,
# and every figure no taller than SMALL_H
# that is checked, never straddles the view's edge; each is in full view
# somewhere in the shot; and a walk ends where the next shot's actor stands.
func _test_staged() -> void:
	var panels: Dictionary = data["panels"]
	var figs: Dictionary = data["figures"]
	var n := 0
	var shots := v3_shots()
	for si in shots.size():
		var sh: Dictionary = shots[si]
		var pid: String = sh["panel"]
		if not panels.has(pid):
			continue
		n += 1
		var size := vec(panels[pid]["size"])
		var anchors: Dictionary = panels[pid]["anchors"]
		var sides := {}
		var speakers := {}
		for bt in sh["beats"]:
			if bt is String and bt != "narrator" and bt != "hush":
				sides["L" if bt == "wick" else "R"] = true
				speakers[bt] = true
		# who stands where: {anchor: [figure id, alpha, moved]}; the actor's x
		var cast := {}
		for aid in sh["figs"]:
			var fid := str(sh["figs"][aid])
			if not anchors.has(aid) or not figs.has(fid):
				continue
			var checked := FOCAL_OBJECTS.has(fid)
			for who in SPEAKS.get(fid, []):
				checked = checked or speakers.has(who)
			if checked:
				cast[aid] = [fid, float(sh.get("fig_alpha", {}).get(aid, 1.0)), Vector2.ZERO]
		var actor: String = sh["actor"]
		var ax := float(anchors[actor]["p"][0]) if anchors.has(actor) else 0.0
		# the moments: the camera's start, each cam cue's target, its end
		var moments := [[sh["cam"][0], cast.duplicate(true), ax]]
		for bt in sh["beats"]:
			if not bt is Dictionary:
				continue
			match str(bt["do"]):
				"fig":
					if cast.has(bt["fig"]):
						if bt.has("alpha"):
							cast[bt["fig"]][1] = float(bt["alpha"])
						if bt.has("move"):
							cast[bt["fig"]][2] += vec(bt["move"])
				"walk":
					ax = float(bt["to"]) * size.x
					# the next shot of the scene picks the actor up where the walk left him
					if si + 1 < shots.size() and str(shots[si + 1]["id"]).get_slice("/", 0) == str(sh["id"]).get_slice("/", 0):
						var nx: String = shots[si + 1]["actor"]
						if anchors.has(nx) and shots[si + 1]["panel"] == pid:
							_check(absf(ax - float(anchors[nx]["p"][0])) < 12.0,
								"%s: the walk ends where the next shot's actor stands (%s at %.0f, the walk at %.0f)" % [
								sh["id"], nx, float(anchors[nx]["p"][0]), ax])
				"cam":
					moments.append([bt["to"], cast.duplicate(true), ax])
		moments.append([sh["cam"][1], cast.duplicate(true), ax])
		var seen := {}
		for m in moments:
			var cam: Array = m[0]
			var who := {}
			for aid in m[1]:
				if float(m[1][aid][1]) > 0.05:
					who[aid] = m[1][aid]
			if anchors.has(actor):
				who["@" + actor] = ["", 1.0, Vector2.ZERO]
			for aid in who:
				var an: Dictionary = anchors[aid.trim_prefix("@")]
				var d := float(an.get("depth", 1.0))
				var feet: Vector2 = vec(an["p"]) + (who[aid][2] as Vector2)
				var face: Vector2
				var x0: float
				var x1: float
				var tall: float
				var faced := true
				if aid.begins_with("@"):
					# the actor: the cutscene's face point (h 0.47 over his feet), h / 2 wide
					var h := float(an.get("h", 120.0))
					feet.x = m[2]
					face = feet - Vector2(0, h * 0.47)
					x0 = feet.x - h * 0.25
					x1 = feet.x + h * 0.25
					tall = h
					faced = speakers.has("wick")
				else:
					var fid: String = who[aid][0]
					var f: Dictionary = figs[fid]
					var k := float(an.get("h", f["h"])) / 256.0
					var sx := -1.0 if an.get("flip", false) else 1.0
					var fe := vec(f["feet"])
					var box := fig_box(fid)
					var fc := fig_face(fid)
					face = feet + Vector2((fc.x - fe.x) * sx, fc.y - fe.y) * k
					var ea: float = feet.x + (box.position.x - fe.x) * sx * k
					var eb: float = feet.x + (box.end.x - fe.x) * sx * k
					x0 = minf(ea, eb)
					x1 = maxf(ea, eb)
					tall = (fe.y - box.position.y) * k
				var fv := view_frac(size, cam, d, face)
				var l := view_frac(size, cam, d, Vector2(x0, feet.y)).x
				var r := view_frac(size, cam, d, Vector2(x1, feet.y)).x
				var top := view_frac(size, cam, d, Vector2(feet.x, feet.y - tall)).y
				var bottom := view_frac(size, cam, d, feet).y
				if r < 0.0 or l > 1.0 or bottom < 0.0 or top > 1.0:
					continue
				var where := "%s %s at cam %s" % [sh["id"], aid.trim_prefix("@"), cam]
				if tall <= SMALL_H:
					_check(l >= -0.005 and r <= 1.005, "%s: the figure doesn't straddle the view's edge (%.2f..%.2f)" % [where, l, r])
				if fv.x < 0.0 or fv.x > 1.0:
					continue
				if faced:
					seen[aid] = true
				if sides.is_empty():
					continue
				# (the hero's face stays clear of the portraits even when he listens)
				if faced:
					_check(fv.y >= (LETTERBOX + FACE_ROOM) / VIEW.y and fv.y <= BOX_TOP / VIEW.y,
						"%s: the face is between the letterbox and the box (%.2f down the view)" % [where, fv.y])
				var px := Vector2(fv.x * VIEW.x, fv.y * VIEW.y)
				for side in sides:
					var c: Array = PORTRAITS[side]
					_check(_near_segment(px, c[0], c[1]) > PORTRAIT_R,
						"%s: the face is clear of the %s portrait (%.0f px from it)" % [where, side, _near_segment(px, c[0], c[1])])
		for aid in cast:
			if not OFFSCREEN.has("%s %s" % [sh["id"], aid]):
				_check(seen.has(aid), "%s %s is in view in its shot" % [sh["id"], aid])
		if anchors.has(actor) and speakers.has("wick"):
			_check(seen.has("@" + actor), "%s the actor (%s) is in view in its shot" % [sh["id"], actor])
	_check(n >= 20, "the v3 shots are staged (%d)" % n)


# The finale's busiest shot fits the cutscene's lights (MAX_LIGHTS 48).
func _test_busiest() -> void:
	var panels: Dictionary = data["panels"]
	var figs: Dictionary = data["figures"]
	if not panels.has(BUSIEST[0]):
		return
	var n: int = (panels[BUSIEST[0]]["lights"] as Dictionary).size() + 1
	for a in BUSIEST[1]:
		n += (figs.get(BUSIEST[1][a], {}).get("flames", {}) as Dictionary).size()
	_check(n <= MAX_LIGHTS, "the finale's busiest shot has %d lights (at most %d)" % [n, MAX_LIGHTS])
	print("  the finale's busiest shot: %d lights" % n)
	# texture weight per panel (a layer is rect x px square, RGBA): at most 2 panels are resident
	var heaviest := ""
	var most := 0.0
	for pid in panels:
		var mb := 0.0
		for lay in panels[pid]["layers"]:
			var r: Array = lay["rect"]
			mb += float(r[2]) * float(lay["px"]) * float(r[3]) * float(lay["px"]) * 4.0 / 1e6
		_check(mb <= PANEL_MB, "%s's layers weigh %.1f MB (at most %.0f)" % [pid, mb, PANEL_MB])
		if mb > most and not V2_PANELS.has(pid):
			most = mb
			heaviest = pid
	print("  the heaviest v3 panel: %s, %.1f MB" % [heaviest, most])


# Every figure is drawn facing right; an anchor's flip turns it left. Each
# anchor holding a speaking figure faces whoever it talks to.
func _test_facing() -> void:
	var panels: Dictionary = data["panels"]
	for pid in FACING:
		if not panels.has(pid):
			continue
		var anchors: Dictionary = panels[pid]["anchors"]
		for aid in FACING[pid]:
			if not anchors.has(aid):
				continue
			var want: bool = FACING[pid][aid][0]
			var flip: bool = anchors[aid].get("flip", false)
			_check(flip == want, "%s %s faces %s" % [pid, aid, "left" if want else "right"])
			var other: String = FACING[pid][aid][1]
			if other != "" and anchors.has(other):
				var dx: float = vec(anchors[other]["p"]).x - vec(anchors[aid]["p"]).x
				_check((dx < 0.0) == flip, "%s %s turns toward %s" % [pid, aid, other])
	# the belfry's boss spot leaves the size to the figure, so the Snuffer's
	# taunt can stand there at his own size (Tollgrave's intro size is his figure's)
	var bf: Dictionary = panels.get("belfry", {}).get("anchors", {})
	_check(bf.has("boss") and not bf["boss"].has("h"), "belfry's boss anchor has no size of its own")


# Layers and figures draw strictly by depth, so the moonlight that falls from a
# far window to the floor is split: the far part fades out at the wall's foot
# and the rest is a lit layer at the floor's depth, after the floor and under
# the figures. The bells' beams are shaded, so they grow as the bells light.
func _test_split_light() -> void:
	var panels: Dictionary = data["panels"]
	for sp in [["chapel", "beam", "pool", "fg", Vector2(610, 318), 284.0], ["belfry", "shafts", "pools", "floor", Vector2(420, 330), 302.0]]:
		if not panels.has(sp[0]):
			continue
		var layers: Array = panels[sp[0]]["layers"]
		var idx := {}
		for i in layers.size():
			idx[String(layers[i]["tex"]).get_file().get_basename().trim_prefix(sp[0] + "_")] = i
		_check(idx.has(sp[1]) and idx.has(sp[2]) and idx.has(sp[3]), "%s has %s, %s and %s" % [sp[0], sp[1], sp[2], sp[3]])
		if not (idx.has(sp[1]) and idx.has(sp[2]) and idx.has(sp[3])):
			continue
		var far: Dictionary = layers[idx[sp[1]]]
		var near: Dictionary = layers[idx[sp[2]]]
		_check(far["lit"] and near["lit"], "%s's %s and %s are lit" % [sp[0], sp[1], sp[2]])
		_check(float(near["depth"]) == float(layers[idx[sp[3]]]["depth"]) and idx[sp[2]] > idx[sp[3]],
			"%s's %s sits at the floor's depth, after it" % [sp[0], sp[2]])
		# rasterize at 1 px per unit: the far part is clear below the wall's foot
		var k := 1.0 / float(far["px"])
		var a := Image.new()
		a.load_svg_from_string(FileAccess.get_file_as_string(far["tex"]), k)
		var clear := true
		for x in range(0, a.get_width(), 4):
			for y in range(int(sp[5] + 8), a.get_height(), 4):
				clear = clear and a.get_pixel(x, y).a < 0.02
		_check(clear, "%s_%s fades out by the wall's foot" % [sp[0], sp[1]])
		var b := Image.new()
		b.load_svg_from_string(FileAccess.get_file_as_string(near["tex"]), 1.0 / float(near["px"]))
		var q: Vector2 = sp[4]
		_check(b.get_pixel(int(q.x), int(q.y)).a > 0.03, "%s_%s lights the floor at %s" % [sp[0], sp[2], q])
	for lay in panels.get("bells_all", {}).get("layers", []):
		if String(lay["tex"]).ends_with("_beams.svg"):
			_check(not lay.get("lit", false), "bells_all's beams are shaded, so they show as the bells light")


func _test_dawn_lamps() -> void:
	var panels: Dictionary = data["panels"]
	if not panels.has("dawn_rise") or not panels.has("lanternfold"):
		return
	for i in range(1, 9):
		var a := vec(panels["lanternfold"]["lights"]["lamp%d" % i]["p"])
		var b := vec(panels["dawn_rise"]["lights"]["lamp%d" % i]["p"])
		_check(a.distance_to(b) < 0.5, "lamp%d stands in the same place at dawn (%s vs %s)" % [i, a, b])


# every anchor a figure or the actor stands on has a light near its head
# (panels with darkness only): focal points sit in light pools. Lights that
# start off don't count, but the anchors a cue reveals (CUE_LIT) stand in one.
func _test_lit_anchors() -> void:
	var panels: Dictionary = data["panels"]
	for pid in panels:
		var pn: Dictionary = panels[pid]
		if pn["dark"] == null:
			continue
		var lights: Dictionary = pn["lights"]
		for aid in pn["anchors"]:
			var a: Dictionary = pn["anchors"][aid]
			var head: Vector2 = vec(a["p"]) - Vector2(0, float(a.get("h", 120.0)) * 0.5)
			var lit := false
			var cued := false
			for lid in lights:
				var L: Dictionary = lights[lid]
				if vec(L["p"]).distance_to(head) <= float(L["r"]):
					if L.get("off", false):
						cued = true
					else:
						lit = true
			if (CUE_LIT.get(pid, []) as Array).has(aid):
				_check(cued, "%s anchor %s stands in the reach of the light its cue turns on" % [pid, aid])
			else:
				_check(lit or aid.begins_with("actor") or aid == "edge", "%s anchor %s stands in a light's reach" % [pid, aid])


func _test_figures() -> void:
	var figs: Dictionary = data["figures"]
	_check(figs.size() == FIGURES.size(), "there are %d figures (got %d)" % [FIGURES.size(), figs.size()])
	for fid in FIGURES:
		_check(figs.has(fid), "figure %s exists" % fid)
		if not figs.has(fid):
			continue
		var f: Dictionary = figs[fid]
		_check(FileAccess.file_exists(f["tex"]), "figure %s texture exists" % fid)
		var frame: Array = f["frame"]
		_check(int(frame[0]) == 256 and int(frame[1]) == 256, "figure %s uses the 256 frame" % fid)
		var sz := svg_size(f["tex"])
		_check(absf(sz.x - 256.0 * float(f["px"])) < 1.0, "figure %s is 256 x px wide" % fid)
		_check(float(f["h"]) > 0.0, "figure %s has a height" % fid)
		var flames: Dictionary = f["flames"]
		for name in FIGURES[fid]:
			_check(flames.has(name), "figure %s has flame %s" % [fid, name])
		for name in flames:
			_check(flames[name] is Array, "figure %s flame %s is an array" % [fid, name])
			if not flames[name] is Array:
				continue
			var q: Array = flames[name]
			_check(q.size() >= 3 and Rect2(0, 0, 256, 256).has_point(Vector2(float(q[0]), float(q[1]))), "figure %s flame %s is in the frame" % [fid, name])
			# [x, y, h, kind, colour]: a reader of the array alone gets the kind and colour
			var kind: String = str(q[3]) if q.size() > 3 else ""
			_check(KINDS.has(kind), "figure %s flame %s names its kind (%s)" % [fid, name, kind])
			var st: Dictionary = f.get("light", {}).get(name, {})
			_check(st.get("kind", kind) == kind, "figure %s flame %s: the array and light agree on the kind" % [fid, name])
			_check(float(st.get("r", 1.0)) > 0.0 and float(st.get("s", 1.0)) > 0.0, "figure %s flame %s has a light r and s" % [fid, name])
			if kind == "eyes":
				var pts: Array = st.get("pts", [])
				_check(pts.size() == 2, "figure %s's eyes have two points" % fid)
				_check(q.size() > 4 and str(q[4]) == str(st.get("color", "")), "figure %s's eyes carry their colour in the array" % fid)
				if pts.size() == 2:
					var a := vec(pts[0])
					var b := vec(pts[1])
					var mid := (a + b) * 0.5
					_check(mid.distance_to(Vector2(float(q[0]), float(q[1]))) < 0.6, "figure %s's eye point is between its eyes" % fid)
					_check(absf(a.distance_to(b) - EYE_GAP * float(q[2])) < 0.5,
						"figure %s's eyes are EYE_GAP h apart (%.1f vs %.1f)" % [fid, a.distance_to(b), EYE_GAP * float(q[2])])
			else:
				_check(float(q[2]) > 0.0, "figure %s flame %s has a height" % [fid, name])
	var feet: Array = figs.get("taper_stand", {}).get("feet", [])
	_check(feet.size() == 2 and float(feet[0]) == 128.0 and float(feet[1]) == 244.0, "figures stand on (128, 244)")
	# Taper is tiny: about 60% of Wick's height (the actor is h 120 for 128 frame units)
	if figs.has("taper_stand") and figs.has("novice_back"):
		_check(absf(float(figs["taper_stand"]["h"]) - float(figs["novice_back"]["h"])) < 0.5, "Taper and the novice are drawn at one scale")
	# The story's Snuffer is the fight's (boss2.py's parts): the white collar,
	# the brass pole and its bell; the three drawings of him share one scale
	for fid in ["snuffer_stand", "snuffer_reach", "cone_broken"]:
		if figs.has(fid):
			var t := FileAccess.get_file_as_string(figs[fid]["tex"])
			_check(t.contains("#b8862a") and (fid == "cone_broken" or t.contains("#d6d0e4")), "%s wears the fight Snuffer's brass (and collar)" % fid)
			_check(absf(float(figs[fid]["h"]) - float(figs["snuffer_stand"]["h"])) < 0.5, "%s is drawn at the Snuffer's scale" % fid)
	# v3's bosses: the fight's size (the Snuffer's scale) where the panel has
	# the headroom, 0.85 of it in the Heartwood and the Escapement; each boss's
	# drawings at one scale
	for fid in ["rootmother_boss", "rootmother_open", "tinker_boss", "saint_boss", "tessel_lit"]:
		if figs.has(fid) and figs.has("snuffer_stand"):
			var k := float(figs[fid]["h"]) / float(figs["snuffer_stand"]["h"])
			_check(k >= 0.84 and k <= 1.001, "%s is drawn at 0.85 to 1 of the fight's scale (%.2f)" % [fid, k])
	for pair in [["rootmother_boss", "rootmother_open"], ["saint_boss", "tessel_lit"]]:
		if figs.has(pair[0]) and figs.has(pair[1]):
			_check(float(figs[pair[0]]["h"]) == float(figs[pair[1]]["h"]), "%s and %s are drawn at one scale" % pair)


func _test_portraits() -> void:
	var ports: Dictionary = data["portraits"]
	for who in MOODS:
		_check(ports.has(who), "portraits for %s" % who)
		if not ports.has(who):
			continue
		var p: Dictionary = ports[who]
		_check(p["moods"] == MOODS[who], "%s has the moods %s" % [who, MOODS[who]])
		for mood in MOODS[who]:
			var res := "res://art/story/portraits/%s_%s.svg" % [who, mood]
			_check(FileAccess.file_exists(res), "portrait %s exists" % res)
			_check(absf(svg_size(res).x - 768.0) < 1.0, "portrait %s is 128 x 6 px" % res)
			var fl: Array = p.get("mood_flames", {}).get(mood, p.get("flames", []))
			for q in fl:
				_check(q is Array and (q as Array).size() >= 3, "%s_%s flame is [x, y, h]" % [who, mood])
				var fp := Vector2(float(q[0]), float(q[1]))
				# the dialogue box's crop keeps the flame's base and the candle under it
				_check(fp.distance_to(CROP_C) <= CROP_R - 2.0, "%s_%s flame sits inside the box's crop (%.1f from its centre)" % [who, mood, fp.distance_to(CROP_C)])
		# flame: an array of numbers when present (a reader assigns it to an Array),
		# left out when the first mood has none
		if p.has("flame"):
			var f0 = p["flame"]
			var ok: bool = f0 is Array and (f0 as Array).size() >= 3
			if ok:
				for v in f0:
					ok = ok and (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT)
			_check(ok, "%s's flame is an array of at least 3 numbers" % who)
			var fls: Array = p.get("flames", [])
			_check(fls.size() > 0 and fls[0] == f0, "%s's flame is its first flame" % who)
		else:
			_check((p.get("flames", []) as Array).is_empty(), "%s has no flame key only when it has no flames" % who)
		# the face is inside the r 46 crop: the centre of the frame is painted
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://art/story/portraits/%s_%s.svg" % [who, MOODS[who][0]]), 0.25)
		_check(img.get_pixel(img.get_width() / 2, img.get_height() / 2).a > 0.9, "%s's portrait is painted at its centre" % who)
	_check(ports.get("taper", {}).get("flame") is Array, "Taper's nub candle is a live flame")
	for who in ["tollgrave", "snuffer", "hollin"]:
		_check(not ports.get(who, {}).has("flame"), "%s has no flame key (no live flame in its first mood)" % who)
	_check((ports.get("waxley", {}).get("flames", []) as Array).size() == 2, "two of Waxley's brim candles are live")
	_check((ports.get("hollin", {}).get("mood_flames", {}).get("relit", []) as Array).size() == 1, "relit Hollin's helm is lit")


# The credits' cast roll: a portrait for everyone and every boss (and the
# five callings' own for Waxby).
func _test_cast_roll() -> void:
	var ports: Dictionary = data["portraits"]
	for who in CAST_ROLL:
		var moods: Array = ports.get(who, {}).get("moods", [])
		_check(moods.size() > 0 and FileAccess.file_exists("res://art/story/portraits/%s_%s.svg" % [who, moods[0]]),
			"the cast roll has %s's portrait" % who)
	for cls in ["knight", "founder", "witch", "runner", "sexton"]:
		_check(FileAccess.file_exists("res://art/heroes/%s/portrait_normal.svg" % cls), "the cast roll has the %s's portrait" % cls)
	# story.gd's own roll (once it has one): every [who, mood] has its portrait
	# (a speaker's CAST "face" alias: the Lost Wicks wear echo's)
	var St = load("res://scripts/story.gd")
	var roll = St.get_script_constant_map().get("CAST_ROLL", null) if St != null else null
	var cast: Dictionary = St.get_script_constant_map().get("CAST", {}) if St != null else {}
	if roll is Array:
		for page in roll:
			for e in page.get("people", []):
				var who := str(e[0])
				if who == "wick":
					continue
				var face := str((cast.get(who, {}) as Dictionary).get("face", who))
				_check((ports.get(face, {}).get("moods", []) as Array).has(str(e[1])),
					"story.gd's cast roll: %s (%s) has the portrait %s_%s" % [who, face, face, e[1]])
	for who in LIVE:
		var fl: Array = ports.get(who, {}).get("flames", [])
		_check(fl.size() == LIVE[who], "%s's first portrait has %d live flame(s) (%d)" % [who, LIVE[who], fl.size()])
	for who in ["rootmother", "tinker", "tickwell", "saint", "tessel", "hush"]:
		_check(not ports.get(who, {}).has("flame"), "%s's portrait has no live flame" % who)
	# Taper faint: her nub flame at 0.35 of its height
	var tp: Dictionary = ports.get("taper", {})
	var faint: Array = tp.get("mood_flames", {}).get("faint", [])
	if tp.has("flame") and faint.size() == 1:
		_check(absf(float(faint[0][2]) - 0.35 * float(tp["flame"][2])) < 0.05, "taper_faint's flame is 0.35 of her warm one")
	else:
		_check(false, "taper_faint has one small flame")
	for mood in ["worried", "grin"]:
		_check((ports.get("hollin", {}).get("mood_flames", {}).get(mood, []) as Array).size() == 1, "hollin_%s's helm is lit" % mood)


func hex_colours(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("#[0-9a-fA-F]{6}\\b")
	var out := {}
	for m in re.search_all(text):
		out[m.get_string().to_lower()] = true
	return out


# The bosses' story figures are the fight's: each uses nearly every colour of
# its fight frame (A4's) when the frame is here, and wears A4's palette.
func _test_boss_palettes() -> void:
	var figs: Dictionary = data["figures"]
	for bp in BOSS_FIGHT:
		var fid: String = bp[0]
		if not figs.has(fid):
			continue
		var mine := hex_colours(FileAccess.get_file_as_string(figs[fid]["tex"]))
		var worn := 0
		for c in bp[2]:
			if mine.has(c):
				worn += 1
		_check(worn == (bp[2] as Array).size(), "%s wears the fight's palette (%d of %d of boss3/4/5.py's colours)" % [fid, worn, (bp[2] as Array).size()])
		if not FileAccess.file_exists(bp[1]):
			print("  note: %s isn't here yet (A4's): %s is checked against its palette only" % [bp[1], fid])
			continue
		var fight := hex_colours(FileAccess.get_file_as_string(bp[1]))
		var both := 0
		for c in fight:
			if mine.has(c):
				both += 1
		_check(both >= FIGHT_SHARE * fight.size(), "%s uses its fight frame's colours (%d of the %d in %s)" % [fid, both, fight.size(), bp[1].get_file()])


func _test_svgs() -> void:
	var n := 0
	var bad := []
	for dir in ["res://art/story/sets", "res://art/story/figures", "res://art/story/portraits"]:
		var d := DirAccess.open(dir)
		_check(d != null, "%s exists" % dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".svg"):
				continue
			var text := FileAccess.get_file_as_string(dir + "/" + f)
			if text.contains("<text") or text.contains("<filter"):
				bad.append(f + " (text/filter)")
			var img := Image.new()
			if img.load_svg_from_string(text, 0.05) != OK or img.get_width() < 2:
				bad.append(f + " (raster)")
			n += 1
	_check(bad.is_empty(), "every story SVG rasterizes without <text> or filters: %s" % [bad])
	_check(n >= 60, "the story art has its files (%d)" % n)


func _test_imports() -> void:
	var d := DirAccess.open("res://art/story/sets")
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".svg.import"):
			var t := FileAccess.get_file_as_string("res://art/story/sets/" + f)
			_check(t.contains("mipmaps/generate=false"), "%s imports without mipmaps" % f)
