extends Node

const TARGET_FRAME_SECONDS := 1.0 / 60.0

var optimization_enabled := false
var benchmark_active := false
var benchmark_profile := "baseline"
var racer_count := 0

var _sample_count := 0
var _fps_sum := 0.0
var _process_seconds_sum := 0.0
var _physics_seconds_sum := 0.0
var _draw_calls_sum := 0.0
var _primitives_sum := 0.0
var _render_objects_sum := 0.0
var _physics_pairs_sum := 0.0
var _memory_peak_bytes := 0.0
var _video_memory_peak_bytes := 0.0
var _ai_update_usec_total := 0
var _ai_update_calls := 0
var _ai_brain_updates := 0
var _ai_raycast_calls := 0
var _ai_lod_samples: Array[int] = [0, 0, 0]

func _ready() -> void:
	optimization_enabled = _env_enabled("WILDDASH_OPTIMIZED")

func set_optimization_enabled(value: bool) -> void:
	optimization_enabled = value

func start_benchmark(profile: String, total_racers: int) -> void:
	benchmark_profile = profile
	racer_count = total_racers
	_reset_samples()
	benchmark_active = true
	print("PERF START profile=%s racers=%d optimized=%s" % [benchmark_profile, racer_count, str(optimization_enabled)])

func finish_benchmark() -> Dictionary:
	benchmark_active = false
	var samples: float = maxf(1.0, float(_sample_count))
	var avg_fps := _fps_sum / samples
	var process_ms := (_process_seconds_sum / samples) * 1000.0
	var physics_ms := (_physics_seconds_sum / samples) * 1000.0
	var engine_cpu_budget_pct := ((_process_seconds_sum + _physics_seconds_sum) / samples) / TARGET_FRAME_SECONDS * 100.0
	var ai_ms_per_frame := (float(_ai_update_usec_total) / 1000.0) / samples
	var ai_usec_per_call := float(_ai_update_usec_total) / maxf(1.0, float(_ai_update_calls))
	var draw_calls := _draw_calls_sum / samples
	var primitives := _primitives_sum / samples
	var render_objects := _render_objects_sum / samples
	var physics_pairs := _physics_pairs_sum / samples
	var memory_mb := _memory_peak_bytes / (1024.0 * 1024.0)
	var video_memory_mb := _video_memory_peak_bytes / (1024.0 * 1024.0)
	var result := {
		"profile": benchmark_profile,
		"racers": racer_count,
		"fps_avg": avg_fps,
		"process_ms": process_ms,
		"physics_ms": physics_ms,
		"engine_cpu_budget_pct": engine_cpu_budget_pct,
		"ai_ms_per_frame": ai_ms_per_frame,
		"ai_usec_per_call": ai_usec_per_call,
		"ai_brain_updates": _ai_brain_updates,
		"ai_raycast_calls": _ai_raycast_calls,
		"draw_calls_avg": draw_calls,
		"primitives_avg": primitives,
		"render_objects_avg": render_objects,
		"physics_pairs_avg": physics_pairs,
		"memory_mb_peak": memory_mb,
		"video_memory_mb_peak": video_memory_mb,
		"lod_near_samples": _ai_lod_samples[0],
		"lod_mid_samples": _ai_lod_samples[1],
		"lod_far_samples": _ai_lod_samples[2],
	}
	print("PERF_RESULT profile=%s racers=%d fps_avg=%.2f process_ms=%.3f physics_ms=%.3f engine_cpu_budget_pct=%.2f ai_ms_per_frame=%.3f ai_usec_per_call=%.2f ai_brain_updates=%d ai_raycast_calls=%d draw_calls_avg=%.1f primitives_avg=%.1f render_objects_avg=%.1f physics_pairs_avg=%.1f memory_mb_peak=%.2f video_memory_mb_peak=%.2f lod_near=%d lod_mid=%d lod_far=%d" % [
		benchmark_profile, racer_count, avg_fps, process_ms, physics_ms, engine_cpu_budget_pct,
		ai_ms_per_frame, ai_usec_per_call, _ai_brain_updates, _ai_raycast_calls, draw_calls,
		primitives, render_objects, physics_pairs, memory_mb, video_memory_mb,
		_ai_lod_samples[0], _ai_lod_samples[1], _ai_lod_samples[2],
	])
	return result

func record_ai_update(duration_usec: int, lod_level: int, brain_updated: bool, raycast_used: bool) -> void:
	if not benchmark_active:
		return
	_ai_update_usec_total += maxi(0, duration_usec)
	_ai_update_calls += 1
	if brain_updated:
		_ai_brain_updates += 1
	if raycast_used:
		_ai_raycast_calls += 1
	var safe_lod := clampi(lod_level, 0, 2)
	_ai_lod_samples[safe_lod] += 1

func _process(_delta: float) -> void:
	if not benchmark_active:
		return
	_sample_count += 1
	_fps_sum += Performance.get_monitor(Performance.TIME_FPS)
	_process_seconds_sum += Performance.get_monitor(Performance.TIME_PROCESS)
	_physics_seconds_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_draw_calls_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitives_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_render_objects_sum += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_physics_pairs_sum += Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
	_memory_peak_bytes = maxf(_memory_peak_bytes, Performance.get_monitor(Performance.MEMORY_STATIC))
	_video_memory_peak_bytes = maxf(_video_memory_peak_bytes, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))

func _reset_samples() -> void:
	_sample_count = 0
	_fps_sum = 0.0
	_process_seconds_sum = 0.0
	_physics_seconds_sum = 0.0
	_draw_calls_sum = 0.0
	_primitives_sum = 0.0
	_render_objects_sum = 0.0
	_physics_pairs_sum = 0.0
	_memory_peak_bytes = 0.0
	_video_memory_peak_bytes = 0.0
	_ai_update_usec_total = 0
	_ai_update_calls = 0
	_ai_brain_updates = 0
	_ai_raycast_calls = 0
	_ai_lod_samples = [0, 0, 0]

func _env_enabled(name: String) -> bool:
	if not OS.has_environment(name):
		return false
	var value := OS.get_environment(name).strip_edges().to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"
