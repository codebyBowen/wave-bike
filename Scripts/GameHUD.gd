extends CanvasLayer
## 游戏 HUD - 显示分数、距离、速度、连击等

# 节点引用
@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var distance_label: Label = $Panel/VBoxContainer/DistanceLabel
@onready var speed_label: Label = $Panel/VBoxContainer/SpeedLabel
@onready var combo_label: Label = $ComboLabel

func _ready():
	# 连接信号
	SignalBus.score_changed.connect(_on_score_changed)
	SignalBus.distance_updated.connect(_on_distance_updated)
	SignalBus.combo_increased.connect(_on_combo_increased)
	SignalBus.combo_broken.connect(_on_combo_broken)

	# 初始化显示
	update_display()

func _process(_delta):
	# 更新速度（每帧更新以保持流畅）
	update_speed()

func update_display():
	"""更新所有显示"""
	score_label.text = "分数: 0"
	distance_label.text = "距离: 0m"
	speed_label.text = "速度: 0 km/h"
	combo_label.text = ""

func update_speed():
	"""更新速度显示"""
	var bike = get_tree().get_first_node_in_group("bike")
	if bike and bike.has_method("get_speed_kmh"):
		var speed = bike.get_speed_kmh()
		speed_label.text = "速度: %d km/h" % int(speed)

func _on_score_changed(new_score: int):
	"""分数变化"""
	score_label.text = "分数: %d" % new_score

func _on_distance_updated(distance: float):
	"""距离更新"""
	distance_label.text = "距离: %.1fm" % distance

func _on_combo_increased(combo: int):
	"""连击增加"""
	combo_label.text = "连击 x%d" % combo
	combo_label.modulate = Color.YELLOW

	# 连击越高，字体越大
	var scale_factor = 1.0 + (combo * 0.05)
	combo_label.scale = Vector2.ONE * min(scale_factor, 2.0)

func _on_combo_broken():
	"""连击中断"""
	combo_label.text = ""
