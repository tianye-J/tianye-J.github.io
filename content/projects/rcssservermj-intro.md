+++
title = 'RCSSServerMJ 入门指南'
date = 2026-04-15T14:22:43+08:00
draft = false
description = "面向零基础读者的 RCSSServerMJ 仿真服务器源码阅读入门指南"
status = "Completed"
stack = ["C++", "MuJoCo", "RoboCup 3D"]
outcome = "把仿真服务器、通信协议和物理循环梳理成源码阅读路线。"
tags = ["RoboCup", "仿真足球", "RCSSServerMJ", "MuJoCo", "入门指南"]
series = ["RoboCup 3D 足球仿真"]
+++
> 面向零基础读者。读完这篇文档，你将理解仿真服务器的核心概念，并能开始阅读 RCSSServerMJ 的源码。
>
> **源代码地址**：[robocup-sim/rcssservermj](https://gitlab.com/robocup-sim/rcssservermj)
>
> **后续阅读**：理解服务器之后，可以继续读 [Janus 客户端入门指南](/learning/janus-intro/)，看客户端如何接收感知、做决策并发送动作。

---

## 快速阅读路线

- **10 分钟速读**：先看“第一章：什么是物理仿真”“第二章：Client-Server 架构”和“第八章：完整数据流”，建立服务器整体图景。
- **30 分钟入门**：按网络通信、消息协议、仿真主循环、感知与动作这条线读，理解服务器和客户端每 20ms 如何交换信息。
- **深入阅读**：再看 PlayMode、Beam、场地规格和“服务端 ↔ 客户端代码对应关系”，适合准备对照源码调试比赛逻辑。

## 第一章：什么是物理仿真

### 物理引擎 (Physics Engine) 是什么

想象一个虚拟世界——里面有地面、一个足球、一个机器人。你把球推一下，它会滚动、减速、停下；机器人抬脚，重心会偏移、可能摔倒。

**物理引擎**就是负责计算这些的程序。它模拟真实世界的：
- **重力**：物体会往下掉
- **碰撞**：球碰到脚会弹开
- **摩擦**：球在草地上会慢慢停下
- **关节约束**：机器人的膝盖只能在一定范围内弯曲

你可能在游戏中见过物理引擎（比如 Unity 的 PhysX）。RoboCup 用的 **MuJoCo**（Multi-Joint dynamics with Contact）是一个专门用于机器人和控制研究的高精度物理引擎，由 DeepMind 维护。

### 仿真步进 (Simulation Step)

物理引擎不是连续运算的，而是**离散地推进时间**：

```text
时刻 0.000s → 计算 → 时刻 0.020s → 计算 → 时刻 0.040s → ...
```

每一"步"（step），引擎会：
1. 读取所有物体当前的位置、速度
2. 读取施加在物体上的力（比如电机的扭矩）
3. 根据牛顿力学算出 0.020 秒后所有物体的新位置、新速度

这个时间间隔越小，仿真越精确，但计算量越大。RCSSServerMJ 默认每步 20ms，内部还会细分为多个 substep 来提高精度。

### MuJoCo 的世界用 XML 描述

MuJoCo 用 XML 文件定义整个物理世界：

```xml
<!-- 简化示例 -->
<mujoco>
  <worldbody>
    <body name="ball" pos="0 0 0.5">
      <geom type="sphere" size="0.11" mass="0.4"/>
    </body>
    <body name="robot_torso" pos="0 0 0.8">
      <joint name="hip" type="hinge" range="-90 90"/>
      <geom type="capsule" size="0.05 0.2"/>
    </body>
  </worldbody>
</mujoco>
```

你可以在 `resources/robots/T1/robot.xml` 看到 T1 机器人的完整定义（23 个关节），在 `resources/environments/soccer/world.xml` 看到足球场的定义。

> **对应代码**：`sim/simulation.py` 负责加载 XML 并驱动 MuJoCo 步进。

---

## 第二章：Client-Server（客户端-服务器）架构

### 为什么要把服务器和客户端分开

RCSSServerMJ 的世界里有两种角色：

| | 服务器 (Server) | 客户端 (Client) |
|---|---|---|
| 职责 | 运行物理仿真、执行裁判规则 | 控制一个机器人的决策 |
| 类比 | 足球场 + 裁判 | 球员的大脑 |
| 数量 | 1 个 | 最多 22 个（每队 11 人） |
| 代码 | 这个仓库（rcssservermj） | Janus（你们的项目） |

为什么要分开？因为在 RoboCup 比赛中，每个参赛队伍只提交自己的**客户端**程序，所有队伍连接到同一个官方服务器比赛。服务器是公平的"裁判 + 物理世界"，客户端是你的"算法"。

### 数据流

```text
┌──────────────────────────────────────────────────────────────┐
│                    Server（仿真服务器）                        │
│                                                              │
│  MuJoCo 物理引擎  ←→  裁判逻辑  ←→  感知生成               │
└────────┬─────────────────────────────────────┬───────────────┘
         │ 发送感知（你在哪、球在哪...）         │ 发送感知
         ▼                                     ▼
   ┌───────────┐                         ┌───────────┐
   │ Client #1 │                         │ Client #2 │
   │ (球员 1)   │                         │ (球员 2)   │
   └─────┬─────┘                         └─────┬─────┘
         │ 发送动作（转关节、走路...）           │ 发送动作
         ▼                                     ▼
┌──────────────────────────────────────────────────────────────┐
│                  Server 接收动作，执行物理                     │
└──────────────────────────────────────────────────────────────┘
```

每一轮循环：
1. **Server** 把当前世界状态（感知）发给每个 Client
2. **Client** 根据感知做出决策，把动作发回 Server
3. **Server** 把动作施加到物理世界，推进一步仿真
4. 重复

> **对应代码**：`server/server.py` 管理整个循环，`server/remote_agent.py` 管理每个 Client 的连接。

---

## 第三章：网络通信基础

Server 和 Client 是**两个独立的进程**（甚至可以在不同的电脑上），它们通过**网络**通信。

### IP 地址 + 端口 = 门牌号

- **IP 地址**：标识一台电脑。`127.0.0.1`（也叫 `localhost`）表示"自己这台电脑"。
- **端口 (Port)**：同一台电脑上可以跑很多程序，端口号区分它们。RCSSServerMJ 默认用 **60000**（给 Agent）和 **60001**（给 Monitor）。

类比：IP 地址是小区地址，端口号是门牌号。你寄信需要写清楚两者。

### TCP 协议

TCP (Transmission Control Protocol) 是一种网络协议，特点：
- **可靠**：数据保证送达，丢了会自动重传
- **有序**：发送顺序 = 接收顺序
- **双向**：建立连接后，双方都可以发和收
- **字节流**：没有"消息"的概念，只是一串连续的字节

类比：TCP 像打电话——先拨号建立连接，然后双方持续对话，挂断才断开。（与之对比，UDP 像发短信——直接发，不保证对方收到。）

### Socket：程序里的网络接口

**Socket** 是操作系统提供给程序使用网络的接口。用 Python 写大概是这样：

```python
import socket

# 服务端
server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # 创建 TCP socket
server_sock.bind(('127.0.0.1', 60000))  # 绑定 IP + 端口
server_sock.listen()                      # 开始监听
conn, addr = server_sock.accept()         # 等待客户端连接（阻塞）

# 客户端
client_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client_sock.connect(('127.0.0.1', 60000))  # 连接到服务端

# 双方都可以用 send() / recv() 读写数据
```

> **对应代码**：
> - `server/communication/tcp_connection_listener.py`：服务端监听端口、接受新连接
> - `server/communication/tcp_lpm_connection.py`：在 TCP 上读写带长度前缀的消息

---

## 第四章：消息协议 — 怎么发消息

### 问题：TCP 是字节流，怎么知道一条消息在哪结束？

TCP 传输的是连续的字节，没有"边界"。假设服务器连续发两条消息：

```text
"hello" + "world"
```

客户端收到的可能是：
- `"helloworld"`（粘在一起了）
- `"hel"` + `"loworld"`（断在奇怪的地方）

我们需要一种方法让接收方知道每条消息的边界。

### 长度前缀协议 (Length-Prefixed Message)

RCSSServerMJ 的解决方案很简单：**每条消息前面加 4 个字节，表示消息的长度**。

```text
[长度: 4字节] [消息内容: N字节]
```

具体格式：
```text
字节流:  00 00 00 0C  48 65 6C 6C 6F 20 57 6F 72 6C 64 21
         ├─ 长度 ──┤  ├──────── 消息内容 ────────────────┤
         12 (十进制)    "Hello World!" (12 个字节)
```

- 长度用 **大端序 (Big-Endian)**：高位在前。`00 00 00 0C` = 12。
- 接收方先读 4 字节得到长度 N，再读 N 字节得到完整消息。

```python
# 伪代码：接收一条消息
length_bytes = sock.recv(4)                        # 先读 4 字节
length = int.from_bytes(length_bytes, 'big')       # 解析为整数
message = sock.recv(length)                        # 再读 length 字节
```

> **对应代码**：`server/communication/tcp_lpm_connection.py` 中的 `send_message()` 和 `receive_message()`。

### S-expression：消息内容的格式

知道了怎么分割消息，下一个问题是：消息的**内容**用什么格式组织？

RCSSServerMJ 使用 **S-expression**（符号表达式），一种用括号嵌套的轻量格式：

```text
(time (now 12.34))
(GS (unum 1) (team left) (t 0.00) (pm BeforeKickOff))
(HJ (n he1) (ax 0.00) (rt 0.00))
(See (Ball (pol 5.2 -10.3 2.1)))
```

解读规则：
- `(...)` 表示一个表达式
- 第一个元素通常是"键"（类型），后面是"值"或子表达式
- 可以嵌套：`(GS (unum 1) (team left))` 表示 GS 里面有 unum=1 和 team=left

和你可能见过的 JSON 对比：

| | S-expression | JSON |
|---|---|---|
| 示例 | `(pos (x 1.0) (y 2.0))` | `{"pos": {"x": 1.0, "y": 2.0}}` |
| 特点 | 更紧凑，解析简单 | 更通用，可读性更好 |
| 为什么用 | RoboCup 传统，SimSpark 时代传下来的 | — |

> **对应代码**：`utils/sexpression.py` 实现了 S-expression 的解析器。

---

## 第五章：仿真主循环 — 服务器每帧在做什么

### Game Loop（游戏主循环）

几乎所有实时仿真程序的核心都是一个 **无限循环**，每轮执行固定的一组操作：

```python
while not shutdown:
    update_physics()      # 推进物理
    generate_percepts()   # 生成感知
    send_to_clients()     # 发给客户端
    receive_actions()     # 收客户端的动作
    apply_actions()       # 应用动作
    referee_check()       # 裁判检查
    render()              # 画面渲染（可选）
```

### RCSSServerMJ 的主循环

打开 `server/server.py`，找到 `run()` 方法，它的核心逻辑（简化后）是：

```text
每一轮循环 {
    1. simulation.step()
       └─ MuJoCo 向前推进一步（计算碰撞、关节力、新位置...）

    2. 为每个已连接的 Agent 生成感知数据
       └─ 把机器人能"看到"和"感受到"的信息打包成 S-expression

    3. 把感知发送给每个 Agent（通过 TCP）

    4. 等待/接收 Agent 返回的动作
       └─ 解析 S-expression → 电机控制指令

    5. 把动作应用到物理世界
       └─ 设置 MuJoCo 的电机目标值

    6. 裁判检查
       └─ 球出界了？进球了？该换 PlayMode 了？

    7.（如果开启了渲染）更新 MuJoCo Viewer 画面
}
```

### 三种运行模式

| 模式 | 命令行参数 | 说明 |
|------|-----------|------|
| **实时模式** (Real-time) | 默认开启 | 服务器按真实时间推进，20ms 仿真一步。和现实同步。 |
| **全速模式** (As-fast-as-possible) | `--no-realtime` | 不等待，算完一步立刻算下一步。训练 AI 时常用。 |
| **同步模式** (Sync) | `--sync` | 服务器等所有 Agent 都返回动作后才推进下一步。保证不丢帧。 |

> **对应代码**：`server/server.py` 的 `run()` 方法中通过 `self.real_time`、`self.sync_mode` 控制这些行为。

---

## 第六章：感知与动作 — 机器人的"眼睛"和"肌肉"

### 感知 (Perception)：服务器告诉 Agent 什么

每一轮循环，服务器给每个 Agent 发送一条感知消息，包含：

```text
(time (now 5.24))                                    ← 仿真时间
(GS (unum 1) (team left) (t 5.24) (pm PlayOn))      ← 比赛状态
(pos (n torso) (p 3.21 -1.05 0.45))                  ← 身体位置 (x,y,z)
(quat (n torso) (q 1.0 0.0 0.0 0.0))                ← 身体朝向 (四元数)
(HJ (n he1) (ax 0.00) (rt 0.00))                     ← 关节状态 (角度, 角速度)
(HJ (n he2) (ax -5.23) (rt 0.12))                    ← he2 = 头部俯仰
(HJ (n lle1) (ax 12.50) (rt -0.03))                  ← lle1 = 左腿关节1
...（23 个关节）
(gyro (n torso) (rt 0.01 -0.02 0.00))                ← 陀螺仪 (角速度)
(acc (n torso) (a 0.05 0.02 9.81))                   ← 加速度计
(See (Ball (pol 5.2 -10.3 2.1))                      ← 看到球 (距离, 水平角, 垂直角)
     (P (team left) (id 2) (pol 8.1 30.5 1.2)))      ← 看到队友 2 号
```

**几个关键感知类型**：

| 感知 | 含义 | 用途 |
|------|------|------|
| `pos` | 全局坐标 (x, y, z) | 知道自己在球场的位置 |
| `quat` | 四元数 (w, x, y, z) | 知道自己面朝哪个方向（见下面解释） |
| `HJ` | 关节角度 + 角速度 | 知道自己四肢的当前姿态 |
| `gyro` | 三轴角速度 | 知道身体在旋转吗（检测摔倒） |
| `acc` | 三轴加速度 | 知道身体在加速吗 + 判断摔倒方向 |
| `See` | 视觉检测（极坐标） | 看到球、其他球员、场地标志 |

#### 四元数 (Quaternion) 简介

你可能习惯用"朝北"、"朝东"来描述方向。在 3D 空间中，描述朝向常用 **四元数** `(w, x, y, z)`，一共 4 个数。

你不需要完全理解四元数的数学原理，只需要知道：
- 它是一种**表示 3D 旋转**的方式（比欧拉角更稳定，没有万向锁问题）
- `(1, 0, 0, 0)` 表示"没有旋转"（原始朝向）
- 服务器发的格式是 `[w, x, y, z]`，Janus 客户端会转换成 `[x, y, z, w]`（scipy 库的惯例）

> **对应代码**：`sim/perceptions.py` 定义了所有感知类型。

### 动作 (Action)：Agent 告诉服务器什么

Agent 收到感知后，决定要怎么动，把动作通过 TCP 发回来：

```text
(he1 0.0 0.0 1.0 0.1 0.0)(he2 -5.0 0.0 1.0 0.1 0.0)(lle1 15.0 0.0 150.0 1.0 0.0)...
```

每个电机的控制指令格式：

```text
(电机名  目标角度  目标速度  kp   kd  力矩)
 he1     0.0      0.0      1.0  0.1  0.0
```

其中 `kp` 和 `kd` 是 PD 控制器的参数（下面解释）。

还有一种特殊动作 **Beam**（传送）：

```text
(beam -3.0 0.0 0.0)
      └ x   y  角度(度)
```

在开球前（BEFORE_KICK_OFF）等特定状态下，Agent 可以用 beam 把自己传送到指定位置。

> **对应代码**：`server/action_parser.py` 解析动作消息。

### PD 控制器：电机怎么转到目标角度

机器人的关节由电机驱动。你不能直接"设置"关节角度（就像你不能瞬间把胳膊移到任意位置），而是通过电机施加**力矩 (torque)** 来驱动关节旋转。

**PD 控制器** 是最常用的控制方法，公式：

```text
力矩 = kp * (目标角度 - 当前角度) - kd * 当前角速度
       └── P（比例项）──────────┘   └── D（微分项）──┘
```

直觉理解：
- **kp（比例增益）**= 弹簧的刚度。kp 越大，关节越"用力"往目标位置拉。
- **kd（微分增益）**= 阻尼器。kd 越大，运动越平滑，不会来回震荡。

```text
类比：把橡皮筋（kp）绑在关节和目标之间，同时在关节上涂润滑油（kd）。
      橡皮筋把关节拉向目标，润滑油防止它到达后来回弹跳。
```

T1 机器人有 23 个关节，每个关节都独立做 PD 控制。走路时，客户端需要每帧给出所有 23 个关节的目标角度。

> **对应代码**：服务器在 `sim/sim_interfaces.py` 的 `ctrl_motor()` 中实现 PD 控制。
> Janus 客户端在 `robot.py` 的 `commit_motor_targets_pd()` 中打包 PD 参数。

---

## 第七章：足球比赛逻辑

### PlayMode（比赛模式）

一场足球比赛不只是"跑来跑去踢球"。比赛会经历很多状态：

```text
BEFORE_KICK_OFF → KICK_OFF_LEFT → PLAY_ON → GOAL_LEFT → BEFORE_KICK_OFF → ...
                                          ↘ THROW_IN_RIGHT → PLAY_ON → ...
                                          ↘ CORNER_KICK_LEFT → PLAY_ON → ...
```

常见模式：

| PlayMode | 含义 |
|----------|------|
| `BEFORE_KICK_OFF` | 开球前，球员可以 beam 到位 |
| `KICK_OFF_LEFT` | 左队开球 |
| `PLAY_ON` | 正常比赛中 |
| `THROW_IN_LEFT` | 左队掷界外球 |
| `CORNER_KICK_RIGHT` | 右队角球 |
| `GOAL_LEFT` | 左队进球 |
| `GAME_OVER` | 比赛结束 |

每种模式有不同的规则（谁能碰球、能不能 beam、超时自动转换等）。

> **对应代码**：`games/soccer/play_mode.py` 定义枚举，`games/soccer/sim/soccer_referee.py` 实现裁判逻辑。

### Beam（传送定位）

在 `BEFORE_KICK_OFF`、`GOAL_*` 等状态下，球员可以使用 `(beam x y angle)` 把自己传送到指定位置。这模拟了真实足球中开球前球员站位的过程。

Janus 的 `decision_maker.py` 里硬编码了每个球员号码对应的 beam 位置。

### 场地规格

| 场地 | 尺寸 | 用途 |
|------|------|------|
| FIFA | 105m x 68m | 标准 11v11 比赛 |
| HL Adult | 14m x 9m | 3v3 比赛（Brazil Open Demo 等） |

> **对应代码**：`games/soccer/soccer_fields.py` 定义场地几何参数。

---

## 第八章：完整数据流 — 从连接到踢球

现在把前面的概念串起来，看一个球员从启动到踢球的**完整生命周期**：

```text
┌─ 阶段 1：启动与连接 ──────────────────────────────────────────────────────┐
│                                                                          │
│  Janus 客户端启动 (run_player.py)                                        │
│       │                                                                  │
│       ▼                                                                  │
│  创建 TCP Socket，连接到 Server 的 127.0.0.1:60000                       │
│       │                                                                  │
│       ▼                                                                  │
│  发送初始化消息：(init T1 MujocoCodebase 1)                               │
│                        │        │         │                              │
│                   机器人型号  队名     球员号                              │
│       │                                                                  │
│       ▼                                                                  │
│  Server 收到 init → 在物理世界中生成一个 T1 机器人                         │
│  Agent 状态：INIT → READY → ACTIVE                                       │
│                                                                          │
│  对应代码：                                                               │
│    服务端 → server/remote_agent.py (连接管理)                             │
│    客户端 → mujococodebase/server.py (TCP连接) + agent.py (创建各模块)    │
└──────────────────────────────────────────────────────────────────────────┘

┌─ 阶段 2：主循环（每 20ms 一轮）──────────────────────────────────────────┐
│                                                                          │
│  ┌─ Server ───────────────────────┐   ┌─ Client (Janus) ──────────────┐ │
│  │                                │   │                                │ │
│  │ 1. MuJoCo step()              │   │                                │ │
│  │    物理引擎推进一步             │   │                                │ │
│  │         │                      │   │                                │ │
│  │         ▼                      │   │                                │ │
│  │ 2. 生成感知数据                │   │                                │ │
│  │    (时间/位置/关节/视觉...)     │   │                                │ │
│  │         │                      │   │                                │ │
│  │         ▼                      │   │                                │ │
│  │ 3. 编码为 S-expression        │   │                                │ │
│  │    加上 4 字节长度前缀          │   │                                │ │
│  │         │                      │   │                                │ │
│  │         ├──── TCP 发送 ────────┼──►│ 4. server.receive()           │ │
│  │         │                      │   │    读取长度前缀 → 读取消息体    │ │
│  │         │                      │   │         │                      │ │
│  │         │                      │   │         ▼                      │ │
│  │         │                      │   │ 5. world_parser.parse()       │ │
│  │         │                      │   │    解析 S-expression           │ │
│  │         │                      │   │    更新 World 和 Robot 状态    │ │
│  │         │                      │   │         │                      │ │
│  │         │                      │   │         ▼                      │ │
│  │         │                      │   │ 6. decision_maker.update()    │ │
│  │         │                      │   │    该 beam？该起身？该走路？    │ │
│  │         │                      │   │         │                      │ │
│  │         │                      │   │         ▼                      │ │
│  │         │                      │   │ 7. skills_manager.execute()   │ │
│  │         │                      │   │    执行技能 → 设置关节目标      │ │
│  │         │                      │   │         │                      │ │
│  │         │                      │   │         ▼                      │ │
│  │         │                      │   │ 8. robot.commit_motor_pd()    │ │
│  │         │                      │   │    把 23 个关节目标打包         │ │
│  │         │                      │   │         │                      │ │
│  │ 9. 收到动作消息    ◄───────────┼───┤ server.send()                 │ │
│  │    解析电机指令                 │   │    编码为 S-expression + 发送   │ │
│  │         │                      │   │                                │ │
│  │         ▼                      │   └────────────────────────────────┘ │
│  │ 10. 应用 PD 控制到 MuJoCo     │                                      │
│  │ 11. 裁判检查                   │                                      │
│  │ 12. 渲染画面                   │                                      │
│  │         │                      │                                      │
│  │         ▼                      │                                      │
│  │    回到第 1 步                 │                                      │
│  └────────────────────────────────┘                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

### 服务端 ↔ 客户端代码对应关系

| 服务端 (rcssservermj) | 客户端 (Janus) | 数据方向 |
|---|---|---|
| `server/perception_encoder.py` 编码感知 | `world_parser.py` 解析感知 | Server → Client |
| `server/action_parser.py` 解析动作 | `robot.py` 打包电机指令 | Client → Server |
| `sim/simulation.py` 物理步进 | — | Server 内部 |
| `games/soccer/sim/soccer_referee.py` 裁判 | `decision_maker.py` 根据 PlayMode 决策 | 间接影响 |
| `server/remote_agent.py` 管理连接 | `server.py` 管理连接 | 双向 |

---

## 术语速查表

| 术语 | 英文 | 含义 |
|------|------|------|
| 仿真步进 | Simulation Step | 物理引擎推进一个时间步长 |
| 感知 | Perception | 服务器发给客户端的传感器数据 |
| 动作 | Action | 客户端发给服务器的控制指令 |
| 长度前缀 | Length-Prefixed Message | 消息前 4 字节表示消息长度 |
| 大端序 | Big-Endian | 高位字节在前 |
| S-expression | S-expression | 括号嵌套的数据格式 |
| PD 控制 | PD Control | 比例-微分控制器，控制电机平滑到达目标角度 |
| 四元数 | Quaternion | 4 个数表示 3D 旋转，无万向锁 |
| Beam | Beam | 将机器人传送到指定位置（开球前使用） |
| PlayMode | Play Mode | 比赛状态（开球前/比赛中/界外球/进球...） |
| DOF | Degrees of Freedom | 自由度，T1 机器人有 23 个可控关节 |
| kp | Proportional Gain | PD 控制的比例增益（弹簧刚度） |
| kd | Derivative Gain | PD 控制的微分增益（阻尼系数） |

---
