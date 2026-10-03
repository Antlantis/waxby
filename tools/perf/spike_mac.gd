# The GPU spike on the Mac (the phone runs it through tools/perf/run_phone.sh).
#   godot --path game --resolution 2868x1320 [--rendering-driver vulkan --rendering-method mobile] \
#         --script res://../tools/perf/spike_mac.gd -- [all|lights48|lights48b|scene33]
# Metal reports no GPU time (read the ramp); Vulkan (MoltenVK) does. Uses this
# copy's v3 light seam (tools/perf/world_seam.gd) until world.gd has it.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "all"
	await process_frame
	var sp = load("res://scripts/perf_spike.gd").new()
	sp.name_arg = which
	sp.world_script_path = "res://../tools/perf/world_seam.gd"
	root.add_child(sp)
	await process_frame
	sp.run(which)
