extends Node
## 全局信号中心 - 用于组件间通信

# 特技相关
signal trick_performed(flips: int, quality: String, air_time: float)  # 完成特技
signal perfect_landing()  # 完美落地
signal combo_increased(combo: int)  # 连击增加
signal combo_broken()  # 连击中断

# 摩托车状态
signal bike_crashed(reason: String)  # 摔车
signal bike_landed()  # 着陆
signal bike_airborne()  # 起飞

# 游戏事件
signal game_started()  # 游戏开始
signal game_over(final_score: int, distance: float)  # 游戏结束
signal game_paused()  # 游戏暂停
signal game_resumed()  # 游戏继续

# 得分相关
signal score_changed(new_score: int)  # 分数变化
signal distance_updated(distance: float)  # 距离更新
signal high_score_beaten(new_high_score: int)  # 打破最高分

# UI 事件
signal show_trick_popup(flips: int, quality: String, score: int)  # 显示特技弹窗
signal update_hud()  # 更新 HUD

# 地形相关
signal terrain_section_generated(section_type: String)  # 生成新地形段
