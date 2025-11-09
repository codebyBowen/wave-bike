extends CanvasLayer
## 游戏结束界面 - 显示统计和重试选项

# 节点引用
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $Panel/VBoxContainer/StatsContainer/ScoreLabel
@onready var distance_label: Label = $Panel/VBoxContainer/StatsContainer/DistanceLabel
@onready var flips_label: Label = $Panel/VBoxContainer/StatsContainer/FlipsLabel
@onready var combo_label: Label = $Panel/VBoxContainer/StatsContainer/ComboLabel
@onready var restart_label: Label = $Panel/VBoxContainer/RestartLabel

func _ready():
	# 连接信号
	SignalBus.game_over.connect(_on_game_over)

	# 初始隐藏
	visible = false

func _on_game_over(final_score: int, final_distance: float):
	"""显示游戏结束界面"""
	# 获取统计数据
	var score_sys = get_tree().get_first_node_in_group("score_system")
	if score_sys:
		var stats = score_sys.get_stats()
		display_stats(stats)
	else:
		# 备用显示
		score_label.text = "最终分数: %d" % final_score
		distance_label.text = "行驶距离: %.1fm" % final_distance

	# 显示界面
	visible = true

	# 入场动画
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)

func display_stats(stats: Dictionary):
	"""显示统计数据"""
	score_label.text = "最终分数: %d" % stats.score
	distance_label.text = "行驶距离: %.1fm" % stats.distance
	flips_label.text = "总空翻数: %d" % stats.total_flips
	combo_label.text = "最高连击: x%d" % stats.max_combo

	# 如果打破了最高分
	if stats.score >= Global.high_score:
		title_label.text = "新纪录！"
		title_label.modulate = Color.GOLD
	else:
		title_label.text = "游戏结束"
		title_label.modulate = Color.WHITE
