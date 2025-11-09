extends Node2D
class_name Terrain
## 程序化地形生成器 - 无尽滚动赛道

# 加速板场景
const BoostPadScene = preload("res://Scenes/BoostPad.tscn")

# 导出参数
@export var segment_length: int = 400  # 每段地形长度（像素）
@export var segment_resolution: int = 20  # 每段的点密度
@export var difficulty: float = 1.0  # 难度系数（随游戏进行增加）
@export var generate_distance: int = 2000  # 提前生成距离
@export var scroll_speed: float = 300.0  # 地形滚动速度（像素/秒）

# 地形数据
var terrain_points := PackedVector2Array()  # 所有地形点
var base_y := 400.0  # 基础高度
var current_x := 0.0  # 当前生成到的 X 坐标
var generated_segments := 0  # 已生成的段数

# 地形类型权重（根据难度调整）
var terrain_types := {
	"flat": 1.0,
	"sine": 2.0,
	"bumps": 1.5,
	"ramp": 1.0,
	"hill": 0.5,
}

# 节点引用
var static_body: StaticBody2D
var collision_polygon: CollisionPolygon2D
var collision_shapes: Array[CollisionShape2D] = []  # 矩形碰撞体阵列
var line_2d: Line2D

func _ready():
	setup_rendering()
	setup_collision()
	generate_initial_terrain()

	# 立即创建碰撞（移除延迟，防止小车第一帧掉穿）
	update_collision()

	print("地形系统初始化完成")

func setup_rendering():
	"""设置渲染节点"""
	line_2d = Line2D.new()
	line_2d.name = "TerrainLine"
	line_2d.width = 5.0  # 加粗，更明显
	line_2d.default_color = Color(0, 1, 1, 1)  # 青色霓虹
	line_2d.joint_mode = Line2D.LINE_JOINT_ROUND
	line_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
	line_2d.z_index = 10  # 确保在上层
	add_child(line_2d)
	print("✅ Line2D 渲染节点已创建")

func setup_collision():
	"""设置碰撞节点 - 矩形阵列模式"""
	static_body = StaticBody2D.new()
	static_body.name = "TerrainBody"
	add_child(static_body)
	print("地形碰撞系统已初始化（矩形模式）")

	# 保留测试平台
	var test_body = StaticBody2D.new()
	test_body.name = "TestPlatform"
	var test_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(200, 20)
	test_shape.shape = rect
	test_shape.position = Vector2(100, 390)
	test_body.add_child(test_shape)
	add_child(test_body)
	print("✅ 测试平台已创建在 (100, 390)")

	# 添加底部安全平台（防止无限下落）
	var bottom_body = StaticBody2D.new()
	bottom_body.name = "BottomSafety"
	var bottom_shape = CollisionShape2D.new()
	var bottom_rect = RectangleShape2D.new()
	bottom_rect.size = Vector2(10000, 50)  # 超宽平台
	bottom_shape.shape = bottom_rect
	bottom_shape.position = Vector2(0, 650)  # Y=650，在最低波谷 Y=550 下方
	bottom_body.add_child(bottom_shape)
	add_child(bottom_body)
	print("✅ 底部安全平台已创建在 Y=650")

func generate_initial_terrain():
	"""生成初始地形 - 抛物线山丘模式（y = x²）"""
	terrain_points.clear()

	# 参数配置
	var step = 8.0  # 点间距
	var hill_width = 800.0  # 每个抛物线山丘宽度
	var hill_height = 200.0  # 山丘高度
	var flat_length = 200.0  # 平直段长度
	var num_hills = 3  # 生成3个山丘

	var current_x = -500.0

	# 生成多个"抛物线山丘 + 平直"循环
	for hill in range(num_hills):
		# 1. 生成抛物线山丘（倒U形，y = -ax² + peak）
		var hill_steps = int(hill_width / step)
		for i in range(hill_steps):
			var x_local = (float(i) / hill_steps - 0.5) * 2.0  # 归一化到 -1 到 1
			var parabola = 1.0 - (x_local * x_local)  # 1 - x²，范围 0 到 1
			var y = base_y - parabola * hill_height  # 向上的山丘

			var x = current_x + i * step
			terrain_points.append(Vector2(x, y))

		current_x += hill_width

		# 2. 生成平直段
		var flat_steps = int(flat_length / step)
		for i in range(flat_steps):
			var x = current_x + i * step
			terrain_points.append(Vector2(x, base_y))

		current_x += flat_length

	update_rendering()

	print("========================================")
	print("地形生成完成: 抛物线山丘模式（y = x²）")
	print("山丘宽度: %.0fpx, 高度: %.0fpx, 数量: %d" % [hill_width, hill_height, num_hills])
	print("总点数: %d" % terrain_points.size())
	print("========================================")

func _process(delta):
	# 地形向左滚动（暂时禁用用于测试可见性）
	# position.x -= scroll_speed * delta

	# 动态生成已禁用 - 测试模式：只使用初始地形
	# var terrain_right_edge = global_position.x + current_x
	# if terrain_right_edge < 1500:
	#     var segment_type = choose_segment_type()
	#     generate_segment(segment_type)
	#     update_rendering()
	#     update_collision()

func choose_segment_type() -> String:
	"""根据难度和权重选择地形类型"""
	# 根据进度调整难度
	var progress = generated_segments / 50.0  # 每 50 段增加难度
	difficulty = 1.0 + progress * 0.5

	# 调整权重
	var adjusted_weights := {}
	for type in terrain_types:
		match type:
			"flat":
				adjusted_weights[type] = max(0.5, 2.0 - difficulty)  # 难度越高，平地越少
			"sine":
				adjusted_weights[type] = 2.0
			"bumps":
				adjusted_weights[type] = 1.0 + difficulty * 0.5
			"ramp":
				adjusted_weights[type] = 0.5 + difficulty * 0.8
			"hill":
				adjusted_weights[type] = difficulty * 0.5

	# 加权随机选择
	var total_weight = 0.0
	for weight in adjusted_weights.values():
		total_weight += weight

	var random_value = randf() * total_weight
	var cumulative = 0.0
	for type in adjusted_weights:
		cumulative += adjusted_weights[type]
		if random_value <= cumulative:
			return type

	return "sine"  # 默认

func generate_segment(type: String):
	"""生成一段地形"""
	var points := PackedVector2Array()
	var step = segment_length / float(segment_resolution)

	match type:
		"flat":
			points = generate_flat(step)
		"sine":
			points = generate_sine(step)
		"bumps":
			points = generate_bumps(step)
		"ramp":
			points = generate_ramp(step)
		"hill":
			points = generate_hill(step)

	# 添加到总点集
	terrain_points.append_array(points)
	current_x += segment_length
	generated_segments += 1

	# 发送信号（暂时禁用）
	# SignalBus.terrain_section_generated.emit(type)

func generate_flat(step: float) -> PackedVector2Array:
	"""平地"""
	var points := PackedVector2Array()
	for i in range(segment_resolution + 1):
		var x = current_x + i * step
		points.append(Vector2(x, base_y))
	return points

func generate_sine(step: float) -> PackedVector2Array:
	"""对称的多层波浪 - 美观且平滑"""
	var points := PackedVector2Array()
	var base_amplitude = 50.0 + difficulty * 10.0

	# 使用固定周期，确保一个完整的对称波形
	var num_waves = 2.0  # 每段包含 2 个完整波浪

	for i in range(segment_resolution + 1):
		var t = float(i) / segment_resolution  # 归一化到 0-1
		var x = current_x + i * step

		# 主波浪（低频大振幅）- 基础形状
		var main_wave = sin(t * TAU * num_waves)

		# 次级波浪（中频中振幅）- 增加变化
		var secondary_wave = sin(t * TAU * num_waves * 2.5) * 0.3

		# 细节波纹（高频小振幅）- 增加真实感
		var detail_wave = sin(t * TAU * num_waves * 6) * 0.1

		# 叠加所有波形
		var combined = (main_wave + secondary_wave + detail_wave) * base_amplitude
		var y = base_y + combined

		points.append(Vector2(x, y))

	return points

func generate_bumps(step: float) -> PackedVector2Array:
	"""连续小颠簸"""
	var points := PackedVector2Array()

	for i in range(segment_resolution + 1):
		var x = current_x + i * step
		var y = base_y + sin(x * 0.05) * 20 + sin(x * 0.12) * 10
		points.append(Vector2(x, y))
	return points

func generate_ramp(step: float) -> PackedVector2Array:
	"""跳台"""
	var points := PackedVector2Array()
	var ramp_height = 80.0 + difficulty * 30.0

	for i in range(segment_resolution + 1):
		var t = float(i) / segment_resolution
		var x = current_x + i * step
		var y = base_y

		if t < 0.3:
			# 上坡
			y = base_y - (t / 0.3) * ramp_height
		elif t < 0.4:
			# 平台
			y = base_y - ramp_height
		elif t < 0.5:
			# 陡降
			y = base_y - ramp_height + ((t - 0.4) / 0.1) * ramp_height
		else:
			# 平地
			y = base_y

		points.append(Vector2(x, y))
	return points

func generate_hill(step: float) -> PackedVector2Array:
	"""大山丘"""
	var points := PackedVector2Array()
	var hill_height = 120.0 + difficulty * 20.0

	for i in range(segment_resolution + 1):
		var t = float(i) / segment_resolution
		var x = current_x + i * step
		var y = base_y - sin(t * PI) * hill_height
		points.append(Vector2(x, y))
	return points

func update_rendering():
	"""更新渲染"""
	if not line_2d:
		print("❌ Line2D 未初始化")
		return

	# 直接渲染所有地形点（简化版本）
	line_2d.points = terrain_points
	print("✅ Line2D 渲染 %d 个点" % terrain_points.size())

func update_collision():
	"""更新碰撞 - 使用 Godot 官方推荐的 SegmentShape2D 方法"""
	if not static_body:
		print("❌ StaticBody2D 未初始化！")
		return

	if terrain_points.size() < 2:
		print("⚠️ 地形点太少，无法创建碰撞")
		return

	# 清理旧的碰撞形状
	for shape in collision_shapes:
		if is_instance_valid(shape):
			shape.queue_free()
	collision_shapes.clear()

	# 为每对相邻点创建线段碰撞 + 厚度矩形（防止轮子穿透）
	for i in range(terrain_points.size() - 1):
		var p1 = terrain_points[i]
		var p2 = terrain_points[i + 1]

		# 1. 线段碰撞（表面精确碰撞）
		var line_shape = CollisionShape2D.new()
		var segment = SegmentShape2D.new()
		segment.a = p1
		segment.b = p2
		line_shape.shape = segment
		static_body.add_child(line_shape)
		collision_shapes.append(line_shape)

		# 2. 薄矩形碰撞（增加厚度，防止高速穿透）
		var rect_shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		var segment_length = p1.distance_to(p2)
		var mid_point = (p1 + p2) / 2.0
		var angle = atan2(p2.y - p1.y, p2.x - p1.x)

		# 矩形碰撞向上偏移，顶边对齐视觉地形线
		var perpendicular = Vector2(-sin(angle), cos(angle))  # 法向量（向下）
		var thickness = 30.0  # 30px厚度

		rect.size = Vector2(segment_length, thickness)
		rect_shape.shape = rect
		rect_shape.position = mid_point - perpendicular * (thickness / 2.0)  # 向上偏移，顶边对齐地形线
		rect_shape.rotation = angle
		static_body.add_child(rect_shape)
		collision_shapes.append(rect_shape)

	print("✅ 双层碰撞更新: %d 个形状（线段+厚度），覆盖范围 x: %.0f ~ %.0f" % [
		collision_shapes.size(),
		terrain_points[0].x,
		terrain_points[-1].x
	])

func place_boost_pads():
	"""智能检测波峰左侧的陡坡并放置加速板"""
	if terrain_points.size() < 3:
		return

	var boost_pads_placed = 0
	var min_steep_slope = 0.3  # 陡坡阈值（更陡才放置）
	var min_spacing = 300.0  # 加速板最小间隔
	var last_boost_x = -999999.0  # 上一个加速板的X位置

	# 遍历地形点，检测陡坡位置（波峰左侧）
	for i in range(1, terrain_points.size() - 1):
		var p1 = terrain_points[i - 1]
		var p2 = terrain_points[i]
		var p3 = terrain_points[i + 1]

		# 计算斜率（向上为负）
		var slope = (p2.y - p1.y) / (p2.x - p1.x)
		var next_slope = (p3.y - p2.y) / (p3.x - p2.x)

		# 检测陡坡：当前陡峭上升 + 下一段坡度变缓但仍上升 = 接近波峰的左侧陡坡
		if slope < -min_steep_slope and next_slope > slope and next_slope < 0:
			# 检查与上一个加速板的距离
			if p2.x - last_boost_x >= min_spacing:
				# 放置加速板
				var boost_pad = BoostPadScene.instantiate()
				boost_pad.position = p2

				# 加速板跟随地形角度（斜向上，给小车向上冲量）
				var terrain_angle = atan2(p3.y - p2.y, p3.x - p2.x)
				boost_pad.rotation = terrain_angle

				# 添加为地形的子节点（跟随地形滚动）
				add_child(boost_pad)

				last_boost_x = p2.x
				boost_pads_placed += 1

	print("🚀 已放置 %d 个加速板（陡坡位置）" % boost_pads_placed)

func get_height_at(x: float) -> float:
	"""获取指定 X 坐标的地形高度（用于 AI 或特效）"""
	if terrain_points.size() < 2:
		return base_y

	# 二分查找最近的点
	var left = 0
	var right = terrain_points.size() - 1

	while left < right - 1:
		var mid = (left + right) / 2
		if terrain_points[mid].x < x:
			left = mid
		else:
			right = mid

	# 线性插值
	var p1 = terrain_points[left]
	var p2 = terrain_points[right]
	if p2.x - p1.x == 0:
		return p1.y
	var t = (x - p1.x) / (p2.x - p1.x)
	return lerp(p1.y, p2.y, t)
