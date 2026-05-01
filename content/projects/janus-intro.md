+++
title = 'Janus 客户端入门指南'
date = 2026-04-16T14:22:43+08:00
draft = false
description = "面向零基础队员的 Janus RoboCup 3D 足球仿真客户端入门指南"
tags = ["RoboCup", "仿真足球", "Janus", "入门指南"]
series = ["RoboCup 3D 足球仿真"]
+++
> 面向零基础队员。读完这篇文档，你将理解 Janus 客户端的每一个模块在做什么，以及它们如何协同工作。
>
> **前置阅读**：建议先读完 [RCSSServerMJ 入门指南](/learning/rcssservermj-intro/)，了解仿真服务器和通信协议的基础概念。
>
> **代码声明**：Janus 为南邮 Apollo 战队开源代码，如需交流或获取相关信息，请通过 [About](/about/) 页邮箱联系。

---

## 快速阅读路线

- **10 分钟速读**：先看“第一章：Janus 是什么”“第二章：主循环”和“第十三章：完整数据流”，抓住客户端每帧的输入、决策和输出。
- **30 分钟入门**：按服务器通信、感知解析、世界模型、决策系统、技能系统这条线读，把 `server.py`、`world_parser.py`、`decision_maker.py` 串起来。
- **深入阅读**：重点读 Walk、Keyframe、GetUp 和工具函数几章，再回到“代码对应关系一览”，对照源码逐个文件看。

## 第一章：Janus 是什么

Janus 是一个 **RoboCup 3D 足球仿真客户端**。它不负责物理仿真（那是服务器的事），它只做一件事：

> **收到服务器发来的感知 → 做决策 → 把动作发回去**

类比：如果服务器是"足球场 + 裁判"，那 Janus 就是"球员的大脑"。每 20ms，大脑从眼睛和身体收到信息（感知），想好下一步做什么（决策），然后命令肌肉动起来（动作）。

### 代码在哪

```text
Janus_main/Janus3D/
├── run_player.py              ← 入口：启动一个球员
├── start.sh / start3v3.sh     ← 脚本：启动整支队伍
├── kill.sh                    ← 脚本：杀掉所有球员进程
├── build_binary.sh            ← 脚本：打包成比赛用的二进制
├── pyproject.toml             ← 依赖配置
└── mujococodebase/            ← 所有核心代码
    ├── agent.py               ← 主控：把所有模块串起来
    ├── server.py              ← 网络：和服务器的 TCP 通信
    ├── world_parser.py        ← 感知解析：S-expression → Python 数据
    ├── robot.py               ← 机器人模型：23 个电机的控制
    ├── decision_maker.py      ← 决策：该干什么
    ├── world/                 ← 世界模型：球、球员、场地、比赛状态
    ├── skills/                ← 技能系统：走路、起身、站立
    └── utils/                 ← 工具：坐标变换、神经网络加载
```

---

## 第二章：主循环 — Agent 每帧在做什么

打开 `agent.py`，整个客户端的核心就是 `Agent.run()` 里的 **4 行代码**：

```python
while True:
    self.server.receive()                        # 1. 收感知
    self.world.update()                          # 2. 更新世界状态
    self.decision_maker.update_current_behavior() # 3. 做决策 + 执行技能
    self.server.send()                           # 4. 发动作
```

画成图：

```text
                    RCSSServerMJ 服务器
                         │
          ┌──────────────┼──────────────┐
          │  S-expression 感知消息       │
          ▼                             │
   ┌─────────────┐                     │
   │ 1. receive() │ 从 TCP 读取消息     │
   └──────┬──────┘                     │
          │ 原始字节流                   │
          ▼                             │
   ┌──────────────────┐                │
   │ world_parser 解析 │ 自动被调用     │
   │ S-expr → 更新     │               │
   │ World + Robot 状态│               │
   └──────┬───────────┘                │
          │                            │
          ▼                             │
   ┌─────────────────┐                 │
   │ 2. world.update()│ 判断比赛阶段    │
   └──────┬──────────┘                 │
          │                            │
          ▼                             │
   ┌──────────────────────────┐        │
   │ 3. decision_maker.update │        │
   │    该 beam？该起身？该走路？│       │
   │    ↓                     │        │
   │    执行技能（Walk/GetUp） │        │
   │    ↓                     │        │
   │    设置 23 个电机目标角度  │        │
   └──────┬───────────────────┘        │
          │                            │
          ▼                             │
   ┌─────────────┐  S-expression 动作  │
   │ 4. send()   │ ────────────────────┘
   └─────────────┘
```

**就这么简单。** 接下来我们逐个拆解每个模块。

---

## 第三章：网络通信 — server.py

`Server` 类负责和仿真服务器的所有 TCP 通信。如果你读过服务器端的入门指南，这里就是它的"对面"。

### 连接

```python
server.connect()  # 创建 TCP Socket，连接到 host:port
```

连接失败会自动重试，直到服务器准备好。

### 发送初始化消息

```python
server.send_immediate("(init T1 MujocoCodebase 1)")
#                            │      │            │
#                       机器人型号  队名       球员号
```

这条消息告诉服务器："我要加入比赛，我用的是 T1 机器人，队名叫 MujocoCodebase，我是 1 号球员"。

### 接收感知

```python
server.receive()
```

内部做的事：
1. 从 TCP Socket 读 4 字节 → 得到消息长度 N
2. 再读 N 字节 → 得到完整的 S-expression 消息
3. 调用 `world_parser.parse()` 解析这条消息

### 发送动作

```python
server.commit(msg)   # 把一条消息加入发送缓冲区
server.send()        # 把缓冲区里所有消息一次性发出去
```

还有一个特殊方法：

```python
server.commit_beam(pos2d=[x, y], rotation=angle)
# 生成: (beam x y angle)
# 用于开球前把球员传送到指定位置
```

> **文件**：`mujococodebase/server.py`，约 107 行。

---

## 第四章：感知解析 — world_parser.py

服务器每帧发来一大段 S-expression，比如：

```text
(GS (pm PlayOn) (t 100.0) (sl 1) (sr 0) (tl Janus) (tr Opponent))
(time (now 100.0))
(HJ (n he1 ax 0.5 vx 10.0) (n he2 ax 0.2 vx 5.0) ...)
(pos (p 3.21 -1.05 0.45))
(quat (q 1.0 0.0 0.0 0.0))
(GYR (rt 0.1 0.2 0.3))
(ACC (a 0.05 0.02 9.81))
(See (B (pol 5.2 -10.3 2.1)) (P (team Janus) (id 2) (head (pol 8.0 30.0 1.2))))
```

`WorldParser` 的工作是把这堆括号变成 Python 里好用的数据。

### 解析流程

```text
原始 S-expression 字符串
       │
       ▼
__sexpression_to_dict()     ← 把括号结构转成 Python dict
       │
       ▼
parse()                     ← 根据 key 分发到不同处理函数
  ├─ "GS"    → 解析比赛状态（比分、时间、PlayMode、队伍左右）
  ├─ "HJ"    → 解析 23 个关节的角度和速度 → 写入 robot
  ├─ "pos"   → 解析全局位置 [x,y,z] → 写入 world
  ├─ "quat"  → 解析四元数 [w,x,y,z] → 转成 [x,y,z,w] → 写入 robot
  ├─ "GYR"   → 解析陀螺仪 → 写入 robot
  ├─ "ACC"   → 解析加速度计 → 写入 robot
  └─ "See"   → 解析视觉 → 写入 world (球位置、其他球员等)
```

### 两个重要的坐标转换

**1. 四元数顺序转换**

服务器发 `[w, x, y, z]`，但 Python 的 scipy 库用 `[x, y, z, w]`，所以解析时要调换顺序：

```python
# 服务器: (quat (q w x y z))
# 存储:   [x, y, z, w]  ← scipy 惯例
```

**2. 左右队翻转**

服务器的坐标系是固定的——左队在左边，右队在右边。但为了让代码不用区分左右，**如果我们是右队，WorldParser 会把所有坐标旋转 180°**：

```text
服务器视角：                    解析后（统一视角）：
  左队进攻方向 →                  我方总是进攻 → 方向
  右队进攻方向 ←
```

这样 `decision_maker.py` 里的逻辑可以永远假设"对方球门在右边"，不用管我们实际是左队还是右队。

> **文件**：`mujococodebase/world_parser.py`，约 255 行。

---

## 第五章：世界模型 — world/

解析完感知后，所有信息存在 `World` 对象里。这是整个客户端的"共享记忆"。

### World（世界状态）

```python
world.team_name          # 队名
world.number             # 球员号 (1-11)
world.is_left_team       # 我们是左队吗

world.playmode           # 当前比赛模式 (PlayModeEnum)
world.playmode_group     # 比赛阶段分组 (PlayModeGroupEnum)
world.game_time          # 比赛时间
world.score_left         # 左队得分
world.score_right        # 右队得分

world.global_position    # 我的位置 [x, y, z]（米）
world.ball_pos           # 球的位置 [x, y, z]

world.our_team_players   # 我方球员列表 (11 个 OtherRobot)
world.their_team_players # 对方球员列表 (11 个 OtherRobot)

world.field              # 场地对象 (FIFAField 或 HLAdultField)
world.is_fallen()        # 我摔倒了吗？(z 坐标 < 0.3m)
```

### PlayMode（比赛模式）

比赛会经历很多状态，代码里分成 5 个组方便决策：

| 分组 | 含义 | 典型场景 |
|------|------|----------|
| `ACTIVE_BEAM` | 我方可以 beam 传送到位 | 我方进球后、我方先开球 |
| `PASSIVE_BEAM` | 对方可以 beam | 对方进球后、对方先开球 |
| `OUR_KICK` | 我方控球（掷界外球、角球等） | OUR_THROW_IN, OUR_CORNER_KICK |
| `THEIR_KICK` | 对方控球 | THEIR_THROW_IN, THEIR_CORNER_KICK |
| `OTHER` | 正常比赛或结束 | PLAY_ON, GAME_OVER |

`world.update()` 每帧根据 `playmode` 自动计算 `playmode_group`。

### Field（场地）

```python
# FIFA 场地 (11v11)
field.get_length()              # 105m
field.get_width()               # 68m
field.get_our_goal_position()   # [-52.5, 0, 0]  ← 永远在左边
field.get_their_goal_position() # [52.5, 0, 0]   ← 永远在右边

# HL Adult 场地 (3v3)
field.get_length()              # 14m
field.get_width()               # 9m
```

> **文件**：`world/world.py`, `world/play_mode.py`, `world/field.py`, `world/other_robot.py`, `world/field_landmarks.py`

---

## 第六章：机器人模型 — robot.py

`Robot` 是对 T1 机器人的抽象。它不控制物理（那是服务器的事），它只管理 **23 个电机的状态和目标值**。

### T1 机器人的 23 个电机

```text
          [he1] 头左右
          [he2] 头上下
         ╱           ╲
   [lae1]             [rae1]  肩前后
   [lae2]             [rae2]  肩内外
   [lae3]             [rae3]  肘前后
   [lae4]             [rae4]  肘旋转
         ╲           ╱
          [te1] 腰旋转
         ╱           ╲
   [lle1]             [rle1]  髋前后
   [lle2]             [rle2]  髋内外
   [lle3]             [rle3]  髋旋转
   [lle4]             [rle4]  膝前后
   [lle5]             [rle5]  踝前后
   [lle6]             [rle6]  踝内外
```

左边 `l` 开头，右边 `r` 开头。`ae` = arm（胳膊），`le` = leg（腿），`he` = head（头），`te` = torso（躯干）。

### 读取状态

```python
robot.motor_positions     # 当前关节角度（度）: {"he1": 0.5, "he2": -1.2, ...}
robot.motor_speeds        # 当前关节速度（度/秒）

robot.global_orientation_euler  # 身体朝向 [roll, pitch, yaw]（度）
robot.gyroscope                 # 陀螺仪 [roll, pitch, yaw]（度/秒）
robot.accelerometer             # 加速度计 [x, y, z]（m/s²）
```

### 设置电机目标

```python
# 设置单个电机
robot.set_motor_target_position(
    motor_name="lle4",     # 左膝
    target_position=30.0,  # 目标角度（度）
    kp=25,                 # P 增益（弹簧刚度）
    kd=0.6                 # D 增益（阻尼）
)

# 把所有电机目标打包成消息，加入发送缓冲区
robot.commit_motor_targets_pd()
# 生成: (he1 0.0 0.0 25 0.6 0.0)(he2 -5.0 0.0 25 0.6 0.0)...
#        │    │   │    │  │   │
#       电机 目标 速度 kp kd 力矩
```

### 电机对称性 (Motor Symmetry)

人体是左右对称的。当你定义一个动作时，经常需要让左右两边做"镜像"动作。`robot.py` 里定义了对称映射：

```text
"Shoulder_Pitch" → (lae1, rae1)    方向相同
"Shoulder_Roll"  → (lae2, rae2)    方向相反（左外展 = 右内收）
"Hip_Pitch"      → (lle1, rle1)    方向相同
"Hip_Roll"       → (lle2, rle2)    方向相反
...
```

这在 Keyframe 技能中很有用——只需要定义一侧的动作，另一侧自动生成。

> **文件**：`mujococodebase/robot.py`，约 274 行。

---

## 第七章：决策系统 — decision_maker.py

`DecisionMaker` 每帧被调用一次，根据当前状态选择行为。它的逻辑很直接（画成流程图）：

```text
update_current_behavior()
        │
        ▼
  比赛结束了？──是──→ 什么都不做，return
        │ 否
        ▼
  需要 beam 吗？──是──→ commit_beam(预设位置)
  (开球前/进球后)        │ （不 return，继续往下走）
        │                │
        ▼                ▼
  摔倒了？──────是──→ 执行 GetUp 技能
        │                │ （一直执行到站起来为止）
        │ 否             │
        ▼                │
  PLAY_ON？──是──→ carry_ball()
        │           （带球跑向对方球门）
        │ 否
        ▼
  开球前/进球？──是──→ 执行 Neutral（站着不动）
        │ 否
        ▼
  其他情况 ──→ carry_ball()

        │
        ▼
  robot.commit_motor_targets_pd()  ← 最后统一发送电机指令
```

### carry_ball() — 带球行为

这是目前最核心的比赛行为，逻辑是：

```text
1. 算出"球→对方球门"的方向向量
2. 算出球身后 0.3 米的"带球位置"（站在球和球门之间）
3. 我和球→球门方向对齐了吗？（偏差 < 7.5°）

   没对齐 → 先走到带球位置（绕到球后面）
   对齐了 → 直接朝球门方向走

两种情况都调用 Walk 技能
```

用图来说：

```text
    ×对方球门
    ↑
    │  ball_to_goal 方向
    │
    ● 球
    │
    │  ← 0.3m
    │
    ○ 带球位置（我要先走到这里）

如果我已经在带球位置且面朝球门方向 → 直接往前推
```

### Beam 位置

开球前，每个球员有预设的站位。在 `BEAM_POSES` 字典里硬编码了：

```text
FIFA 11v11:                      HL Adult 3v3:
  1号: (2.1, 0)   守门员          1号: (7.0, 0)    守门员
  2号: (22, 12)   右前锋          2号: (2.0, -1.5)
  3号: (22, 4)    中前锋          3号: (2.0, 1.5)
  4号: (22, -4)   中前锋
  ...
```

> **文件**：`mujococodebase/decision_maker.py`，约 136 行。

---

## 第八章：技能系统 — skills/

技能是**可复用的动作模块**。决策系统不直接控制电机，而是调用技能。

### 基类 Skill

所有技能继承自 `Skill`（`skills/skill.py`）：

```python
class Skill(ABC):
    def execute(self, reset: bool, *args, **kwargs) -> bool:
        """
        执行一步。
        - reset=True: 第一次调用（或切换到这个技能时），用来初始化
        - 返回 True: 技能完成了
        - 返回 False: 还没完成，下一帧继续调
        """

    def is_ready(self, *args) -> bool:
        """这个技能现在能执行吗？（前置条件检查）"""
```

### SkillsManager（技能管理器）

`SkillsManager` 管理技能的切换和生命周期：

```python
skills_manager.execute("Walk", target_2d=..., orientation=...)
```

它会自动检测技能切换——如果上一帧在执行 `GetUp`，这一帧换成了 `Walk`，它会自动传 `reset=True`。

### 目前有 3 个技能

| 技能 | 类型 | 说明 |
|------|------|------|
| **Walk** | 神经网络 | 走路，永远不返回 True（持续执行） |
| **Neutral** | 关键帧 | 站立姿势，立即完成 |
| **GetUp** | 复合技能 | 检测摔倒方向，执行起身动画，恢复平衡 |

---

## 第九章：Walk — 神经网络走路

Walk 是最复杂也最核心的技能。它用一个**预训练的神经网络**来控制 23 个关节，让机器人能走向任意目标位置。

### 为什么用神经网络

让双足机器人走路是一个极其复杂的控制问题——需要同时保持平衡、协调 23 个关节、适应不同速度和转向。手工编写这样的控制器几乎不可能，所以用**强化学习**训练一个神经网络策略（policy），然后导出为 ONNX 格式在运行时使用。

### 执行流程

```text
              ┌──────────────────────────────────────────┐
              │           Walk.execute() 每帧执行         │
              └──────────────────┬───────────────────────┘
                                 │
   ┌─────────────────────────────▼─────────────────────────────┐
   │ 第 1 步：计算目标速度                                       │
   │                                                           │
   │ 如果 is_target_absolute:                                  │
   │   raw = target_2d - 我的位置                              │
   │   velocity = rotate_2d_vec(raw, -我的朝向)                │
   │   └─→ 把全局目标转成身体坐标系下的速度                      │
   │                                                           │
   │ 速度裁剪:                                                 │
   │   前后: [-0.5, 0.5] m/s                                   │
   │   左右: [-0.25, 0.25] m/s                                 │
   │   转向: [-0.25, 0.25] rad/s                               │
   └─────────────────────────────┬─────────────────────────────┘
                                 │
   ┌─────────────────────────────▼─────────────────────────────┐
   │ 第 2 步：构建观测向量 (observation)                         │
   │                                                           │
   │ 神经网络需要"看到"机器人当前的状态才能做决策。              │
   │ 观测向量由以下部分拼接而成（共约 75 维）：                   │
   │                                                           │
   │ ┌─ 关节位置 (23维) ─── (当前角度 - 标称角度) / 4.6        │
   │ ├─ 关节速度 (23维) ─── 当前速度 / 110.0                   │
   │ ├─ 上一帧动作 (23维) ── 上一帧的网络输出 / 10.0           │
   │ ├─ 角速度 (3维) ────── 陀螺仪读数 / 50.0                  │
   │ ├─ 目标速度 (3维) ──── [前后, 左右, 转向]                  │
   │ └─ 重力投影 (3维) ──── 身体坐标系下的重力方向              │
   │                                                           │
   │ 所有值都做了归一化，裁剪到 [-10, 10] 范围                   │
   └─────────────────────────────┬─────────────────────────────┘
                                 │
   ┌─────────────────────────────▼─────────────────────────────┐
   │ 第 3 步：神经网络推理                                       │
   │                                                           │
   │   nn_action = run_network(observation, model)             │
   │   └─→ 输入: 75 维 float32                                │
   │   └─→ 输出: 23 维 float32（每个关节的偏移量）              │
   └─────────────────────────────┬─────────────────────────────┘
                                 │
   ┌─────────────────────────────▼─────────────────────────────┐
   │ 第 4 步：转换为电机目标                                     │
   │                                                           │
   │   target = nominal_position + 0.5 * nn_action             │
   │            └─ 标称姿势（站立）    └─ 网络输出的偏移        │
   │                                                           │
   │   target *= train_sim_flip  ← 训练环境和运行环境的关节方向 │
   │                                可能不同，用这个数组修正    │
   │                                                           │
   │   for each motor:                                         │
   │       robot.set_motor_target_position(motor, target,      │
   │                                       kp=25, kd=0.6)     │
   └───────────────────────────────────────────────────────────┘
```

### 几个关键概念

**标称姿势 (Nominal Position)**：机器人"正常站立"时每个关节的角度（弧度）。神经网络的输出是相对于这个姿势的**偏移量**，不是绝对角度。这让网络更容易学习——输出 0 就是保持站立。

**train_sim_flip**：一个 23 维的数组，每个值是 +1 或 -1。因为训练时用的仿真器和 RCSSServerMJ 的关节方向定义可能不同（比如训练时左转是正，运行时左转是负），所以需要逐关节翻转。

**重力投影 (Projected Gravity)**：把世界坐标系的重力向量 `[0, 0, -1]` 转换到机器人身体坐标系。网络通过这个信息知道"我的身体现在是什么姿态"——比如前倾时重力会偏向身体的前方。

> **文件**：`mujococodebase/skills/walk/walk.py`，约 147 行。ONNX 模型：`walk.onnx`。

---

## 第十章：关键帧技能 — Keyframe

关键帧是一种更直觉的动作定义方式：**在 YAML 文件里写好每个时刻各关节的角度，然后按时间顺序播放**。

### YAML 格式

以 `get_up_back.yaml`（从仰面摔倒中起身）为例：

```yaml
symmetry: false          # 不使用左右对称
kp: 250                  # 默认 P 增益（比走路大很多，因为起身需要大力）
kd: 1                    # 默认 D 增益

keyframes:
  - delta: 0.0           # 第 1 帧：立即执行
    motor_positions:
      Head_yaw: 0.0
      Shoulder_Pitch: -90.0    # 双臂前举
      Hip_Pitch: -90.0         # 大腿前抬
      Knee_Pitch: 120.0        # 膝盖弯曲
      Ankle_Pitch: -60.0       # 脚踝
      ...

  - delta: 0.5           # 第 2 帧：0.5 秒后执行
    motor_positions:
      Hip_Pitch: -30.0         # 大腿放下
      Knee_Pitch: 60.0         # 膝盖伸展
      ...
    p_gains:                   # 可以单独给某些关节更大的力
      Hip_Pitch: 300

  - delta: 0.3           # 第 3 帧：再过 0.3 秒
    ...
```

### 播放逻辑

```text
开始 → 加载第 1 帧的关节角度 → 等 delta 秒
     → 加载第 2 帧的关节角度 → 等 delta 秒
     → ...
     → 最后一帧播完 → 返回 True（技能完成）
```

### 对称模式

如果 `symmetry: true`，你只需定义"可读名称"（如 `Shoulder_Pitch: -30`），系统会自动展开成两侧：
- `lae1 = -30`（左肩）
- `rae1 = -30`（右肩，方向可能反转）

> **文件**：`skills/keyframe/keyframe.py`（基类），`skills/keyframe/get_up/`（起身），`skills/keyframe/poses/neutral/`（站立）。

---

## 第十一章：GetUp — 起身技能

GetUp 是一个**复合技能**：它自己不直接控制电机，而是调用其他技能来完成"从摔倒到站稳"的全过程。

### 状态机

```text
检测到摔倒 (world.is_fallen() → z < 0.3m)
       │
       ▼
┌─── 阶段 1：稳定 ───────────────────────┐
│ 执行 Neutral（全身关节归零）             │
│ 等待陀螺仪稳定（角速度 < 2.5°/s）      │
│ 持续 3 帧以上                          │
└──────────────┬─────────────────────────┘
               │
               ▼
┌─── 阶段 2：判断摔倒方向 ───────────────┐
│ 读加速度计的 x 分量:                    │
│   acc[0] < -8  → 脸朝下（前摔）        │
│   acc[0] > +8  → 脸朝上（后摔）        │
└──────────────┬─────────────────────────┘
               │
       ┌───────┴───────┐
       ▼               ▼
  get_up_front    get_up_back
  .yaml            .yaml
  （前摔起身）     （后摔起身）
       │               │
       └───────┬───────┘
               ▼
┌─── 阶段 3：恢复平衡 ──────────────────┐
│ 执行 Walk(0, 0) 原地踏步 1.5 秒       │
│ 让机器人重新找到平衡                    │
└──────────────┬─────────────────────────┘
               │
               ▼
          返回 True（起身完成）
```

> **文件**：`skills/keyframe/get_up/get_up.py`，约 66 行。

---

## 第十二章：工具函数 — utils/

### math_ops.py（坐标变换和几何计算）

这个文件有 400+ 行，是代码中用得最多的工具类。核心函数：

**坐标变换**

```python
# 极坐标 → 直角坐标（用于视觉感知）
MathOps.deg_sph2cart(距离, 水平角°, 垂直角°) → [x, y, z]

# 本地坐标 → 全局坐标（用于把相对于身体的位置转成场地坐标）
MathOps.rel_to_global_3d(本地位置, 全局位置, 全局朝向四元数) → 全局位置
```

**角度操作**

```python
MathOps.normalize_deg(angle)    # 把角度归一化到 [-180°, 180°)
MathOps.normalize_rad(angle)    # 把弧度归一化到 [-π, π)
MathOps.vector_angle(vec)       # 二维向量的方向角（度）
MathOps.rotate_2d_vec(vec, angle)  # 旋转二维向量
```

### neural_network.py（ONNX 模型加载）

```python
model = load_network("walk.onnx")      # 加载模型
action = run_network(observation, model) # 推理，输入观测，输出动作
```

ONNX (Open Neural Network Exchange) 是一种通用的神经网络格式，不依赖 PyTorch 或 TensorFlow，可以用轻量的 ONNXRuntime 高效推理。

> **文件**：`utils/math_ops.py`（424 行），`utils/neural_network.py`（69 行）。

---

## 第十三章：完整数据流 — 一帧的生命

把所有章节串起来，看一帧（20ms）里发生的事：

```text
Server 发来 S-expression
│
│  server.receive()
│  └─ TCP: 读 4 字节长度 → 读 N 字节消息
│
│  world_parser.parse()
│  ├─ 解析比赛状态 → world.playmode, world.score_left, ...
│  ├─ 解析关节 → robot.motor_positions["he1"] = 0.5
│  ├─ 解析位置 → world.global_position = [3.2, -1.0, 0.45]
│  ├─ 解析四元数 → robot.global_orientation_quat = [x,y,z,w]
│  ├─ 解析陀螺仪 → robot.gyroscope = [0.1, 0.2, 0.3]
│  ├─ 解析加速度计 → robot.accelerometer = [0.05, 0.02, 9.81]
│  └─ 解析视觉 → world.ball_pos = [5.0, 2.0, 0.1]
│
│  world.update()
│  └─ playmode → playmode_group (判断当前阶段)
│
│  decision_maker.update_current_behavior()
│  ├─ 比赛结束？ → return
│  ├─ 需要 beam？ → server.commit_beam(...)
│  ├─ 摔倒了？ → skills_manager.execute("GetUp")
│  │              └─ GetUp 内部调 Neutral / KeyframeSkill / Walk
│  │              └─ 设置 robot.motor_targets
│  ├─ PLAY_ON？ → carry_ball()
│  │              └─ 计算带球位置
│  │              └─ skills_manager.execute("Walk", target=...)
│  │                  └─ 构建观测 → 运行 ONNX → 设置 23 个电机目标
│  │
│  └─ robot.commit_motor_targets_pd()
│     └─ 把 23 个 (电机名 目标 0 kp kd 0) 加入发送缓冲区
│
│  server.send()
│  └─ TCP: 4 字节长度 + S-expression 动作消息 → 发给 Server
│
└─→ Server 收到动作，执行物理步进，下一帧重复
```

---

## 第十四章：代码对应关系一览

把服务端（rcssservermj）和客户端（Janus）对应起来看：

| 功能 | 服务端 | 客户端 (Janus) | 数据方向 |
|------|--------|---------------|----------|
| TCP 通信 | `server/communication/` | `server.py` | 双向 |
| 编码感知 | `server/perception_encoder.py` | — | Server 内部 |
| 解析感知 | — | `world_parser.py` | Server → Client |
| 编码动作 | — | `robot.py` commit | Client 内部 |
| 解析动作 | `server/action_parser.py` | — | Client → Server |
| 物理仿真 | `sim/simulation.py` | — | Server 内部 |
| 比赛规则 | `soccer/sim/soccer_referee.py` | `decision_maker.py`（响应） | 间接 |
| PlayMode | `soccer/play_mode.py`（定义） | `world/play_mode.py`（解析） | Server → Client |

---

## 推荐阅读顺序

1. **`run_player.py`** — 3 分钟读完，看怎么创建 Agent
2. **`agent.py`** — 5 分钟读完，看主循环的 4 行核心代码
3. **`server.py`** — 了解 TCP 通信的收发流程
4. **`world_parser.py`** — 对照服务器入门指南的第四章，理解 S-expression 怎么变成 Python 数据
5. **`robot.py`** — 了解 23 个电机的命名和控制方式
6. **`world/world.py` + `play_mode.py`** — 理解世界模型和比赛状态
7. **`decision_maker.py`** — 理解决策逻辑（这是你最常修改的文件）
8. **`skills/walk/walk.py`** — 理解神经网络走路的输入输出
9. **`skills/keyframe/`** — 理解关键帧动画和起身技能

### 动手实验建议

- 在 `world_parser.py` 的 `parse()` 里加 `print(data)` 打印原始消息
- 修改 `decision_maker.py` 的 `carry_ball()` 让机器人做别的事
- 修改 `BEAM_POSES` 改变开球站位
- 在 `get_up/` 里新建一个 YAML 文件，自定义起身动作

---

## 术语速查表

| 术语 | 含义 |
|------|------|
| Agent | 一个球员的客户端程序 |
| World | 客户端维护的世界状态（位置、球、比分等） |
| Perception | 服务器发来的感知数据 |
| Action | 客户端发回的动作指令 |
| Skill | 可复用的动作模块（Walk, GetUp, Neutral） |
| Keyframe | 预定义的关节角度序列，按时间播放 |
| ONNX | 神经网络模型格式，用于走路策略 |
| Beam | 开球前将球员传送到指定位置 |
| PlayMode | 比赛状态（开球前/比赛中/界外球等） |
| PD Control | 比例-微分控制器，让电机平滑到达目标角度 |
| Nominal Position | 标称姿势，机器人"正常站立"的关节角度 |
| train_sim_flip | 修正训练/运行环境关节方向差异的数组 |
| Motor Symmetry | 左右关节的对称映射关系 |
