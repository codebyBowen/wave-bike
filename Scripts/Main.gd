extends Node2D
## 主场景 - 整合所有游戏系统

# 节点引用
@onready var terrain: Terrain = $Terrain
@onready var bike: Bike = $Bike
@onready var score_system: ScoreSystem = $ScoreSystem
@onready var hud = $GameHUD
@onready var game_over_screen = $GameOver
@onready var background: ColorRect = $Background

func _ready():
	# 添加标识组
	terrain.add_to_group("terrain")

	# 初始化背景
	setup_background()

	# 让 GameManager 找到所有节点
	GameManager.find_game_nodes()

	# 开始游戏
	GameManager.start_game()

	print("主场景加载完成 - 游戏开始!")

func setup_background():
	"""设置赛博朋克风格背景"""
	if background:
		# 简单的深蓝紫色背景
		background.color = Color(0.05, 0.05, 0.2, 1.0)
