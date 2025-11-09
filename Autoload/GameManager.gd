extends Node
## 游戏管理器 - 控制游戏状态和流程

enum GameState {
	MENU,      # 主菜单
	PLAYING,   # 游戏中
	PAUSED,    # 暂停
	GAME_OVER  # 游戏结束
}

var current_state := GameState.MENU
var bike: Bike = null
var terrain: Terrain = null
var score_system: ScoreSystem = null

func _ready():
	# 连接信号
	SignalBus.bike_crashed.connect(_on_bike_crashed)

	print("游戏管理器初始化完成")

func _input(event):
	"""处理全局输入"""
	# 暂停/继续
	if event.is_action_pressed("pause"):
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()

	# 重启
	if event.is_action_pressed("restart"):
		if current_state == GameState.GAME_OVER:
			restart_game()

func start_game():
	"""开始游戏"""
	print("游戏开始！")
	current_state = GameState.PLAYING

	# 发送信号
	SignalBus.game_started.emit()

	# 取消暂停（如果之前暂停了）
	get_tree().paused = false

func pause_game():
	"""暂停游戏"""
	if current_state != GameState.PLAYING:
		return

	print("游戏暂停")
	current_state = GameState.PAUSED
	get_tree().paused = true
	SignalBus.game_paused.emit()

func resume_game():
	"""继续游戏"""
	if current_state != GameState.PAUSED:
		return

	print("游戏继续")
	current_state = GameState.PLAYING
	get_tree().paused = false
	SignalBus.game_resumed.emit()

func restart_game():
	"""重启游戏"""
	print("重启游戏")

	# 重新初始化随机种子，确保地形变化
	randomize()

	# 重载主场景
	get_tree().paused = false
	get_tree().reload_current_scene()

func game_over():
	"""游戏结束"""
	if current_state == GameState.GAME_OVER:
		return

	print("游戏结束")
	current_state = GameState.GAME_OVER

	# 获取最终统计
	var final_score = 0
	var final_distance = 0.0

	if score_system:
		var stats = score_system.get_stats()
		final_score = stats.score
		final_distance = stats.distance

	# 保存最高分
	if final_score > Global.high_score:
		Global.high_score = final_score
		Global.save_settings()

	# 发送信号
	SignalBus.game_over.emit(final_score, final_distance)

func _on_bike_crashed(reason: String):
	"""摩托车摔车 - 延迟后游戏结束"""
	print("检测到摔车: %s" % reason)

	# 等待 1.5 秒让玩家看到摔车动画
	await get_tree().create_timer(1.5).timeout

	# 触发游戏结束
	game_over()

func find_game_nodes():
	"""查找游戏节点（供外部调用）"""
	bike = get_tree().get_first_node_in_group("bike")
	terrain = get_tree().get_first_node_in_group("terrain")
	score_system = get_tree().get_first_node_in_group("score_system")

func get_current_state() -> GameState:
	"""获取当前状态"""
	return current_state
