# map_config.gd
class_name MapConfig

# ---------------------------------------------------------------------------
# Map dimensions
# ---------------------------------------------------------------------------
const MAP_WIDTH  := 36
const MAP_HEIGHT := 27

# ---------------------------------------------------------------------------
# Tile types
# ---------------------------------------------------------------------------
enum TileType {
	WATER,
	GROUND,
	MARSH,
	ROCK,
	SNOW,
	MOUNTAIN,
}

const TILE_TYPE_COUNT := 6   # seed tiles are GROUND/MARSH/ROCK/SNOW only (no WATER, no MOUNTAIN)

const TILE_NAMES := {
	TileType.WATER:    "water",
	TileType.GROUND:   "ground",
	TileType.MARSH:    "marsh",
	TileType.ROCK:     "rock",
	TileType.SNOW:     "snow",
	TileType.MOUNTAIN: "mountain",
}

# ---------------------------------------------------------------------------
# Elevation classification
# ---------------------------------------------------------------------------
const WATER_THRESHOLD    := 0.30
const MOUNTAIN_THRESHOLD := 0.78

# Target land ratio — gradient strength is tuned around this
const TARGET_LAND_RATIO  := 0.80

# ---------------------------------------------------------------------------
# Directional gradient (Option B)
# Angle and strength are randomised per seed.
# Strength 0.0 → nearly flat (full continent, water only from noise dips)
# Strength 1.0 → strong falloff in one direction (peninsula / island)
# ---------------------------------------------------------------------------
const GRADIENT_STRENGTH_RANGE := [0.2, 0.85]

# How much of the final elevation is noise vs gradient-shaped.
# Higher = gradient dominates shape, noise adds texture.
const NOISE_BLEND := 0.45
const GRADIENT_BLEND := 0.55   # must sum to 1 with NOISE_BLEND

# ---------------------------------------------------------------------------
# Elevation attractor parameters
# Each seed tile pulls surrounding elevation toward 0.5 (neutral land).
# Radius is randomised per seed in this range (in tiles).
# ---------------------------------------------------------------------------
const ATTRACTOR_RADIUS_RANGE  := [3.0, 5.0]
# Maximum lerp weight toward 0.5 at distance 0
const ATTRACTOR_MAX_WEIGHT    := 0.95

# ---------------------------------------------------------------------------
# Climate attractor parameters
# Each seed tile propagates its climate (temp + humid targets) to neighbours.
# Uses a separate radius range from elevation attractors.
# ---------------------------------------------------------------------------
const CLIMATE_ATTRACTOR_RADIUS_RANGE := [2.0, 4.0]
# Maximum lerp weight toward the seed's climate targets
const CLIMATE_ATTRACTOR_MAX_WEIGHT   := 0.70

# Climate lerp targets per seed TileType: { temp_target, humid_target }
# Ground → neutral (0.5, 0.5)
# Marsh  → hot + wet
# Rock   → hot + dry
# Snow   → cold + dry
const CLIMATE_TARGETS := {
	TileType.GROUND: { "temp": 0.5, "humid": 0.5 },
	TileType.MARSH:  { "temp": 0.8, "humid": 0.8 },
	TileType.ROCK:   { "temp": 0.8, "humid": 0.2 },
	TileType.SNOW:   { "temp": 0.2, "humid": 0.2 },
}

# ---------------------------------------------------------------------------
# Climate classification — 3×3 grid
# ---------------------------------------------------------------------------
const TEMP_COLD  := 0.35
const TEMP_HOT   := 0.65
const HUMID_DRY  := 0.35
const HUMID_WET  := 0.65

# ---------------------------------------------------------------------------
# Noise fixed parameters (per-layer ranges are export vars in MapGenerator)
# ---------------------------------------------------------------------------
const NOISE_LACUNARITY := 2.0
const NOISE_GAIN       := 0.5

# ---------------------------------------------------------------------------
# Constraint regions (8 regions — seed tiles are never water)
# ---------------------------------------------------------------------------
const REGIONS: Array = [
	[Vector2i(2,2),  Vector2i(3,2),  Vector2i(4,2),
	 Vector2i(2,3),  Vector2i(3,3),  Vector2i(4,3),  Vector2i(2,4),  Vector2i(3,4)],
	[Vector2i(15,1), Vector2i(16,1), Vector2i(17,1), Vector2i(18,1),
	 Vector2i(15,2), Vector2i(16,2), Vector2i(17,2), Vector2i(18,2),
	 Vector2i(16,3), Vector2i(17,3)],
	[Vector2i(31,2), Vector2i(32,2), Vector2i(33,2),
	 Vector2i(31,3), Vector2i(32,3), Vector2i(33,3), Vector2i(32,4), Vector2i(33,4)],
	[Vector2i(2,11), Vector2i(3,11), Vector2i(4,11),
	 Vector2i(2,12), Vector2i(3,12), Vector2i(4,12),
	 Vector2i(2,13), Vector2i(3,13), Vector2i(4,13)],
	[Vector2i(16,11),Vector2i(17,11),Vector2i(18,11),
	 Vector2i(16,12),Vector2i(17,12),Vector2i(18,12),
	 Vector2i(16,13),Vector2i(17,13),Vector2i(18,13)],
	[Vector2i(31,11),Vector2i(32,11),Vector2i(33,11),
	 Vector2i(31,12),Vector2i(32,12),Vector2i(33,12),
	 Vector2i(31,13),Vector2i(32,13),Vector2i(33,13)],
	[Vector2i(2,22), Vector2i(3,22), Vector2i(4,22),
	 Vector2i(2,23), Vector2i(3,23), Vector2i(4,23),  Vector2i(2,24), Vector2i(3,24)],
	[Vector2i(31,22),Vector2i(32,22),Vector2i(33,22),
	 Vector2i(31,23),Vector2i(32,23),Vector2i(33,23), Vector2i(32,24),Vector2i(33,24)],
]

# ---------------------------------------------------------------------------
# Tree density categories
# ---------------------------------------------------------------------------
enum TreeDensity {
	NONE,
	LOW,
	MID,
	LIGHT_FOREST,
	DENSE_FOREST,
}

# Per-biome maximum allowed density category.
# The generator never exceeds this cap regardless of noise value.
const BIOME_MAX_TREE_DENSITY := {
	TileType.WATER:    TreeDensity.NONE,
	TileType.MOUNTAIN: TreeDensity.NONE,
	TileType.ROCK:     TreeDensity.DENSE_FOREST,  # artist handles sparse look in TileSet
	TileType.SNOW:     TreeDensity.DENSE_FOREST,
	TileType.MARSH:    TreeDensity.DENSE_FOREST,
	TileType.GROUND:   TreeDensity.DENSE_FOREST,
}

# Tree density TileSet terrain indices (second TileMapLayer)
# Must match your tree TileSet terrain set IDs in the Godot editor.
const TREE_TERRAIN_SETS := {
	TreeDensity.NONE:         { "set": 0, "terrain": 0 },
	TreeDensity.LOW:          { "set": 0, "terrain": 1 },
	TreeDensity.MID:          { "set": 0, "terrain": 2 },
	TreeDensity.LIGHT_FOREST: { "set": 0, "terrain": 3 },
	TreeDensity.DENSE_FOREST: { "set": 0, "terrain": 4 },
}

# ---------------------------------------------------------------------------
# TileSet terrain indices
# ---------------------------------------------------------------------------
const TERRAIN_SETS := {
	TileType.WATER:    { "set": 0, "terrain": 0 },
	TileType.GROUND:   { "set": 0, "terrain": 1 },
	TileType.MARSH:    { "set": 0, "terrain": 4 },
	TileType.ROCK:     { "set": 0, "terrain": 2 },
	TileType.SNOW:     { "set": 0, "terrain": 3 },
	TileType.MOUNTAIN: { "set": 0, "terrain": 5 },
}
