extends Node

enum actions {
	ATTACK,
	WAIT
}

const baseUISize: Vector2i = Vector2i(768, 432)

const CELL_SIZE: int = 16
const neighbors: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1) 
]
const cellRings = {
	1: [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)],
	2: [
		Vector2i(-2, 0), Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)
	],
	3: [
		Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, 0), Vector2i(0, 3),
		Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(2, -1),
		Vector2i(2, 1), Vector2i(1, 2), Vector2i(-1, 2), Vector2i(-2, 1)
	]
}

# ========== STATS ==========

enum Stats { HP, STR, MAG, AIM, DEF, SPD }
enum Growth { S, A, B, C, D }
const GROWTH_RATES = [0.90, 0.75, 0.55, 0.35, 0.15]
const HIDDEN_TRAIT_GROWTH = 0.25
const GROWTH_AMOUNTS = [4, 1, 1, 5, 5, 1]
const BASE_STATS = [16, 3, 3, 65, 0, 3]
const BASE_MOVE = 4
const MAX_LEVEL = 4
const XP_PER_BASE_LEVEL = 5
const XP_PER_PROMOTE_LEVEL = 5
const BASE_MOB_XP = 1
const STRONG_MOB_XP = 1

# ========== SKILLS ==========

enum Skills {
	DRAGON_SKIN, LIGHT_FOOTED, SPELL_WHITE_1,
	SPELL_PURPLE_1, SPELL_GREEN_1
}

const SK_NAME = 0
const SK_DESC = 1
const SKILL_DATA = {
	Skills.DRAGON_SKIN: ["Dragon skin", "-2 to all incoming damages"],
	Skills.LIGHT_FOOTED: ["Light footed", "+1 to MOV"],
	Skills.SPELL_WHITE_1: ["Minor white magic", "Unlock a 1st level white spell"],
	Skills.SPELL_PURPLE_1: ["Minor purple magic", "Unlock a 1st level purple spell"],
	Skills.SPELL_GREEN_1: ["Minor green magic", "Unlock a 1st level green spell"],
}

# ========== SPELLS ==========

enum Spells {
	HEAL, MISSILE, PUSH
}

enum Schools {
	WHITE, BLACK, GREEN, PURPLE
}

enum Targets {
	ENEMY, ALLY, CELL
}

const SP_NAME = 0
const SP_SCHOOL = 1
const SP_RANGE = 2
const SP_TARGET = 3
const SP_USES = 4
const SP_DESC = 5
const SPELL_DATA = {
	Spells.HEAL: ["Heal", Schools.WHITE, Vector2i(1, 1), Targets.ALLY, Vector2i(1, 0), "Heal an ally for 50% of its max HP"],
}

# ========== WEAPONS ==========

enum Weapons {
	SHORT_BOW, RUSTY_DAGGER, RUSTY_AXE, OLD_STAFF
}

enum WeaponTypes {
	STAFF, DAGGER, BOW, SWORD, AXE, MACE
}

const WP_NAME = 0
const WP_SPRITE = 1
const WP_DMG = 2
const WP_STAT = 3
const WP_RANGE = 4
const WP_EFFECT = 4
const WEAPON_DATA = {
	Weapons.RUSTY_DAGGER: ["Rusty dagger", 0, Vector2i(1, 0), Stats.STR, Vector2i(1, 1), null],
	Weapons.RUSTY_AXE: ["Rusty axe", 0, Vector2i(1, 0), Stats.STR, Vector2i(1, 1), null],
	Weapons.SHORT_BOW: ["Short bow", 0, Vector2i(1, 0), Stats.STR, Vector2i(2, 2), null],
	Weapons.OLD_STAFF: ["Old staff", 0, Vector2i(1, 0), Stats.STR, Vector2i(1, 1), null],
}

# ========== CLASSES ==========

enum Classes {
	FIGHTER, THIEF, SCOUT, MAGE, CLERIC,
	WARRIOR, DUELIST, ASSASSIN, RANGER, DRUID, BARD,
	SORCERER, NECROMANCER, PRIEST, PALADIN
}

const CL_NAME = 0
const CL_SPRITE = 1
const CL_FAV_STAT = 2
const CL_SKILL = 3
const CL_IS_BASE = 4
const CL_GROWTH = 5
const CL_WEAPONS = 6
const CL_KIT = 7
const CLASS_DATA = {
	Classes.FIGHTER: ["Fighter", 0, Stats.STR, Skills.DRAGON_SKIN, true,
		[Growth.A, Growth.B, Growth.D, Growth.C, Growth.C, Growth.C], 
		[WeaponTypes.STAFF, WeaponTypes.DAGGER, WeaponTypes.SWORD, WeaponTypes.AXE, WeaponTypes.MACE],
		[Weapons.RUSTY_AXE],
	],
	Classes.THIEF: ["Thief", 0, Stats.SPD, Skills.LIGHT_FOOTED, true,
		[Growth.C, Growth.C, Growth.D, Growth.A, Growth.D, Growth.A], 
		[WeaponTypes.DAGGER],
		[Weapons.RUSTY_DAGGER],
	],
	Classes.CLERIC: ["Cleric", 0, Stats.DEF, Skills.SPELL_WHITE_1, true,
		[Growth.C, Growth.B, Growth.B, Growth.C, Growth.C, Growth.D], 
		[WeaponTypes.STAFF, WeaponTypes.MACE],
		[Weapons.OLD_STAFF],
	],
	Classes.SCOUT: ["Scout", 0, Stats.AIM, Skills.SPELL_GREEN_1, true,
		[Growth.B, Growth.C, Growth.C, Growth.B, Growth.D, Growth.B], 
		[WeaponTypes.DAGGER, WeaponTypes.SWORD, WeaponTypes.BOW],
		[Weapons.SHORT_BOW, Weapons.RUSTY_DAGGER],
	],
	Classes.MAGE: ["Mage", 0, Stats.MAG, Skills.SPELL_PURPLE_1, true,
		[Growth.C, Growth.D, Growth.A, Growth.B, Growth.D, Growth.C], 
		[WeaponTypes.STAFF],
		[Weapons.OLD_STAFF],
	],
}

# ========== PROMOTIONS ==========

enum Promotions {
	DEVOTION, STRENGTH, VIGILANCE, WISDOM, KNOWLEDGE
}

const PR_NAME = 0
const PR_SPRITE = 1
const PR_PATHS = 2
const PROMOTION_DATA = {
	Promotions.DEVOTION: ["Crystal of devotion", 0, [
			Vector2(Classes.CLERIC, Classes.PRIEST),
			Vector2(Classes.CLERIC, Classes.PALADIN),
			Vector2(Classes.FIGHTER, Classes.PALADIN),
			Vector2(Classes.FIGHTER, Classes.WARRIOR),
		],
	],
	Promotions.STRENGTH: ["Crystal of strength", 0, [
			Vector2(Classes.FIGHTER, Classes.WARRIOR),
			Vector2(Classes.FIGHTER, Classes.DUELIST),
			Vector2(Classes.THIEF, Classes.DUELIST),
			Vector2(Classes.THIEF, Classes.ASSASSIN),
		],
	],
	Promotions.VIGILANCE: ["Crystal of vigilance", 0, [
			Vector2(Classes.THIEF, Classes.ASSASSIN),
			Vector2(Classes.THIEF, Classes.RANGER),
			Vector2(Classes.SCOUT, Classes.RANGER),
			Vector2(Classes.SCOUT, Classes.DRUID),
		],
	],
	Promotions.WISDOM: ["Crystal of wisdom", 0, [
			Vector2(Classes.SCOUT, Classes.DRUID),
			Vector2(Classes.SCOUT, Classes.BARD),
			Vector2(Classes.MAGE, Classes.BARD),
			Vector2(Classes.MAGE, Classes.SORCERER),
		],
	],
	Promotions.KNOWLEDGE: ["Crystal of knowledge", 0, [
			Vector2(Classes.MAGE, Classes.SORCERER),
			Vector2(Classes.MAGE, Classes.NECROMANCER),
			Vector2(Classes.CLERIC, Classes.NECROMANCER),
			Vector2(Classes.CLERIC, Classes.PRIEST),
		],
	],
}

# ========== MONSTERS ==========

enum Monsters {
	GOBLIN, GOBLIN_ELITE, GOBLIN_ARCHER
}

enum MonsterPacks {
	GOBLINS
}

const PA_MONSTERS = 0
const PA_THEMES = 1
const PACK_DATA = {
	MonsterPacks.GOBLINS: [
		[],
		[],
	],
}

enum Profiles {	Normal, Elite }
const PR_STATS = 0
const PRO_GROWTH = 1
const PROFILE_DATA = {
	Profiles.Normal: [
		[7, 2, 1, 80, 0, 2],
		[Growth.B, Growth.B, Growth.D, Growth.B, Growth.C, Growth.C],
	],
	Profiles.Elite: [
		[7, 2, 1, 80, 0, 2],
		[Growth.B, Growth.B, Growth.D, Growth.B, Growth.C, Growth.C],
	],
}

const MO_NAME = 0
const MO_SPRITE = 1
const MO_RANGE = 2
const MO_IS_STRONG = 3
const MO_IS_FRONT = 4
const MO_MOVE = 5
const MO_PROFILE = 6
const MONSTER_DATA = {
	Monsters.GOBLIN: ["Goblin", 0, Vector2i(1, 1), false, true, 0, Profiles.Normal],
	Monsters.GOBLIN_ARCHER: ["Goblin archer", 0, Vector2i(2, 2), false, false, 0, Profiles.Normal],
	Monsters.GOBLIN_ELITE: ["Goblin elite", 0, Vector2i(1, 1), true, true, 0, Profiles.Elite],
}

# ========== STATUSES ==========

enum Triggers {
	PASSIVE, END_TURN, START_TURN, START_BATTLE, END_BATTLE,
	ON_HIT, ON_KILL, ON_FIGHT, ON_DEATH
}

# ========== ITEMS ==========

# ========== MAPS ==========

const STARTING_UNITS = 3
const NB_ACTS = 3
const BATTLES_PER_ACT = 3

enum MapSizes { 
	S2x2, S3x2, M4x2, M3x3, L4x3,
	L5x3, L4x4, XL6x3, XL5x4
}

const MAP_SIZES_PER_LEVEL = [
	[MapSizes.S2x2, MapSizes.S3x2],
	[MapSizes.S3x2, MapSizes.M4x2],
	[MapSizes.M4x2, MapSizes.M3x3, MapSizes.L4x3],
	[MapSizes.M3x3, MapSizes.L4x3, MapSizes.L5x3],
	[MapSizes.L4x3, MapSizes.L5x3, MapSizes.L4x4],
	[MapSizes.L5x3, MapSizes.L4x4, MapSizes.XL6x3, MapSizes.XL5x4],
]

# Total items: 12
const ITEMS_PER_REWARD = Vector2i(1, 2) # [All missions, Item missions]
enum Rewards { SINGLE_UNIT, UNITS, PROMOTIONS, UNITS_AND_PROMOTIONS, ITEMS, RESSURECTION, NOTHING }

# Max units: 13/2 Min units: 7/7
const BATTLE_REWARDS = {
	0: [Rewards.SINGLE_UNIT, Rewards.ITEMS, Rewards.UNITS, Rewards.PROMOTIONS],
	1: [Rewards.SINGLE_UNIT, Rewards.ITEMS, Rewards.UNITS_AND_PROMOTIONS, Rewards.RESSURECTION],
	2: [Rewards.UNITS_AND_PROMOTIONS, Rewards.ITEMS, Rewards.UNITS_AND_PROMOTIONS, Rewards.NOTHING],
}

const REGEN_PER_BATTLE = 0.30
const REGEN_PER_BOSS = 1.0
const LVL_PER_BATTLE = 0.5

# ========== OBJECTIVES ==========

enum Objectives { EXTERMINATE, ELIMINATE, SURVIVE, FLEE }

# (E/E, E/A, A/A) for each act
const OBJECTIVES_REPARTITION = [
	[Vector3i(2, 0, 1), Vector3i(1, 2, 0), Vector3i(1, 1, 1)],
	[Vector3i(2, 0, 1), Vector3i(1, 1, 1), Vector3i(2, 1, 0)],
	[Vector3i(2, 0, 1), Vector3i(2, 1, 0), Vector3i(1, 0, 2)],
	[Vector3i(2, 0, 1), Vector3i(2, 0, 1), Vector3i(1, 1, 1)],
	[Vector3i(2, 1, 0), Vector3i(1, 1, 1), Vector3i(1, 1, 1)],
	
	[Vector3i(2, 0, 1), Vector3i(1, 1, 1), Vector3i(1, 2, 0)],
	[Vector3i(2, 0, 1), Vector3i(2, 1, 0), Vector3i(1, 1, 1)],
	[Vector3i(2, 0, 1), Vector3i(1, 0, 2), Vector3i(2, 1, 0)],
	[Vector3i(2, 0, 1), Vector3i(1, 1, 1), Vector3i(2, 0, 1)],
	[Vector3i(2, 1, 0), Vector3i(1, 1, 1), Vector3i(1, 1, 1)],
]

# ========== GENERATION ==========

# Chest generation
const CHEST_XP_BASE = 2.0
const CHEST_XP_PER_ACT = 4.0 # 6 -> 10 -> 14

# Monsters generation
const FRONT_MOB_ON_BACK_CHANCES = 0.25
const RARE_MOB_REROLL = 0.65
const NORMAL_NOB_VALUE = 0.9
const STRONG_MOB_VALUE = 1.5
const MOB_NB_BASE = 1.0
const MOB_NB_PER_ACT = 7.0 # 8 -> 15 -> 22

# ========== DIFFICULTIES ==========

enum Difficulties { EASY, NORMAL, HARD, UNFAIR }
enum DifficultyVariables { FLEEING_CASUALTIES, ENEMY_STATS, HEAL_PER_BATTLE, BONUS_XP }

const DF_NAME = 0
const DF_DESC = 1
const DF_VAR = 2
const DIFFICULTY_DATA = {
	Difficulties.EASY: [ "Easy", "TODO description",
		[0.5, 0.8, 1.5, 1.2],
	],
	Difficulties.NORMAL: [ "Normal", "TODO description",
		[1.0, 1.0, 1.0, 1.0],
	],
	Difficulties.HARD: [ "Hard", "TODO description",
		[1.0, 1.2, 0.5, 0.8],
	],
	Difficulties.UNFAIR: [ "Unfair", "TODO description",
		[2.0, 1.4, 0.5, 0.6],
	],
}

const VR_NAME = 0
const VR_DESC = 1
const VARIABLE_DATA = {
	DifficultyVariables.FLEEING_CASUALTIES: ["Fleeing casualties", "TODO description"],
	DifficultyVariables.ENEMY_STATS: ["Enemy strength", "TODO description"],
	DifficultyVariables.HEAL_PER_BATTLE: ["Heal per battle", "TODO description"],
	DifficultyVariables.BONUS_XP: ["Bonus experience", "TODO description"],
}
