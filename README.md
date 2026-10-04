# WAXBY

A side-scroller for iPhone set in a sunken gothic cathedral. Waxby is a small
candle-keeper whose flame is his life and his light. Every hit shrinks the
flame, and with it how far he can see. The bells below have stopped ringing,
and the Snuffer is putting out every light that is left. Waxby goes down to
ring them again.

- **Five callings**, each with its own Special, resource, movement quirk and
  skill tree:
  - Candleknight: Aegis guard and shield-rush, runs on Grace; ledge grab.
  - Taperwitch: charged Flare that leaves a light, runs on Melt; drift.
  - Sootrunner: Smoke Step dash, where back hits always crit; runs on Smoke;
    moth cling.
  - Bellfounder: Peal ground slam, runs on Heat; stampede.
  - Sexton: Knell wisps and Toll the Dead, runs on Dirge; grave step.
- **Levels and loot:** XP to level 30, skill points, gear with affixes and
  Legendaries, a relic codex with a belt of 2 to 4 slots, and the Chandler's
  shop. The belt changes between levels, on the map's Sheet; in a level its
  tab is only to look at, and a found relic goes straight onto a free slot.
  A lit altar with a skill point waiting offers three skills (the Altar
  Rites; again while points are left), then a relic found with the belt full
  against the weakest worn one (the one way the belt changes in a level;
  found after the last altar, or in a mode, it waits in the codex for the
  map). A boss's first kill on a difficulty lets you choose his prize: his
  signature Legendary or one or two others you don't hold (the Boss Boons).
  Dusk kills drop half as often and never a Common; a Legendary taken is worn
  over a piece that isn't one, and announced, and a worn one is never swapped
  out by itself for a piece that isn't one.
- **Four worlds of four levels** so far (v3 builds toward six), each ending
  in a boss:
  - World 1, the Sunken Cathedral: the Nave, the Crypt Stair, the Burning
    Choir, and the Bell Tower with Old Tollgrave.
  - World 2, the Tallow Deep: the Waxfalls, the Drowned Chandlery, the Moth
    Garden, and the Undercandle with the Snuffer.
  - World 3, the Bone Orchard (climb): the Bramble Gate, the Hanging
    Ossuary, the Sporewood, and the Heartwood with Mother Gravebough.
  - World 4, the Frozen Carillon (keep time): the Rime Stair, the
    Escapement, the Hall of Weights, and the Hour Chamber with the Tinker
    of Hours.
- **Three difficulties:** Dusk, Nightfall and Witching. There are elites with
  Omens, Dreads, and a Guttered Pool of spilled embers you can win back. Dusk
  stays gentle in Worlds 1-2 and pushes back from World 3 (Combat.DUSK_TEETH):
  altars heal 40%, the monsters killed come back after a snuff, Anointed come
  about twice as often, and Hushlings hunt in twos and threes. Anointed and
  Dreads there fight with their Nightfall moves (a Rattlehound's second
  pounce, an Anointed Hushling's bigger pack), their life, damage and tells
  still Dusk's (elites.gd behave_diff). These and the Dusk kill drops are
  the story's: the challenge modes (the Descent, the Waxworks, the Trials)
  keep Dusk as it was before. A level's anoint: header places Anointed
  every run, with chosen Omens and a name on their plate (lab-elites shows
  both).
- **Illustrated story scenes** between the worlds, with portraits and voices.
  Waxby is the hero's name until you give him your own at the oath (up to 12
  letters; Rename on the Sheet's Stats tab changes it). Any keeper who carries
  the flame is a Wick, as Mother Taper tells him there.

Every picture is drawn in code (Python-generated SVG) and every sound is
synthesized. Nothing is borrowed.

```
game/                     Godot 4.7 project (landscape 844x390, mobile renderer, 120 Hz physics)
  scenes/main.tscn        the only scene: a Node running scripts/main.gd
  scripts/main.gd         the flow: title -> story -> map -> level -> results; debug --autoplay bot
  scripts/world.gd        one level being played: builds it from LevelData, runs the step, damage
                          (deal / hurt_player), hazards, shots, lights, loot drops, XP, the pool
  scripts/combat.gd       the numbers: difficulty table, scaling, damage rolls, light radius
  scripts/classes.gd      the five callings and their skill trees
  scripts/kits/*.gd       each calling's Special, resource and quirk (kit.gd is the base)
  scripts/player.gd       Waxby's feel (accel, variable jump, coyote time, buffers) plus HP and hits
  scripts/wick_rig.gd     the paper-doll body (art/heroes/<calling>/ parts) animated in code
  scripts/hero.gd  items.gd  progression.gd  relics.gd   stats, gear, the XP curve, relics
  scripts/game_state.gd   Game autoload: the save (with v1 migration), heroes, unlocks, input actions
  scripts/enemy.gd        what monsters share; one script per monster; elites.gd adds Omens
  scripts/boss.gd         Old Tollgrave; snuffer_boss.gd the Snuffer (both with their Waxworks rush
                          moves, Bell Roll and the Smother)
  scripts/boss_mods.gd    the boss rush's boss side for every boss: the rush life (RUSH_HP), Warded
                          and Echoing Wax as a runtime (marks() is what the echoes draw)
  scripts/boss_rig.gd     the v3 bosses' shared rules (windows, the first stomp 3x, phases, staggers,
                          the retry) and parts rig; rootmother_boss.gd Mother Gravebough (3-4's
                          R_ARENA), tinker_boss.gd the Tinker of Hours (4-4's K_ARENA);
                          saint_boss.gd the Prism Saint (5-4's P_ARENA), hush_boss.gd the Hush
                          (6-4's Z_ARENA) and hush_finale.gd its in-level ending (the stair, the
                          hold, hush_given); each boss's bot_pad plays its fight for --autoplay
  scripts/features/*.gd   v3's terrain, one module a world (level_features.gd builds them):
                          orchard.gd W3 (vines and rotten vines, spore pods, glowfruit, the updraft),
                          clockwork.gd W4 (the tick, ice and rime, icicles, belts, cogs, swings,
                          weights), glass.gd W5 (glass, gusts, dawnglass), deep.gd W6 (floats,
                          bell-buoys and still water, grasps, Hush zones, Vigil candles, the tide),
                          secrets.gd (the silver bells and their arches, the Warden rooms, the
                          shrine and its prize), sealed.gd (Build 2's sealed fight rooms, a
                          header's `room:` duel, ambush or hold: the doors lock till it's won,
                          a snuff resets it at the door altar; the --autoplay bot fights in it)
  scripts/themes/*.gd     v3's themes (loader.gd reads them): w3.gd the orchard, rootvault,
                          sporewood and rootheart; w4.gd clockface, gearworks, icebells and
                          escapement (palettes, props maps, ambient, edge lines, water); w5.gd
                          choirglass, rosewind, voidnave, prismheart; w6.gd stillshore, drownbell,
                          hushquiet, husheye; modes.gd the trial hall and the six *_gilt secrets
  scripts/tiles/*.gd      the themes' painters (orchard.gd, frost.gd, glass.gd with W5's gust look and
                          pennants, hush.gd with W6's floats, buoys and still water); scripts/backdrops/
                          *.gd their sliced backdrop styles (orchard.gd, with the Strip / clip_strip
                          helpers the sliced styles share, clockwork.gd, sanctum.gd, hushdeep.gd, hall.gd)
  scripts/level_data.gd   the ASCII level format and its legend (read this before editing a level)
  scripts/level_features.gd  braziers, lanterns, waxfalls, drip spouts, false stone
  scripts/twists.gd       Build 2's level twists, from an optional `twist:` header (none: the
                          level plays as before): the registry (a name and a line per world,
                          shown as "4-2 · On the Hour" on the title card, then the line in the
                          top band once per level and difficulty; an X-1's `lesson: Title|Line`
                          card) and the rules: restless / restless_all (stomped remains rise
                          once unless struck; a risen one pays nothing), dark, omens, dry,
                          packs, toll (a bell every 16 beats of the W4 tick quickens what's in
                          view) and lamplit. The belts' `belt_flip:` header is clockwork.gd's
  scripts/story.gd        every story scene as data; cutscene.gd plays them, cutscene_stage.gd draws
  scripts/name_entry.gd   the hero's name, asked for at the oath (the choose_name cue) and by the
                          Sheet's Rename: the field, the phone's keyboard, the rules (Story.clean_name)
  scripts/tales_screen.gd the Tales: every scene seen, replayed (opened from the title and the saves)
  scripts/hud.gd  touch_controls.gd  title_screen.gd  map_screen.gd  hero_screen.gd (+ *_panel.gd)
  scripts/chandler_screen.gd  keeper_screen.gd  pause_menu.gd  results_screen.gd  settings.gd
  scripts/choice_card.gd  the one choice card over a paused game: up to three cards and a button
                          (the Descent's Glimmers, the Altar Rites, a relic, a boss's boon);
                          rites.gd the Altar Rites: a lit altar with a skill point waiting offers
                          three skills to learn there (again while points are left), then a relic
                          found with the belt full against the weakest worn one (world.gd
                          open_relic); the Boss Boons (world.gd open_boon, Items.boon_legends):
                          a boss's first kill offers his signature Legendary and others to choose
  scripts/glow.gd         everything bright, drawn above the dark
  shaders/darkness.gdshader  the dark: multiplies the screen, warm in hard bands near lights
  scripts/sfx.gd          Sfx autoload: every sound synthesized (cached after first boot), music;
                          v3's banks sfx_w3.gd .. sfx_w6.gd, sfx_story.gd, sfx_modes.gd
  scripts/rootling.gd ... hoarowl.gd   v3's W3-W4 monsters; glassmite.gd ... lurecoil.gd and
                          hush_kind.gd W5-W6's (the Unwick is the player's own rig)
  scripts/modes/*         the Challenges: mode.gd (the seam), descent.gd, waxworks.gd, trials.gd,
                          rooms.gd, descent_data.gd, trial_data.gd, cosmetics.gd, modes_save.gd,
                          mode_hud.gd, mode_art.gd, mode_results.gd, modes_screen.gd, descent_screen.gd,
                          waxworks_screen.gd, trials_screen.gd, look_panel.gd
  levels/*.txt            generated by tools/make_levels.py, do not hand-edit (the level modules
                          are tools/levels/w1.py ... w6.py and secrets.py, 1-S ... 6-S; the
                          feel labs lab.py; the Build 2 labs lab_elites.py, lab_twists.py
                          (lab-restless ... lab-lesson) and lab_rooms.py (lab-rooms, the sealed
                          rooms); each W3-W6 module's ROSTER and THREAT tables are its regular
                          levels' cast and threat, written as their roster: and threat: headers;
                          common.py's Build 2 toolkit: swap, stamp, span, anoint_header,
                          rooms_header, the world's rules)
  levels/rooms/*.txt  rush/*.txt  trials/*.txt   the modes' rooms, Waxworks arenas and Vigil Trials
                          (tools/make_rooms.py, make_modes.py, make_trials.py; test.sh re-runs them)
  audio/*.wav             music generated by tools/audio/music.py (tracks, the hush_final and
                          descent stems, the premixes, the ambience beds)
  art/                    SVGs generated by tools/art/build.py (story art by tools/art/story.py):
                          art/items/*_4.svg and *_5.svg (tiers 4-5; tier 4 frost-rimmed);
                          art/ui/world_1..6, candlemark, medal_*, seal_*, drip, spare_wick, hushing;
                          the 8 new relics; art/heroes/<cls>/cape_trim_<pattern>.svg (hem and edge);
                          art/enemies: v3's monster frames and points_monsters3/4.json (enemies3.py,
                          enemies4.py: the spur_face overlays, the coil _bare heads), the bosses'
                          frames, parts (rootmother_legs, hush_eye_small), props and
                          points_rootmother/tinker/saint/hush.json (boss3.py .. boss6.py: Mother
                          Gravebough, the Tinker of Hours, the Prism Saint, the Hush; boss3 holds
                          the helpers boss4-6 share; frames of 256+ units import without mipmaps).
                          main.gd warms v2's frames and the props at the title; each v3 world's
                          monsters and each new boss are a set of their own (main.WORLD_ART,
                          KIND_ART), warmed only where they're played: a new frame goes in its
                          set, or tests/test_story.gd says where it's missing.
                          art/props: v3's W3-W6 props (tools/art/props_w3.py ... props_w6.py,
                          with points_w3.json ... points_w6.json), warmed with their world's set
                          (main.WORLD_PROPS), not at the title; the secrets' and modes' props
                          (props_modes.py, points_modes.json) are the title's.
                          art/story/thumbs/*.png: the Tales cards' pictures, baked by
                          tools/art/bake_tale_thumbs.gd (thumbs.json holds what each was made from)
                          art/story/portraits_hud: each story portrait again at 128 px (story.py
                          writes them), for the faces drawn small: the HUD's barks, the results
  tests/test_*.gd         core (levels, feel, a bot that reaches every bell and sigil), classes,
                          progression, screens, story, content, integration, sfx, art, monster_art,
                          monster_art3, boss_art, story_art, routes, export, render, monsters3,
                          monsters4, kits3, modes; test_w3 / test_w4 (World 3 and 4's levels,
                          features, star routes, nooks and the climbing bot), test_bosses3
                          (Gravebough and the Tinker: windows, blows, reach, the real arenas),
                          test_world_art (A1's themes: contrast, seams, props; its shots, dc and
                          seams modes need a window; WAXBY_A1_LEVELS points it at other levels),
                          test_w5 / test_w6 (World 5 and 6: glass, gusts, dawnglass, floats,
                          buoys, the chases' bot and human runners), test_secrets (the six secret
                          levels, the exits, the Wardens' rooms and prizes), test_bosses4 (the
                          Saint and the Hush: windows, tells, the finale, real-pad runs on the real
                          5-4 and 6-4 arenas), test_rush_bosses (Tollgrave's and the Snuffer's
                          rush moves, boss_mods.gd), test_world_art2 (A2's W5-W6 and gilt themes),
                          test_boss_windows (every calling at the arrival level and 4 over it
                          against the real 3-4 and 4-4, each window used in full: 5 windows
                          and 45 s at least, no add outliving its boss; and the real 5-4 and
                          6-4 through the boss's own bot_pad: the windows a phase the cap
                          allows at least, each Hush phase 70 s or less), test_toolkit (Build 2's
                          level rules, tests/level_rules.gd, proven on tests/fixtures/
                          toolkit-cast.txt; test_w3 .. test_w6 hold each regular level to its own
                          roster: and threat: through them, test_progression its anoint: cells),
                          test_twists (Build 2's twists, each in a small level: the cards and
                          their fit, every level without the header unchanged, and each rule
                          played out; the labs), test_rooms (Build 2's sealed rooms on
                          lab-rooms: seal and its tell, the bars, a snuff's reset, a pit, the
                          opt-in loft, no monsters, a resume, the bot)
  tests/routes/*.json     the golden routes (tools/record_route.gd; test_routes.gd replays them:
                          3-1 ... 4-3 to the bell, 3-4_approach, 3-4_approach_witch and
                          4-4-approach to the arena door; W3's are the Taperwitch's but
                          3-4_approach, the Candleknight's, which test_w3 also runs with monsters;
                          5-1 ... 6-3 (6-3's on all three difficulties), 5-4 and 6-4 to the arena
                          door (an "until" goal), 1-S ... 6-S and 2-2 to their silver bells,
                          2-2-bell to 2-2's main bell)
tools/
  make_levels.py          the levels, drawn as side-by-side sections (levels/toolkit.py: Build 2's
                          toolkit's self-check, and the test fixture it writes)
  make_rooms.py  make_modes.py  make_trials.py   the modes' rooms, rush arenas and trials
  record_route.gd  route_dfs.gd   golden routes: played by you or the autoplay bot; route_dfs.gd
                          (WLS's) by a live search on the real modules (the secret levels' routes)
  test.sh                 regenerate levels and the modes' files, run every test file (and
                          check_music.py unless WAXBY_FAST)
  shot*.gd                screenshots of levels, screens and scenes, for checking by eye
                          (shot_screens_v3.gd: SC's v3 screens with stand-in levels; shot_modes.gd;
                          shot_twists.gd: the twists' cards and tells in their labs)
  twist_lab.gd            a level played by hand with any twist (-- 3-2 --twist=restless_all)
  art/                    the art generators, contact sheets, the icon renderer
  audio/                  the music: music.py (v2's eight) merging tracks_worlds.py and
                          tracks_bosses.py (v3's, on instruments_v3.py); check_music.py (files,
                          loudness, phone, stems and stages, the carillon's tick, every played
                          note's mode); spectro.py; an SFX audition renderer
```

## Controls

On the phone: left and right under the left thumb (slide between them), the
flask above them; attack, jump and the Special under the right thumb; pause top
right. The left thumb also slides down and up, counted from where it landed
(26 px, less when it lands low on the glass): faint chevrons mark both while
the thumb is down, light while held, and the phone ticks as one switches on; a
quick steep slide (within 25 degrees of straight down or up, from half the
slide to all of it in 0.3 s) lets go of left and right, while a thumb creeping
down over a long run keeps running. Down held 0.15 s on a ledge drops through
it (or slide down and press jump, at once; down on solid floor does nothing,
and a down held on from a vine or the air waits to be let go); up climbs a
vine without the leap a fresh jump with an arrow held makes (slant it toward a
floor at the top to haul onto it). A one-time card teaches each, on the first
ledge and the first vine.
The camera holds Waxby's feet just over the highest thumb buttons (the Special
and the flask, at any button size), so nothing on his floor is behind them; it
leans up (at most back to the line it
held before) to show a drip spout, a Dripkin, a Bonebow, a Flit's roost with
its wind-up, or a Gutterwing nest hanging just over the top of the view. A
Bonebow looses, a Flit winds up and a nest breeds only in plain sight (not off
the glass, behind a button or the HUD's corners). Where Waxby is under the
HUD's corner blocks (a level's first and last tiles, where the camera stops at
the edge), a jump takes the camera up with him sooner, so his flame never goes
behind them; the boss bar, a title or level-up card or a message he jumps up
behind goes see-through. `tools/shot_floor.gd` measures and shoots all of it.

On a Mac: arrows or A/D to move (Down or S held on a ledge drops through it;
the Up arrow climbs a vine), Space/Z/W to jump, X/J to attack, C/L/E for the
Special, Q/Tab for the flask, R/Enter to take a pickup, Esc to pause. A game
controller (MFi, Xbox, PlayStation) plays the levels: the d-pad or the left
stick to move (the same four ways), A to jump, X to attack, Y for the Special,
the left shoulder for the flask, the right one to take a pickup, Menu to pause.
On the map it picks a level (left and right) and plays it (A); the pause
menu's buttons and the other screens are still taps.

## Saves

Three save slots, each a whole game of its own: the hero's name, callings,
gear, embers, relics, unlocks and story seen (a save from before names is
Waxby's). A tap on the title opens the saves
(scripts/saves_screen.gd). Tap a filled card to play on from the map, or an
empty one for a new game (the intro, then the oath). A filled card's "..."
offers **Start over** (erase it and begin again from the intro) and **Erase**
(leave the slot empty). Both need a 1.2 s hold, and an erase can be undone for
5 s (left sooner, the saves offer it again next time; the file is kept as
`.erased` until the next erase, the app's quit or its next launch). The map's
Title button returns to the title, and a tap there opens the saves.

A save is written to a side file and moved over the old one only once all of
it went down, so a kill mid-write or a full disk leaves the last save as it
was. The save it replaces is kept as `<slot>.bak` (`save.json.bak`,
`save_2.json.bak`, ...), and a save that goes missing or can't be read loads
from that instead (its card shows it too, and a missing one is put back from
it). A slot with only its `.bak` left is still a filled slot: its card, the
slot played last, Start over and Erase all see it. An erase or a new game keeps
the `.bak` aside with the save (`.erased.bak`), so an Undo brings back what the
card showed. `settings.json` does the same (`settings.json.bak`). If the
app is sent away mid-level (a call, the home swipe), the embers carried since
the last altar go into the slot's save as `unbanked`; they're still carried in
the level (only an altar or the bell banks them, and a snuff still spills
them), but if iOS ends the app there, the next load adds them to the purse, as
leaving the level through the pause menu would have.

Slot 1 is `user://save.json`, the save there has always been, and the only
one that migrates a v1 save. Slots 2 and 3 are `save_2.json` and
`save_3.json`, made when a game starts there. The settings (`settings.json`)
are shared by every slot and remember the one played last, which opens at
launch and whose hero the title shows. A save that can't be read is copied
aside as `.bad`, and if its `.bak` can't be read either, its card says so. The `--autoplay` bot keeps its own save,
with its slots beside it, so it never touches the player's. tests/test_slots.gd
works only in `user://test_slots/` and checks that the player's files are
byte for byte as they were; tools/shot_slots.gd takes screenshots.

## Build and run

```bash
python3 tools/make_levels.py             # after editing a level
python3 tools/art/build.py               # after editing art
tools/test.sh                            # all tests (WAXBY_FAST=1 skips the slow bot)
```

Godot is at /Users/antmacpro/Downloads/Godot.app. After new or changed art or
audio, run `Godot --headless --path game --import`. After a story set changes,
bake the Tales pictures again (a window, not headless) and import:

```bash
cd game && Godot --path . --resolution 1266x585 --script res://../tools/art/bake_tale_thumbs.gd
```

The iPhone build goes to ~/Developer/waxby-ios (not the iCloud Desktop):

```bash
cd game && Godot --headless --path . --export-debug "iOS" ../../waxby-ios/waxby.ipa
xcrun devicectl device install app --device <UDID> ~/Developer/waxby-ios/waxby.ipa
xcrun devicectl device process launch --device <UDID> com.ant.waxby
```

The bundle id is com.ant.waxby (it was com.ant.wick until 2026-09-28; an old
com.ant.wick install is a separate app and its save stays with it).
`-- --autoplay=1-3` after the bundle id runs that level with a bot and logs the
frame rate to Documents/logs/godot.log (debug builds only). The bot plays cold
(its level loads its own art); `--warm` beside it warms as a player's launch
does (v2's art at once, then the level's WORLD_ART sets), and
tools/perf/run_phone.sh passes it for level and mode runs (`--cold` there for
the old measurement). `--autoplay=4-3@2` starts the level at its altar 2 (0 is
the first), as "Continue from the altar" does: a perf run over a level's later
sections, or straight to a boss's door (3-4@1, 4-4@1). The debug bot climbs
World 3's vines but can't time World 4's weights, so W4's perf runs start from
their altars too. `--story` beside `--autoplay` plays the level's story as a
player's does (the scenes asked for ahead, the beats over the level with their
lines going by themselves): `tools/perf/run_phone.sh --story 3-4@1 4-4@1`
measures boss_3_before and boss_4_before over the live level. run_phone.sh
passes `--warm` to scene runs too (a player always has the title's art loaded
under a scene). The perf line's `art X MB` is the art textures loaded, from
their own sizes (the engine's texmem reads low once a scene has freed its
pictures); perf_report.py gates on the larger of the two.
