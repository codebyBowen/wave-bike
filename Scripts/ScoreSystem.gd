extends Node
class_name ScoreSystem
## 得分系统 - 计算分数、连击、距离等

# 分数数据
var current_score := 0
var distance_meters := 0.0
var combo := 0
var max_combo := 0
var total_flips := 0
var total_tricks := 0

# 连击倍率
var combo_multiplier := 1.0

# 地形滚动距离追踪
var total_scroll_distance := 0.0

func _ready():
	# 连接信号
	SignalBus.trick_performed.connect(_on_trick_performed)
	SignalBus.bike_crashed.connect(_on_crash)
	SignalBus.game_started.connect(_on_game_started)

	add_to_group("score_system")
	print("得分系统初始化完成")

func _process(delta):
	# 更新距离（基于地形滚动）
	update_distance(delta)

func update_distance(delta: float):
	"""更新行驶距离 - 基于地形滚动速度"""
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("get"):
		# 累积地形滚动的距离
		total_scroll_distance += terrain.scroll_speed * delta
		distance_meters = total_scroll_distance / 100.0  # 100 像素 = 1 米
		SignalBus.distance_updated.emit(distance_meters)

func _on_trick_performed(flips: int, quality: String, air_time: float):
	"""处理特技完成事件"""
	# 获取基础分数
	var base_score = Global.get_flip_score(flips)

	# 获取落地质量倍率
	var quality_mult = Global.get_landing_multiplier(quality)

	# 滞空时间奖励
	var air_bonus = int(air_time * 50)

	# 更新连击
	if quality == "PERFECT" or flips > 0:
		combo += 1
		max_combo = max(combo, max_combo)
		update_combo_multiplier()
		SignalBus.combo_increased.emit(combo)

	# 计算总分
	var trick_score = int((base_score + air_bonus) * quality_mult * combo_multiplier)

	# 更新统计
	current_score += trick_score
	total_flips += flips
	if flips > 0 or quality == "PERFECT":
		total_tricks += 1

	# 检查是否打破最高分
	if current_score > Global.high_score:
		Global.high_score = current_score
		SignalBus.high_score_beaten.emit(current_score)

	# 发送信号
	SignalBus.score_changed.emit(current_score)
	SignalBus.show_trick_popup.emit(flips, quality, trick_score)

	print("得分！%d 翻 - %s = %d 分 (连击 x%d, 倍率 %.1fx)" % [flips, quality, trick_score, combo, combo_multiplier])

func update_combo_multiplier():
	"""更新连击倍率"""
	if combo >= 10:
		combo_multiplier = 5.0
	elif combo >= 7:
		combo_multiplier = 4.0
	elif combo >= 5:
		combo_multiplier = 3.0
	elif combo >= 3:
		combo_multiplier = 2.0
	else:
		combo_multiplier = 1.0

func _on_crash(reason: String):
	"""摔车 - 打断连击"""
	if combo > 0:
		print("连击中断！(x%d)" % combo)
		combo = 0
		combo_multiplier = 1.0
		SignalBus.combo_broken.emit()

func _on_game_started():
	"""游戏开始 - 重置数据"""
	reset()

func reset():
	"""重置所有数据"""
	current_score = 0
	distance_meters = 0.0
	combo = 0
	max_combo = 0
	total_flips = 0
	total_tricks = 0
	combo_multiplier = 1.0
	total_scroll_distance = 0.0

	print("得分系统已重置")

func get_stats() -> Dictionary:
	"""获取统计数据"""
	return {
		"score": current_score,
		"distance": distance_meters,
		"combo": combo,
		"max_combo": max_combo,
		"total_flips": total_flips,
		"total_tricks": total_tricks
	}
