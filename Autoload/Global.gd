extends Node
## 全局变量和工具函数

# 游戏状态
var total_rotation := 0.0  # 当前空中总旋转角度（用于空翻计数）
var current_score := 0
var high_score := 0

# 游戏配置
var sound_enabled := true
var music_enabled := true

# 常量
const PERFECT_ANGLE := 5.0  # 完美落地角度范围（度）
const GREAT_ANGLE := 15.0   # 优秀落地角度范围
const GOOD_ANGLE := 30.0    # 良好落地角度范围

# 得分倍率
const PERFECT_MULTIPLIER := 3.0
const GREAT_MULTIPLIER := 2.0
const GOOD_MULTIPLIER := 1.0

# 空翻基础分数
const FLIP_SCORES := {
	1: 200,
	2: 500,
	3: 1500,
	4: 5000
}

func _ready():
	randomize()  # 初始化随机种子，确保每次游戏地形不同
	load_settings()

func get_flip_score(flips: int) -> int:
	"""获取空翻基础分数"""
	if flips in FLIP_SCORES:
		return FLIP_SCORES[flips]
	else:
		return flips * 2000  # 5 翻及以上

func get_landing_multiplier(quality: String) -> float:
	"""获取落地质量倍率"""
	match quality:
		"PERFECT":
			return PERFECT_MULTIPLIER
		"GREAT":
			return GREAT_MULTIPLIER
		"GOOD":
			return GOOD_MULTIPLIER
		_:
			return 1.0

func normalize_angle(angle_deg: float) -> float:
	"""将角度归一化到 0-180 度"""
	var normalized = abs(angle_deg)
	if normalized > 180:
		normalized = 360 - normalized
	return normalized

func save_settings():
	"""保存游戏设置"""
	var config = ConfigFile.new()
	config.set_value("settings", "sound_enabled", sound_enabled)
	config.set_value("settings", "music_enabled", music_enabled)
	config.set_value("game", "high_score", high_score)
	config.save("user://wave_rider_settings.cfg")

func load_settings():
	"""加载游戏设置"""
	var config = ConfigFile.new()
	var err = config.load("user://wave_rider_settings.cfg")
	if err == OK:
		sound_enabled = config.get_value("settings", "sound_enabled", true)
		music_enabled = config.get_value("settings", "music_enabled", true)
		high_score = config.get_value("game", "high_score", 0)
