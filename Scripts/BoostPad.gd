extends Area2D
class_name BoostPad
## 加速板 - 马里奥赛车风格的瞬时加速

# 导出参数
@export var boost_force := 15000.0  # 加速冲量大小
@export var boost_angle_offset := -30.0  # 加速角度偏移（度），负值向上
@export var cooldown_time := 0.5  # 冷却时间（秒）

# 状态变量
var is_active := true  # 是否激活
var cooldown_timer := 0.0  # 冷却计时器

# 节点引用
@onready var visual: ColorRect = $Visual

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)

	# 设置初始颜色
	visual.color = Color(1, 0.9, 0, 1)  # 黄色

	print("加速板已创建，位置: %s" % global_position)

func _process(delta):
	# 冷却计时
	if not is_active:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			activate()

func _on_body_entered(body: Node2D):
	"""检测小车进入"""
	if not is_active:
		return

	if body is Bike:
		apply_boost_to_bike(body)

func apply_boost_to_bike(bike: Bike):
	"""对小车施加加速冲量"""
	# 计算加速方向（沿着加速板的朝向 + 向上偏移）
	var boost_direction = Vector2.from_angle(rotation + deg_to_rad(boost_angle_offset))

	# 施加冲量
	var impulse = boost_direction * boost_force
	bike.apply_central_impulse(impulse)

	print("🚀 加速板触发！冲量: %.0f, 方向: (%.2f, %.2f)" % [boost_force, boost_direction.x, boost_direction.y])

	# 触发特效
	trigger_effect()

	# 进入冷却
	deactivate()

func trigger_effect():
	"""触发视觉特效"""
	# 闪白光
	visual.color = Color(1, 1, 1, 1)

	# 创建渐变动画
	var tween = create_tween()
	tween.tween_property(visual, "color", Color(1, 0.9, 0, 1), 0.2)

func deactivate():
	"""进入冷却状态"""
	is_active = false
	cooldown_timer = cooldown_time
	visual.color = Color(0.5, 0.45, 0, 0.5)  # 灰色半透明

func activate():
	"""重新激活"""
	is_active = true
	visual.color = Color(1, 0.9, 0, 1)  # 恢复黄色
