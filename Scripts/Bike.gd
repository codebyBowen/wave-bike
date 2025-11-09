extends RigidBody2D
class_name Bike
## 摩托车主控制脚本 - 处理物理、控制、空翻检测

# 导出参数（可在编辑器中调整）
@export var acceleration := 5000000000.0  # 加速度（大幅提升以克服地形滚动）
@export var base_thrust_ratio := 2  # 基础推力比例（大幅提升）
@export var max_speed := 200.0  # 最大速度
@export var rotation_torque := 200000.0  # 旋转力矩（X10倍 - 极速旋转）
@export var air_rotation_multiplier := 3.5  # 空中旋转倍率（大幅提升）

# 状态变量
var is_on_ground := false  # 是否在地面
var was_on_ground := false  # 上一帧是否在地面
var is_crashed := false  # 是否已摔车
var air_time := 0.0  # 当前滞空时间
var last_rotation := 0.0  # 上一帧的旋转角度

# 嵌入检测和恢复
var is_embedded := false  # 是否嵌入地形
var embedding_time := 0.0  # 嵌入时长
var embedding_check_timer := 0.0  # 检测计时器
const EMBEDDING_CHECK_INTERVAL = 0.1  # 每0.1秒检测
const MAX_EMBEDDING_TIME = 3.0  # 超过3秒强制重置

# 跳跃系统
var can_jump := true  # 是否可以跳跃
var jump_cooldown_timer := 0.0  # 跳跃冷却计时器
const JUMP_COOLDOWN := 0.3  # 跳跃冷却时间（秒）
const JUMP_FORCE := 35000.0  # 跳跃力

# 节点引用（将在 _ready 中获取）
@onready var front_raycast: RayCast2D = $FrontRaycast
@onready var back_raycast: RayCast2D = $BackRaycast
@onready var camera: Camera2D = $Camera2D
@onready var body_sprite: ColorRect = $BodySprite
@onready var front_wheel_sprite: ColorRect = $FrontWheel/WheelSprite
@onready var back_wheel_sprite: ColorRect = $BackWheel/WheelSprite
@onready var roof_detector: Area2D = $RoofDetector

func _ready():
	# 设置物理属性（优化：更轻更灵活，极低阻尼）
	gravity_scale = 1.0
	mass = 35.0  # 减轻质量，从 50 降到 35
	linear_damp = 0.0  # 完全移除空气阻力
	angular_damp = 0.1  # 降低旋转阻尼

	# 初始化旋转追踪
	last_rotation = rotation

	# 添加到 "bike" 组（方便其他脚本查找）
	add_to_group("bike")

	print("🏍️ 摩托车初始化完成，位置: %s" % global_position)

	# 验证碰撞节点
	var collision = get_node_or_null("BodyCollision")
	if collision:
		print("✅ 车身碰撞节点存在")
	else:
		print("❌ 车身碰撞节点缺失！")

	# 连接车顶碰撞检测信号
	roof_detector.body_entered.connect(_on_roof_hit_terrain)
	print("✅ 车顶碰撞检测已启用")

	# 测试模式提示
	print("========================================")
	print("🚀 高性能测试模式已启用")
	print("推力系统: 恒定全力，空中也加速")
	print("推力值: %.0fN (%.0f × %.1f)" % [acceleration * base_thrust_ratio, acceleration, base_thrust_ratio])
	print("旋转力矩: %.0f" % rotation_torque)
	print("阻尼: linear=%.1f, angular=%.1f" % [linear_damp, angular_damp])
	print("========================================")

func _physics_process(delta):
	if is_crashed:
		return

	# 0. 嵌入检测和恢复（优先级最高）
	embedding_check_timer += delta
	if embedding_check_timer >= EMBEDDING_CHECK_INTERVAL:
		embedding_check_timer = 0.0
		var currently_embedded = detect_embedding()

		if currently_embedded and not is_embedded:
			# 刚刚嵌入
			is_embedded = true
			embedding_time = 0.0
			print("⚠️ 检测到嵌入！位置: (%.0f, %.0f)" % [global_position.x, global_position.y])
		elif not currently_embedded and is_embedded:
			# 成功恢复
			is_embedded = false
			embedding_time = 0.0
			print("✅ 恢复成功！")

	# 如果嵌入，应用恢复力并跳过正常物理
	if is_embedded:
		#apply_recovery_force(delta)
		return

	# 1. 检测地面状态
	check_ground_contact()

	# 2. 处理移动（自动前进）
	handle_movement(delta)

	# 3. 处理平衡控制（A/D 键）
	handle_balance_control(delta)

	# 4. 追踪旋转（空翻检测）
	track_rotation(delta)

	# 5. 检测摔车
	check_crash_conditions()

	# 更新上一帧状态
	was_on_ground = is_on_ground
	last_rotation = rotation

func check_ground_contact():
	"""检测是否与地面接触 - 使用物理碰撞检测"""
	# 使用物理碰撞接触数量检测地面
	var contact_count = get_contact_count()

	# 检查是否有向下的接触（防止侧面碰撞误判）
	var has_ground_contact = false
	if contact_count > 0:
		# 简化：只要有碰撞就认为在地面（轮子碰撞体在底部）
		has_ground_contact = true

	is_on_ground = has_ground_contact

	# 调试：每秒输出一次状态
	if Engine.get_frames_drawn() % 60 == 0:
		print("地面检测 - 接触数: %d, 在地面: %s, 位置: (%.0f, %.0f)" % [
			contact_count,
			is_on_ground,
			global_position.x,
			global_position.y
		])

	# 检测着陆瞬间
	if is_on_ground and not was_on_ground:
		on_land()

	# 检测起飞瞬间
	if not is_on_ground and was_on_ground:
		on_takeoff()

func detect_embedding() -> bool:
	"""检测是否嵌入地形"""
	var speed = linear_velocity.length()
	var angle = abs(Global.normalize_angle(rad_to_deg(rotation)))

	# 条件1: 高速下落突然停止（从>300降到<100）
	if linear_velocity.y > 300.0 and speed < 100.0:
		return true

	# 条件2: 车身倾斜但无法旋转（卡住）
	if angle > 30.0 and abs(angular_velocity) < 0.1 and speed < 80.0:
		return true

	return false

func apply_recovery_force(delta):
	"""施加恢复力 - 垂直车身向上推"""
	embedding_time += delta

	# 恢复方向：车身的垂直向上方向
	var recovery_direction = -transform.y

	# 自适应力度（随时间增加）
	var base_force = 5000000000.0
	var time_multiplier = 1.0 + (embedding_time * 0.5)
	var force_magnitude = min(base_force * time_multiplier, 150000.0)  # 最大150kN

	apply_force(recovery_direction * force_magnitude)

	# 辅助：旋转回正
	var angle = Global.normalize_angle(rad_to_deg(rotation))
	if abs(angle) > 15.0:
		var correction_torque = -sign(angle) * rotation_torque * 0.2
		apply_torque(correction_torque)

	# 调试输出
	if int(embedding_time * 5) % 5 == 0:
		print("🔧 恢复中: 力=%.0fN, 角度=%.1f°, 时长=%.2fs" %
			  [force_magnitude, angle, embedding_time])

	# 紧急重置
	if embedding_time > MAX_EMBEDDING_TIME:
		print("⚠️ 恢复失败 - 紧急传送")
		reset_to_safe_position()

func reset_to_safe_position():
	"""紧急传送到安全位置"""
	global_position.y -= 100  # 向上移动100px
	linear_velocity = Vector2(200, 0)  # 给予前进速度
	angular_velocity = 0.0
	rotation = 0.0
	is_embedded = false
	embedding_time = 0.0
	print("🚑 紧急重置: 新位置 (%.0f, %.0f)" % [global_position.x, global_position.y])

func handle_movement(_delta):
	"""处理摩托车移动 - 地面全力，空中减半"""
	# 空中推力减半（更真实，同时允许飞行和特技）
	var thrust_multiplier = 1.0
	if not is_on_ground:
		thrust_multiplier = 0.5

	# 推力：沿着车身方向（transform.x）
	var forward_direction = transform.x
	var thrust_force = forward_direction * acceleration * base_thrust_ratio * thrust_multiplier
	apply_force(thrust_force)

	# 调试：每0.5秒输出一次推力信息
	if Engine.get_frames_drawn() % 30 == 0:
		var angle_deg = rad_to_deg(rotation)
		var thrust_magnitude = thrust_force.length()
		var on_ground_text = "地面" if is_on_ground else "空中"
		print("🚗 推力调试 - %s, 角度: %.1f°, 方向: (%.2f, %.2f), 大小: %.0fN, 速度: %.0f px/s" % [
			on_ground_text,
			angle_deg,
			forward_direction.x,
			forward_direction.y,
			thrust_magnitude,
			linear_velocity.length()
		])

func handle_balance_control(delta):
	"""处理 A/D 键的平衡控制 + 空格跳跃"""
	var torque = 0.0

	# A 键：向后倾斜（后空翻）
	if Input.is_action_pressed("lean_back"):
		torque = -rotation_torque

	# D 键：向前倾斜（前空翻）
	elif Input.is_action_pressed("lean_forward"):
		torque = rotation_torque

	# 空格：跳跃（仅在地面且冷却完成时）
	if Input.is_action_just_pressed("ui_accept") and is_on_ground and can_jump:
		perform_jump()

	# 更新跳跃冷却
	if not can_jump:
		jump_cooldown_timer -= delta
		if jump_cooldown_timer <= 0.0:
			can_jump = true

	# 空中旋转更快
	if not is_on_ground:
		torque *= air_rotation_multiplier
		air_time += delta
	else:
		air_time = 0.0

	# 施加扭矩
	if torque != 0.0:
		apply_torque(torque)

func perform_jump():
	"""执行跳跃 - 垂直于车身向上"""
	# 跳跃方向：垂直于车身向上（-transform.y）
	var jump_direction = -transform.y
	var jump_impulse = jump_direction * JUMP_FORCE

	apply_central_impulse(jump_impulse)

	# 开始冷却
	can_jump = false
	jump_cooldown_timer = JUMP_COOLDOWN

	print("🦘 跳跃！方向: (%.2f, %.2f), 力: %.0fN" % [
		jump_direction.x,
		jump_direction.y,
		JUMP_FORCE
	])

func track_rotation(delta):
	"""追踪旋转角度，用于空翻计数"""
	# 计算角度变化
	var angle_change = rotation - last_rotation

	# 处理角度跳变（从 -π 到 π 或反向）
	if angle_change > PI:
		angle_change -= TAU  # TAU = 2π
	elif angle_change < -PI:
		angle_change += TAU

	# 累加到全局旋转计数（转换为度数）
	if not is_on_ground:  # 只在空中计数
		Global.total_rotation += rad_to_deg(angle_change)

func on_takeoff():
	"""起飞瞬间"""
	air_time = 0.0
	Global.total_rotation = 0.0  # 重置旋转计数
	SignalBus.bike_airborne.emit()
	print("起飞！")

func on_land():
	"""着陆瞬间 - 判定落地质量（不再因角度摔车）"""
	var landing_angle = rad_to_deg(rotation)
	var normalized_angle = Global.normalize_angle(landing_angle)

	print("着陆！角度: %.1f度, 滞空: %.2f秒, 旋转: %.1f度" % [normalized_angle, air_time, Global.total_rotation])

	# 判定落地质量（所有角度都允许，只是分数不同）
	var quality = ""
	if normalized_angle < Global.PERFECT_ANGLE:
		quality = "PERFECT"
	elif normalized_angle < Global.GREAT_ANGLE:
		quality = "GREAT"
	elif normalized_angle < Global.GOOD_ANGLE:
		quality = "GOOD"
	else:
		quality = "ROUGH"  # 粗糙落地，但不摔车

	# 计算完成的空翻数
	var flips = int(abs(Global.total_rotation) / 360.0)

	# 发射特技完成信号（所有落地都发送）
	if flips > 0 or quality in ["PERFECT", "GREAT", "GOOD"]:
		SignalBus.trick_performed.emit(flips, quality, air_time)
		print("特技 - %d 空翻 (%s)" % [flips, quality])
	elif quality == "ROUGH":
		print("粗糙落地 - 角度: %.1f度" % normalized_angle)

	# 重置空翻计数
	Global.total_rotation = 0.0

	SignalBus.bike_landed.emit()

func check_crash_conditions():
	"""检测摔车条件（放宽版本 - 主要依赖车顶碰撞）"""
	# 条件 1: 严重侧翻（提高到120度，几乎倒置才算）
	if is_on_ground and linear_velocity.length() < 30.0:
		var angle = Global.normalize_angle(rad_to_deg(rotation))
		if angle > 120:  # 提高阈值，更宽容
			crash("TIPPED_OVER")

	# 条件 2: HEAD_FIRST 已移除，由车顶碰撞检测器替代

func crash(reason: String):
	"""摔车处理"""
	if is_crashed:
		return

	is_crashed = true
	print("摔车！原因: %s" % reason)

	# 发射摔车信号
	SignalBus.bike_crashed.emit(reason)

	# 视觉效果：渐隐
	var tween = create_tween()
	tween.tween_property(body_sprite, "modulate:a", 0.3, 0.5)

func _on_roof_hit_terrain(body: Node2D):
	"""当车顶碰到地形时触发摔车"""
	if is_crashed:
		return

	# 验证是地形碰撞（检查父节点是否是Terrain）
	if body is StaticBody2D:
		var parent = body.get_parent()
		if parent and parent is Terrain:
			print("💥 车顶碰撞到地形！位置: (%.0f, %.0f)" % [global_position.x, global_position.y])
			crash("ROOF_COLLISION")

func apply_boost(impulse: Vector2):
	"""接收加速板的加速冲量"""
	apply_central_impulse(impulse)
	print("🚀 小车加速！当前速度: %.0f px/s" % linear_velocity.length())

func get_speed_kmh() -> float:
	"""获取速度（km/h）"""
	return linear_velocity.length() / 10.0  # 简化转换

func reset():
	"""重置摩托车状态"""
	is_crashed = false
	air_time = 0.0
	Global.total_rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0

	# 恢复可见度
	body_sprite.modulate.a = 1.0
	front_wheel_sprite.modulate.a = 1.0
	back_wheel_sprite.modulate.a = 1.0

	print("摩托车已重置")
