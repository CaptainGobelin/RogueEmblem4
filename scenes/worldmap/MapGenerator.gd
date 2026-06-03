# MapGenerator.gd
# Attach to the root Node2D of MapGenerator.tscn.
# Expects a TileMap child node named "TileMap".
#
# Elevation pipeline per tile:
#   raw_elev  = warped simplex noise                         [0,1]
#   grad_mask = directional gradient (angle + strength)     [0,1]
#   attractor = inverse-distance lift from seed tiles        [0,1]
#   final_elev = clamp(raw_elev*NOISE_BLEND + grad_mask*GRADIENT_BLEND + attractor, 0, 1)
#
# Classification:
#   final_elev < WATER_THRESHOLD    → WATER
#   final_elev > MOUNTAIN_THRESHOLD → MOUNTAIN
#   else → climate lookup (temp × humid 3×3) → GROUND/MARSH/ROCK/SNOW
#
# Seed tiles (never water) override the final result and
# also lift local elevation so they sit naturally inside land.

@tool
extends Node2D

# ---------------------------------------------------------------------------
# Inspector buttons
# ---------------------------------------------------------------------------
@export_group("Generation")
@export_tool_button("Re-generate (same seed)", "Reload") var _btn_same_seed: Callable = _regenerate_same

@export_tool_button("Generate (new seed)", "RandomNumberGenerator") var _btn_new_seed: Callable = _regenerate_new

# ---------------------------------------------------------------------------
# Seed
# ---------------------------------------------------------------------------
@export var seed_value: int = 0

# ---------------------------------------------------------------------------
# Landmass shape
# ---------------------------------------------------------------------------
@export_group("Landmass")
@export_range(0.10, 0.70, 0.05) var water_threshold: float    = 0.30
@export_range(0.70, 0.95, 0.05) var mountain_threshold: float = 0.75

@export_subgroup("Gradient")
@export_range(0.0, 1.0, 0.05) var gradient_strength_min: float = 0.20
@export_range(0.0, 1.0, 0.05) var gradient_strength_max: float = 0.85

@export_subgroup("Elevation Noise")
@export_range(0.01, 0.15, 0.01) var elev_freq_min:    float = 0.02
@export_range(0.01, 0.15, 0.01) var elev_freq_max:    float = 0.06
@export_range(1, 8)              var elev_octaves_min: int   = 3
@export_range(1, 8)              var elev_octaves_max: int   = 6
@export_range(0.0, 100.0, 10.0)   var elev_warp_max:    float = 80.0

@export_subgroup("Climate Noise")
@export_range(0.01, 0.15, 0.01) var climate_freq_min:    float = 0.04
@export_range(0.01, 0.15, 0.01) var climate_freq_max:    float = 0.08
@export_range(1, 8)              var climate_octaves_min: int   = 2
@export_range(1, 8)              var climate_octaves_max: int   = 4
@export_range(0.0, 100.0, 10.0)   var climate_warp_max:    float = 30.0

@export_subgroup("Tree Noise")
@export_range(0.01, 0.20, 0.01) var tree_freq_min:    float = 0.07
@export_range(0.01, 0.20, 0.01) var tree_freq_max:    float = 0.14
@export_range(1, 8)              var tree_octaves_min: int   = 2
@export_range(1, 8)              var tree_octaves_max: int   = 3
@export_range(0.0, 100.0, 10.0)   var tree_warp_max:    float = 20.0

# ---------------------------------------------------------------------------
# Climate
# ---------------------------------------------------------------------------
@export_group("Climate")
@export_subgroup("Temperature bands")
@export_range(0.10, 0.45, 0.05) var temp_cold: float = 0.35
@export_range(0.55, 0.90, 0.05) var temp_hot:  float = 0.65

@export_subgroup("Humidity bands")
@export_range(0.10, 0.45, 0.05) var humid_dry: float = 0.35
@export_range(0.55, 0.90, 0.05) var humid_wet: float = 0.65

# ---------------------------------------------------------------------------
# Tree density
# ---------------------------------------------------------------------------
@export_group("Trees")
@export_range(0.0, 1.0, 0.05) var tree_density_low:          float = 0.20
@export_range(0.0, 1.0, 0.05) var tree_density_mid:          float = 0.40
@export_range(0.0, 1.0, 0.05) var tree_density_light_forest: float = 0.60
@export_range(0.0, 1.0, 0.05) var tree_density_dense_forest: float = 0.78

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
@onready var tile_map: TileMapLayer = $TileMap
@onready var tree_map: TileMapLayer = $TreeMap

enum ElevClass { WATER, LAND, MOUNTAIN }
var _elevation_grid: Array = []
var _biome_grid:     Array = []

# Seed constraints: Vector2i → TileType (never WATER)
var _seed_tiles: Dictionary = {}
# Per-seed elevation attractor radius: Vector2i → float
var _seed_radii: Dictionary = {}
# Per-seed climate attractor radius: Vector2i → float
var _seed_climate_radii: Dictionary = {}

var _rng := RandomNumberGenerator.new()

# Noise layers: { noise, warp, warp_amp }
var _layer_elev:  Dictionary = {}
var _layer_temp:  Dictionary = {}
var _layer_humid: Dictionary = {}
var _layer_tree:  Dictionary = {}

# Tree density grid: indexed [y][x] → MapConfig.TreeDensity
var _tree_grid: Array = []

# Gradient parameters (randomised per seed)
var _grad_angle:    float = 0.0
var _grad_strength: float = 0.0
var _grad_dir:      Vector2 = Vector2.RIGHT   # unit vector from angle

# Map centre in tile space
var _centre: Vector2 = Vector2(
	MapConfig.MAP_WIDTH  * 0.5,
	MapConfig.MAP_HEIGHT * 0.5
)
# Max distance from centre to corner (used for normalisation)
var _max_dist: float = Vector2(
	MapConfig.MAP_WIDTH  * 0.5,
	MapConfig.MAP_HEIGHT * 0.5
).length()

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if seed_value == 0:
		seed_value = randi()
	generate()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("ui_accept"):
		seed_value = randi()
		generate()
	if event.is_action_pressed("ui_cancel"):
		generate()

func _regenerate_same() -> void:
	generate()

func _regenerate_new() -> void:
	seed_value = randi()
	generate()

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
func generate() -> void:
	_rng.seed = seed_value
	_seed_tiles.clear()
	_seed_radii.clear()
	_seed_climate_radii.clear()
	_elevation_grid = _make_grid(ElevClass.LAND)
	_biome_grid     = _make_grid(MapConfig.TileType.GROUND)
	_tree_grid      = _make_grid(MapConfig.TreeDensity.NONE)

	_randomise_noise_params()   # noise layers (elev, temp, humid, tree)
	_randomise_gradient()       # directional gradient
	_resolve_constraints()      # seed tiles + per-seed attractor radii
	_build_elevation_grid()     # noise + gradient + attractors → elevation class
	_build_biome_grid()         # temp × humid → biome for LAND tiles
	_apply_seed_overrides()     # hard-set seed tile types
	_smooth_isolated_biomes()   # single pass: remove isolated single-tile biomes
	_build_tree_grid()          # tree density noise → density category per tile
	_write_tilemap()
	_autotile()
	_write_tree_map()
	_autotile_trees()

	_log_land_ratio()
	print("[MapGenerator] seed=%d done." % seed_value)

# ---------------------------------------------------------------------------
# Noise setup
# ---------------------------------------------------------------------------
func _randomise_noise_params() -> void:
	_layer_elev  = _build_layer(seed_value + 0, "elev",
		elev_freq_min,    elev_freq_max,    elev_octaves_min,    elev_octaves_max,    elev_warp_max)
	_layer_temp  = _build_layer(seed_value + 1, "temp",
		climate_freq_min, climate_freq_max, climate_octaves_min, climate_octaves_max, climate_warp_max)
	_layer_humid = _build_layer(seed_value + 2, "humid",
		climate_freq_min, climate_freq_max, climate_octaves_min, climate_octaves_max, climate_warp_max)
	_layer_tree  = _build_layer(seed_value + 3, "tree",
		tree_freq_min,    tree_freq_max,    tree_octaves_min,    tree_octaves_max,    tree_warp_max)

func _build_layer(seed: int, label: String,
	freq_min: float, freq_max: float,
	oct_min: int,   oct_max: int,
	warp_max: float
) -> Dictionary:
	var freq    : float = _rng.randf_range(freq_min, freq_max)
	var octaves : int   = _rng.randi_range(oct_min,  oct_max)
	var warp_amp: float = _rng.randf_range(0.0, warp_max)
	print("[NoiseParams] %s freq=%.3f oct=%d warp=%.1f" % [label, freq, octaves, warp_amp])

	var noise := FastNoiseLite.new()
	noise.seed               = seed
	noise.noise_type         = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency          = freq
	noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves    = octaves
	noise.fractal_lacunarity = MapConfig.NOISE_LACUNARITY
	noise.fractal_gain       = MapConfig.NOISE_GAIN

	var warp := FastNoiseLite.new()
	warp.seed            = seed + 1000
	warp.noise_type      = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp.frequency       = freq * 0.7
	warp.fractal_octaves = 2

	return { "noise": noise, "warp": warp, "warp_amp": warp_amp }

# ---------------------------------------------------------------------------
# Gradient setup
# angle  — random direction in [0, 2π]: the "low" side of the map
# strength — in GRADIENT_STRENGTH_RANGE:
#   low  → nearly full continent (water only from noise dips)
#   high → strong peninsula/island falloff toward angle direction
# _grad_dir points FROM centre TOWARD the "low" side.
# ---------------------------------------------------------------------------
func _randomise_gradient() -> void:
	_grad_angle    = _rng.randf_range(0.0, TAU)
	_grad_strength = _rng.randf_range(gradient_strength_min, gradient_strength_max)
	_grad_dir = Vector2(cos(_grad_angle), sin(_grad_angle))
	print("[Gradient] angle=%.2f strength=%.2f" % [_grad_angle, _grad_strength])

# ---------------------------------------------------------------------------
# Constraint resolver — seed tiles are never WATER (types 1–5)
# ---------------------------------------------------------------------------
func _resolve_constraints() -> void:
	# Valid seed types: GROUND(1), MARSH(2), ROCK(3), SNOW(4)
	# WATER(0) and MOUNTAIN(5) are excluded.
	var valid_types := [
		MapConfig.TileType.GROUND,
		MapConfig.TileType.MARSH,
		MapConfig.TileType.ROCK,
		MapConfig.TileType.SNOW,
	]
	for region in MapConfig.REGIONS:
		var pick: Vector2i = region[_rng.randi_range(0, region.size() - 1)]
		var tile_type: int = valid_types[_rng.randi_range(0, valid_types.size() - 1)]
		var elev_radius: float = _rng.randf_range(
			MapConfig.ATTRACTOR_RADIUS_RANGE[0],
			MapConfig.ATTRACTOR_RADIUS_RANGE[1]
		)
		var climate_radius: float = _rng.randf_range(
			MapConfig.CLIMATE_ATTRACTOR_RADIUS_RANGE[0],
			MapConfig.CLIMATE_ATTRACTOR_RADIUS_RANGE[1]
		)
		_seed_tiles[pick]         = tile_type
		_seed_radii[pick]         = elev_radius
		_seed_climate_radii[pick] = climate_radius

# ---------------------------------------------------------------------------
# Elevation grid construction
#
# For each tile we compute three contributions and sum them:
#
#  1. noise_val  — warped simplex, remapped to [0,1]
#
#  2. grad_val   — directional gradient mask:
#       pos_from_centre = tile_pos - map_centre   (in tile units)
#       dist_norm = length(pos_from_centre) / max_dist   [0,1]
#       dot = dot(normalised(pos_from_centre), _grad_dir) [-1,1]
#       directional_factor = max(0, dot)   (only depresses the "low" side)
#       grad_val = 1 - strength * directional_factor * dist_norm
#     Result: tiles on the "high" side near centre stay close to 1.0;
#     tiles far away on the "low" side are depressed toward (1 - strength).
#     This naturally produces ~80% land when strength is moderate.
#
#  3. attractor weight — smooth quadratic falloff from each seed tile
#       weight = sum of (1 - dist/radius)² for seeds within radius
#       capped at ATTRACTOR_MAX_WEIGHT
#       final_elev = lerp(base_elev, 0.5, attractor_weight)
#
#  final = clamp(noise_val*NOISE_BLEND + grad_val*GRADIENT_BLEND + attractor_contribution, 0, 1)
# ---------------------------------------------------------------------------
func _build_elevation_grid() -> void:
	# radii: seed pos → radius.  targets: seed pos → 0.5 (neutral land) for all.
	var elev_targets : Dictionary = {}
	for seed_pos in _seed_tiles.keys():
		elev_targets[seed_pos] = 0.5
	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			var elev := _compute_elevation(x, y, _seed_radii, elev_targets)
			if elev < water_threshold:
				_elevation_grid[y][x] = ElevClass.WATER
			elif elev > mountain_threshold:
				_elevation_grid[y][x] = ElevClass.MOUNTAIN
			else:
				_elevation_grid[y][x] = ElevClass.LAND

func _compute_elevation(x: int, y: int,
		radii: Dictionary, targets: Dictionary) -> float:
	# 1. Noise
	var noise_val := _sample_warped(_layer_elev, x, y)

	# 2. Directional gradient
	var pos_from_centre := Vector2(x, y) - _centre
	var dist_norm := pos_from_centre.length() / _max_dist
	var grad_val  := 1.0
	if pos_from_centre.length() > 0.001:
		var dot := pos_from_centre.normalized().dot(_grad_dir)
		grad_val = 1.0 - _grad_strength * maxf(0.0, dot) * dist_norm

	# 3. Base elevation from noise + gradient
	var base_elev := noise_val * MapConfig.NOISE_BLEND \
				   + grad_val  * MapConfig.GRADIENT_BLEND

	# 4. Nudge toward 0.5 (neutral land) near seed tiles
	return clampf(_apply_attractor(x, y, base_elev, radii, targets), 0.0, 1.0)

# ---------------------------------------------------------------------------
# Biome grid (fills all cells; only LAND tiles matter for the final output)
# ---------------------------------------------------------------------------
const _MOUNTAIN_TEMP_NUDGE   := 0.25
const _MOUNTAIN_NUDGE_RADIUS := 3   # in tiles — only immediate neighbours

func _build_biome_grid() -> void:
	# Build target dicts for temp and humid from seed climate targets.
	var temp_targets  : Dictionary = {}
	var humid_targets : Dictionary = {}
	for seed_pos in _seed_tiles.keys():
		var t : Dictionary = MapConfig.CLIMATE_TARGETS[_seed_tiles[seed_pos]]
		temp_targets[seed_pos]  = t.temp
		humid_targets[seed_pos] = t.humid

	# Build mountain attractor dicts — radius and targets built per tile below.
	var mountain_radii : Dictionary = {}
	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			if _elevation_grid[y][x] == ElevClass.MOUNTAIN:
				mountain_radii[Vector2i(x, y)] = _MOUNTAIN_NUDGE_RADIUS

	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			var temp  := _sample_warped(_layer_temp,  x, y)
			var humid := _sample_warped(_layer_humid, x, y)
			# Nudge temp and humid toward seed climate targets
			temp  = _apply_attractor(x, y, temp,  _seed_climate_radii, temp_targets)
			humid = _apply_attractor(x, y, humid, _seed_climate_radii, humid_targets)
			# Mountain nudge: each mountain tile pulls temp toward (temp - NUDGE)
			var mountain_targets : Dictionary = {}
			for mpos in mountain_radii.keys():
				mountain_targets[mpos] = temp - _MOUNTAIN_TEMP_NUDGE
			temp = _apply_attractor(x, y, temp, mountain_radii, mountain_targets)
			_biome_grid[y][x] = _classify_climate(temp, humid)

# ---------------------------------------------------------------------------
# Core attractor function
#
# Nudges `current` toward a weighted blend of targets, based on proximity
# to a set of attractor points.
#
# radii_dict:   Dictionary { Vector2i → float }  attractor position → radius
# targets_dict: Dictionary { Vector2i → float }  attractor position → target value
#
# Falloff: quadratic — weight = (1 - dist/radius)²
# Weights are summed, capped at ATTRACTOR_MAX_WEIGHT, then:
#   result = lerpf(current, weighted_average_target, capped_weight)
# ---------------------------------------------------------------------------
func _apply_attractor(x: int, y: int, current: float,
		radii_dict: Dictionary, targets_dict: Dictionary) -> float:
	var total_weight    := 0.0
	var weighted_target := 0.0
	var pos := Vector2(x, y)

	for apos in radii_dict.keys():
		var dist: float = pos.distance_to(Vector2(apos))
		var radius: float = radii_dict[apos]
		if dist >= radius:
			continue
		var t := 1.0 - dist / radius
		var w := t * t
		weighted_target += targets_dict[apos] * w
		total_weight    += w

	if total_weight < 0.001:
		return current

	var blend  := minf(total_weight, MapConfig.ATTRACTOR_MAX_WEIGHT)
	var target := weighted_target / total_weight
	return lerpf(current, target, blend)

func _classify_climate(temp: float, humid: float) -> int:
	var is_hot  := temp  >= temp_hot
	var is_cold := temp  <  temp_cold
	var is_dry  := humid <  humid_dry
	var is_wet  := humid >= humid_wet
	if is_hot  and is_dry: return MapConfig.TileType.ROCK
	if is_hot  and is_wet: return MapConfig.TileType.MARSH
	if is_cold and is_dry: return MapConfig.TileType.SNOW
	return MapConfig.TileType.GROUND

# ---------------------------------------------------------------------------
# Seed overrides — applied after both grids are built.
# Non-water seeds patch biome_grid; elevation_grid is left as LAND
# (attractor already lifted it, so it should be LAND naturally).
# ---------------------------------------------------------------------------
func _apply_seed_overrides() -> void:
	for pos in _seed_tiles:
		var t: int = _seed_tiles[pos]
		# All seeds are non-water, so they live in the LAND band
		_elevation_grid[pos.y][pos.x] = ElevClass.LAND
		_biome_grid[pos.y][pos.x]     = t

# ---------------------------------------------------------------------------
# Final type combiner
# ---------------------------------------------------------------------------
func _final_type(x: int, y: int) -> int:
	match _elevation_grid[y][x]:
		ElevClass.WATER:    return MapConfig.TileType.WATER
		ElevClass.MOUNTAIN: return MapConfig.TileType.MOUNTAIN
		_:                  return _biome_grid[y][x]

# ---------------------------------------------------------------------------
# TileMap writer
# ---------------------------------------------------------------------------
func _write_tilemap() -> void:
	tile_map.clear()
	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0), 0)

# ---------------------------------------------------------------------------
# Autotile pass
# ---------------------------------------------------------------------------
func _autotile() -> void:
	var cells_by_type: Dictionary = {}
	for tile_type in MapConfig.TERRAIN_SETS.keys():
		cells_by_type[tile_type] = []
	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			cells_by_type[_final_type(x, y)].append(Vector2i(x, y))
	for tile_type in cells_by_type:
		var cells: Array = cells_by_type[tile_type]
		if cells.is_empty():
			continue
		var info: Dictionary = MapConfig.TERRAIN_SETS[tile_type]
		tile_map.set_cells_terrain_connect(cells, info["set"], info["terrain"])

# ---------------------------------------------------------------------------
# Isolation smoother (single pass)
# A LAND tile with zero same-type neighbours is visually isolated.
# Replace it with the most common neighbour type (majority vote).
# Seed tiles are protected. Ties keep the current type.
# Water and mountain are skipped — they are handled by elevation, not biome.
# ---------------------------------------------------------------------------
func _smooth_isolated_biomes() -> void:
	var new_biome := _biome_grid.duplicate(true)  # shallow copy of rows
	for y in MapConfig.MAP_HEIGHT:
		new_biome[y] = _biome_grid[y].duplicate()

	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			# Skip non-land tiles
			if _elevation_grid[y][x] != ElevClass.LAND:
				continue
			# Protect seed tiles
			if _seed_tiles.has(Vector2i(x, y)):
				continue

			var current: int = _biome_grid[y][x]
			var has_match := false
			var counts := {}

			for delta in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
				var n: Vector2i = Vector2i(x, y) + delta
				if not _in_bounds(n):
					continue
				if _elevation_grid[n.y][n.x] != ElevClass.LAND:
					continue
				var ntype: int = _biome_grid[n.y][n.x]
				if ntype == current:
					has_match = true
				counts[ntype] = counts.get(ntype, 0) + 1

			if has_match:
				continue   # not isolated — leave unchanged

			# Find majority neighbour type; keep current on tie
			var best_type  := current
			var best_count := 0
			for t in counts:
				if counts[t] > best_count:
					best_count = counts[t]
					best_type  = t

			new_biome[y][x] = best_type

	_biome_grid = new_biome

# ---------------------------------------------------------------------------
# Tree density grid
# ---------------------------------------------------------------------------
func _build_tree_grid() -> void:
	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			var final_type := _final_type(x, y)
			var biome_cap  : int = MapConfig.BIOME_MAX_TREE_DENSITY[final_type]

			# Water and mountain tiles are always empty — skip noise sampling
			if biome_cap == MapConfig.TreeDensity.NONE:
				_tree_grid[y][x] = MapConfig.TreeDensity.NONE
				continue

			var noise_val := _sample_warped(_layer_tree, x, y)
			var raw_density := _classify_tree_density(noise_val)

			# Cap density at what this biome allows
			_tree_grid[y][x] = mini(raw_density, biome_cap)

func _classify_tree_density(value: float) -> int:
	if value < tree_density_low:          return MapConfig.TreeDensity.NONE
	if value < tree_density_mid:          return MapConfig.TreeDensity.LOW
	if value < tree_density_light_forest: return MapConfig.TreeDensity.MID
	if value < tree_density_dense_forest: return MapConfig.TreeDensity.LIGHT_FOREST
	return MapConfig.TreeDensity.DENSE_FOREST

# ---------------------------------------------------------------------------
# Tree TileMap writer
# ---------------------------------------------------------------------------
func _write_tree_map() -> void:
	tree_map.clear()
	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			tree_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0), 0)

func _autotile_trees() -> void:
	var cells_by_density: Dictionary = {}
	for density in MapConfig.TREE_TERRAIN_SETS.keys():
		cells_by_density[density] = []

	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			cells_by_density[_tree_grid[y][x]].append(Vector2i(x, y))

	for density in cells_by_density:
		var cells: Array = cells_by_density[density]
		if cells.is_empty():
			continue
		var info: Dictionary = MapConfig.TREE_TERRAIN_SETS[density]
		tree_map.set_cells_terrain_connect(cells, info["set"], info["terrain"])

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
func _sample_warped(layer: Dictionary, x: int, y: int) -> float:
	var fx   := float(x)
	var fy   := float(y)
	var amp  : float         = layer.warp_amp
	var warp : FastNoiseLite = layer.warp
	var noise: FastNoiseLite = layer.noise
	var dx := warp.get_noise_2d(fx,        fy + 43.7) * amp
	var dy := warp.get_noise_2d(fx + 91.3, fy       ) * amp
	return (noise.get_noise_2d(fx + dx, fy + dy) + 1.0) * 0.5

func _make_grid(default_value) -> Array:
	var g: Array = []
	g.resize(MapConfig.MAP_HEIGHT)
	for y in MapConfig.MAP_HEIGHT:
		var row: Array = []
		row.resize(MapConfig.MAP_WIDTH)
		row.fill(default_value)
		g[y] = row
	return g

func _log_land_ratio() -> void:
	var land_count := 0
	for y in MapConfig.MAP_HEIGHT:
		for x in MapConfig.MAP_WIDTH:
			if _elevation_grid[y][x] != ElevClass.WATER:
				land_count += 1
	var ratio := float(land_count) / float(MapConfig.MAP_WIDTH * MapConfig.MAP_HEIGHT)
	print("[MapGenerator] land ratio=%.1f%%" % (ratio * 100.0))

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < MapConfig.MAP_WIDTH \
	   and pos.y >= 0 and pos.y < MapConfig.MAP_HEIGHT
