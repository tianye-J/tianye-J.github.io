+++
title = 'Transformer 数学原理'
date = 2026-04-13T01:13:25+08:00
draft = false
math = true
description = "Transformer 核心组件的数学推导与直觉解释"
tags = ["深度学习"]
series = ["Transformer"]
+++

> 上一篇笔记建立了 Transformer 的直觉和代码实现，这篇深入每个组件背后的数学原理。每个主题都标注了出处论文或博客，方便查阅原文。

---

## 一、Scaled Dot-Product：为什么除以 √dk？

> **出处**：Vaswani et al. (2017) "Attention Is All You Need", Section 3.2.1

上一篇笔记里我们知道 Attention 的计算公式是：

$$\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}}\right) V$$

其中：
- $Q$：Query 矩阵
- $K$：Key 矩阵
- $V$：Value 矩阵
- $d_k$：Key 向量的维度
- $\text{softmax}$：归一化函数（将分数转为概率分布）

但为什么要除以 $\sqrt{d_k}$？Vaswani et al. 在论文中给出了一句关键解释："We suspect that for large values of $d_k$, the dot products grow large in magnitude, pushing the softmax function into regions where it has extremely small gradients." 下面把这句话拆成严格的数学推导。

### 1.1 方差推导

假设 $q$ 和 $k$ 的每个分量都是独立同分布的随机变量，均值为 0，方差为 1。点积 $q^T k = \sum_{i=1}^{d_k} q_i k_i$。


每一项 $q_i k_i$ 的期望和方差：

其中：
- $E[\cdot]$：期望（均值）
- $\text{Var}(\cdot)$：方差（衡量数据的离散程度）
- $q_i$：Query 向量的第 $i$ 个分量
- $k_i$：Key 向量的第 $i$ 个分量

$$E[q_i k_i] = E[q_i] \cdot E[k_i] = 0 \times 0 = 0$$

$$\text{Var}(q_i k_i) = E[q_i^2 k_i^2] - (E[q_i k_i])^2 = E[q_i^2] \cdot E[k_i^2] = 1 \times 1 = 1$$

因为各分量独立，$d_k$ 项求和后：

$$E[q^T k] = 0, \quad \text{Var}(q^T k) = d_k$$

**结论**：点积的方差随 $d_k$ 线性增长。$d_k = 64$ 时标准差是 8，$d_k = 512$ 时标准差是 $\approx 22.6$。

### 1.2 方差过大的后果

当点积的数值很大时，softmax 的输出会趋近 one-hot 分布：

```
假设 3 个 token 的 attention score 为 [a, b, c]

当 score 量级正常（如 [1.0, 0.5, 0.2]）：
  softmax → [0.44, 0.27, 0.20]  ← 平滑分布，梯度正常

当 score 量级过大（如 [20.0, 10.0, 4.0]）：
  softmax → [0.99, 0.00, 0.00]  ← 几乎是 one-hot，梯度趋近 0
```

softmax 在输入值差距很大时进入**饱和区**，梯度接近零，参数几乎无法更新。除以 $\sqrt{d_k}$ 把方差拉回 1，让 softmax 始终工作在梯度有效的区间。


### 1.3 为什么是 √dk 而不是 dk？

因为我们要让缩放后的方差等于 1：

$$\text{Var}\left(\frac{q^T k}{\sqrt{d_k}}\right) = \frac{\text{Var}(q^T k)}{d_k} = \frac{d_k}{d_k} = 1$$

如果除以 $d_k$，方差会变成 $1/d_k$，过度压缩了分数的区分度。$\sqrt{d_k}$ 是恰好让方差归一的选择。

---

## 二、Softmax 与 Boltzmann 分布：为什么 softmax 能当概率用？

> **出处**：统计力学中的 Boltzmann 分布；Vaswani et al. (2017)

### 2.1 Softmax 就是 Boltzmann 分布

统计力学中，一个系统处于能量状态 $e_i$ 的概率由 Boltzmann 分布给出：

$$P(i) = \frac{\exp(-e_i / T)}{\sum_j \exp(-e_j / T)}$$

其中：
- $P(i)$：系统处于状态 $i$ 的概率
- $e_i$：状态 $i$ 的能量
- $T$：温度参数
- $\exp(\cdot)$：指数函数 $e^{(\cdot)}$
- $\sum_j$：对所有状态 $j$ 求和

其中 $T$ 是温度。如果把 $-e_i$ 替换为 logit $z_i$，令 $T = 1$，就得到 softmax：

$$\text{softmax}(z_i) = \frac{\exp(z_i)}{\sum_j \exp(z_j)}$$

两者形式完全一致。Attention 中的 $\frac{1}{\sqrt{d_k}}$ 缩放因子，本质上就是在调节温度 $T = \sqrt{d_k}$。

### 2.2 温度对注意力分布的影响

温度控制分布的"锐度"：

```
score = [2.0, 1.0, 0.5]

T = 0.5（低温）：softmax(score/0.5) = softmax([4.0, 2.0, 1.0])
  → [0.84, 0.11, 0.04]  ← 集中在最大值，接近 argmax

T = 1.0（标准）：softmax(score/1.0) = softmax([2.0, 1.0, 0.5])
  → [0.54, 0.20, 0.12]  ← 平滑分布

T = 5.0（高温）：softmax(score/5.0) = softmax([0.4, 0.2, 0.1])
  → [0.37, 0.31, 0.28]  ← 接近均匀分布
```

- $T \to 0$：softmax 退化为 argmax（**硬注意力**），只关注一个 token
- $T \to \infty$：softmax 退化为均匀分布，所有 token 权重相等
- $T = \sqrt{d_k}$：Transformer 的默认选择，保持适度的区分度

这个温度视角在知识蒸馏（Hinton et al., 2015）中也很重要——用高温 softmax 让 teacher 模型输出更平滑的概率分布，传递更多"暗知识"。


---

## 三、Positional Encoding：为什么用 sin/cos 就能编码位置？

> **出处**：Vaswani et al. (2017) Section 3.5；Kazemnejad, "Transformer Architecture: The Positional Encoding"（博客）

### 3.1 公式

原始 Transformer 的正弦位置编码：

$$PE(pos, 2i) = \sin\left(\frac{pos}{10000^{2i/d_{model}}}\right)$$

$$PE(pos, 2i+1) = \cos\left(\frac{pos}{10000^{2i/d_{model}}}\right)$$

其中 $pos$ 是 token 在序列中的位置，$i$ 是编码向量的维度索引。每一对 $(2i, 2i+1)$ 维度使用同一个频率的 sin 和 cos。

### 3.2 不同维度 = 不同频率

频率由 $\omega_i = 1 / 10000^{2i/d_{model}}$ 决定：

```
维度 i=0:   ω = 1/10000^0 = 1        → 周期 = 2π ≈ 6.28 个位置
维度 i=128: ω = 1/10000^(256/512) = 1/100  → 周期 ≈ 628 个位置
维度 i=255: ω = 1/10000^(510/512) ≈ 1/9770 → 周期 ≈ 61400 个位置
```

低维度变化快（捕捉相邻 token 的位置差异），高维度变化慢（捕捉远距离的位置关系）。Jay Alammar 在 "The Illustrated Transformer" 中把这比作**二进制计数器**：最低位每步翻转，高位翻转越来越慢。

### 3.3 核心数学性质：相对位置的线性可表达性

这是正弦编码最精妙的设计。Kazemnejad 在博客中给出了完整推导：

对于任意固定偏移 $k$，$PE(pos + k)$ 可以表示为 $PE(pos)$ 的**线性变换**：

$$\begin{bmatrix} PE(pos+k, 2i) \\ PE(pos+k, 2i+1) \end{bmatrix} = \begin{bmatrix} \cos(k\omega_i) & \sin(k\omega_i) \\ -\sin(k\omega_i) & \cos(k\omega_i) \end{bmatrix} \begin{bmatrix} PE(pos, 2i) \\ PE(pos, 2i+1) \end{bmatrix}$$

其中：
- $k$：位置偏移量（两个 token 之间的距离）
- $\omega_i$：第 $i$ 个维度对应的频率

推导依赖三角恒等式：

$$\sin(a + b) = \sin a \cos b + \cos a \sin b$$
$$\cos(a + b) = \cos a \cos b - \sin a \sin b$$

其中 $a = pos \cdot \omega_i$，$b = k \cdot \omega_i$。

**这意味着什么？** 变换矩阵只依赖偏移量 $k$，不依赖绝对位置 $pos$。模型可以通过学习一个线性变换来捕捉"距离为 $k$ 的两个 token 之间的关系"——这就是相对位置信息。Self-Attention 中的 $Q^T K$ 运算天然包含了这种线性组合，因此模型不需要显式计算相对位置，正弦编码已经把这个信息编进去了。

### 3.4 为什么底数是 10000？

Vaswani et al. 没有给出严格的理论推导，这更像是一个工程选择。10000 保证了：

- 最低频率的周期（$\approx 2\pi \times 10000 \approx 62800$ 个位置）远大于训练时的最大序列长度
- 最高频率的周期（$2\pi \approx 6$ 个位置）足以区分相邻 token
- 频率在对数尺度上均匀分布，覆盖从局部到全局的所有距离

实际上，后续工作（如 RoPE, ALiBi）提出了不同的位置编码方案，但正弦编码的数学优雅性使它成为理解位置编码的最佳起点。


---

## 四、Attention 与核方法：为什么 Attention 的形式不是凭空设计的？

> **出处**：Tsai et al. (EMNLP 2019) "Transformer Dissection: An Unified Understanding for Transformer's Attention via the Lens of Kernel"

这一节揭示了一个很漂亮的联系：Attention 不是凭空设计的，它和经典统计学中的核回归有着精确的数学对应。

### 4.1 Nadaraya-Watson 核回归

在非参数统计中，Nadaraya-Watson 估计器用核函数对观测值做加权平均：

$$\hat{f}(x) = \frac{\sum_{j=1}^{n} \kappa(x, x_j) \cdot y_j}{\sum_{j=1}^{n} \kappa(x, x_j)}$$

其中 $\kappa(x, x_j)$ 是核函数，衡量 $x$ 和 $x_j$ 的相似度。离 $x$ 越近的观测点，权重越大。

### 4.2 Attention 就是核回归

把 Attention 的公式展开到单个 query $q_i$：

$$\text{Attn}(q_i) = \sum_{j=1}^{T} \frac{\exp(q_i^T k_j / \sqrt{d_k})}{\sum_{l=1}^{T} \exp(q_i^T k_l / \sqrt{d_k})} \cdot v_j$$

定义核函数 $\kappa(q, k) = \exp(q^T k / \sqrt{d_k})$，上式变成：

$$\text{Attn}(q_i) = \frac{\sum_j \kappa(q_i, k_j) \cdot v_j}{\sum_j \kappa(q_i, k_j)}$$

其中：
- $\kappa(q, k)$：核函数（衡量两个向量相似度的函数）
- $v_j$：第 $j$ 个 token 的 Value 向量
- $T$：序列长度

和 Nadaraya-Watson 估计器形式完全一致。$\kappa$ 是指数内积核（exponentiated inner product kernel），它是正定核，满足 Mercer 条件。

### 4.3 这个视角的意义

- **理论根基**：Attention 不是一个 ad-hoc 的设计，它有核方法的理论支撑。softmax 归一化不是随意选择，而是核回归中自然出现的归一化
- **计算瓶颈的来源**：核回归的计算复杂度是 $O(n^2)$（每对样本都要算核函数），这正是 Attention 的 $O(T^2)$ 复杂度的根源
- **线性 Attention 的理论基础**：Choromanski et al. (2021) 的 Performer 利用核的随机特征分解 $\kappa(q, k) \approx \phi(q)^T \phi(k)$，把 Attention 从 $O(T^2)$ 降到 $O(T)$


---

## 五、残差连接：为什么加一个 $x$ 就能训练几十层？

> **出处**：He et al. (CVPR 2016) "Deep Residual Learning for Image Recognition"；He et al. (2016) "Identity Mappings in Deep Residual Networks"

### 5.1 残差连接的数学形式

标准的残差块：

$$y = F(x, \{W_i\}) + x$$

其中 $F(x)$ 是残差函数（在 Transformer 中就是 Multi-Head Attention 或 FFN）。网络学习的不是完整映射 $H(x) = y$，而是残差 $F(x) = H(x) - x$。

### 5.2 梯度流的关键推导

对 loss $L$ 求 $x$ 的梯度：

$$\frac{\partial L}{\partial x} = \frac{\partial L}{\partial y} \cdot \frac{\partial y}{\partial x} = \frac{\partial L}{\partial y} \cdot \left(\frac{\partial F}{\partial x} + I\right)$$

其中：
- $L$：损失函数
- $\frac{\partial L}{\partial x}$：损失对输入 $x$ 的梯度（参数更新的方向和大小）
- $F(x)$：残差函数（Attention 或 FFN 的输出）
- $I$：单位矩阵（恒等变换）

**恒等项 $I$ 是关键**。不管 $\frac{\partial F}{\partial x}$ 有多小（甚至趋近零），梯度中始终有一个 $\frac{\partial L}{\partial y} \cdot I = \frac{\partial L}{\partial y}$ 的分量直接传回。这条"梯度高速公路"保证了深层网络不会出现梯度消失。

### 5.3 多层堆叠的效果

对于 $L$ 层残差网络，第 $l$ 层的输出可以递归展开：

$$x_L = x_l + \sum_{i=l}^{L-1} F(x_i, W_i)$$

梯度：

$$\frac{\partial L}{\partial x_l} = \frac{\partial L}{\partial x_L} \cdot \left(1 + \frac{\partial}{\partial x_l} \sum_{i=l}^{L-1} F(x_i, W_i)\right)$$

前面的 $1$ 保证了即使后面的求和项很小，梯度也不会消失。这就是为什么 12 层甚至 96 层的 Transformer 能正常训练。

### 5.4 Pre-Norm vs Post-Norm

He et al. 在 "Identity Mappings" 中进一步证明，把 Normalization 放在残差函数**内部**（Pre-Norm）比放在外部（Post-Norm）梯度流更干净：

```
Post-Norm（原始 Transformer）：
  y = LayerNorm(x + F(x))    ← LayerNorm 在残差连接之后

Pre-Norm（改进版）：
  y = x + F(LayerNorm(x))    ← LayerNorm 在残差函数内部
```

Pre-Norm 保证了恒等路径上没有任何非线性变换，梯度高速公路完全畅通。GPT-2 和后续大多数大模型都采用了 Pre-Norm。


---

## 六、LayerNorm vs BatchNorm：为什么 Transformer 选 LayerNorm？

> **出处**：Ba, Kiros & Hinton (2016) "Layer Normalization"

### 6.1 归一化的通用公式

所有归一化方法的形式都一样：

$$\hat{x} = \gamma \cdot \frac{x - \mu}{\sigma + \epsilon} + \beta$$

其中：
- $x$：输入向量
- $\mu$：$x$ 所有分量的均值
- $\sigma$：$x$ 所有分量的标准差
- $\epsilon$：防止除零的小常数（如 $10^{-8}$）
- $\gamma$：可学习的缩放参数
- $\beta$：可学习的偏移参数
- $\hat{x}$：归一化后的输出

区别在于 $\mu$ 和 $\sigma$ 沿哪个维度计算。

### 6.2 BatchNorm vs LayerNorm 的归一化轴

假设输入张量的 shape 是 $[B, T, D]$（batch, 序列长度, 特征维度）：

```
BatchNorm：沿 B 维度归一化
  对每个特征维度 d，计算 batch 内所有样本、所有位置的均值和方差
  μ_d = mean over (B, T)
  → 依赖 batch 内其他样本

LayerNorm：沿 D 维度归一化
  对每个样本的每个位置，计算该位置所有特征维度的均值和方差
  μ_{b,t} = mean over D
  → 每个样本独立，不依赖 batch 内其他样本
```

### 6.3 为什么 BatchNorm 不适合 Transformer

**问题一：序列长度不固定。** 不同样本的序列长度不同，位置 $t$ 在某些样本中存在、在另一些中不存在。BatchNorm 需要对同一位置跨 batch 计算统计量，但"同一位置"在变长序列中没有明确定义。

**问题二：batch size 依赖。** BatchNorm 的统计量质量取决于 batch size。推理时 batch=1，需要用训练时积累的 running mean/variance，这在序列任务中不够稳定。

**问题三：序列内的统计特性不均匀。** 一个句子的开头和结尾的特征分布可能差异很大，把它们混在一起算 batch 统计量会引入噪声。

LayerNorm 对每个 token 独立归一化，完全回避了以上三个问题。

### 6.4 LayerNorm 的数学效果

LayerNorm 把每个 token 的特征向量投影到一个标准化的超球面上（均值为 0，方差为 1），然后通过可学习的 $\gamma$ 和 $\beta$ 做仿射变换。这有两个好处：

- **稳定前向传播**：防止特征值在层间累积增长或衰减
- **稳定反向传播**：梯度的尺度不会因为层数增加而剧烈变化

结合残差连接，LayerNorm 是 Transformer 能堆叠到几十甚至上百层的另一个关键保障。


---

## 七、Cross-Entropy Loss：为什么用交叉熵而不是均方误差？

> **出处**：Cover & Thomas, "Elements of Information Theory"；Lei Mao 博客 "Cross Entropy, KL Divergence, and Maximum Likelihood Estimation"

Transformer 训练时，Decoder 每个位置的 loss 都是交叉熵。但交叉熵不是一个随意选择的损失函数——它和最大似然估计、KL 散度在数学上完全等价。

### 7.1 三者等价链

**交叉熵**：

$$H(p, q) = -\sum_{x} p(x) \log q(x)$$

其中：
- $H(p, q)$：交叉熵
- $p(x)$：真实分布（训练标签）
- $q(x)$：模型预测的概率分布
- $\log$：自然对数

**KL 散度**：

$$D_{KL}(p \| q) = \sum_{x} p(x) \log \frac{p(x)}{q(x)} = H(p, q) - H(p)$$

其中：
- $D_{KL}(p \| q)$：KL 散度（衡量两个概率分布之间的差异）
- $H(p)$：真实分布的熵（常数，不依赖模型参数）

因为 $H(p)$（真实分布的熵）是常数，不依赖模型参数，所以：

$$\arg\min_\theta H(p, q_\theta) = \arg\min_\theta D_{KL}(p \| q_\theta)$$

**最大似然估计**：

给定 $N$ 个样本 $\{x_1, ..., x_N\}$，MLE 最大化对数似然：

$$\arg\max_\theta \frac{1}{N} \sum_{i=1}^{N} \log q_\theta(x_i) = \arg\min_\theta \left(-\frac{1}{N} \sum_{i=1}^{N} \log q_\theta(x_i)\right)$$

右边就是经验分布 $\hat{p}$ 下的交叉熵 $H(\hat{p}, q_\theta)$。

**结论**：最小化交叉熵 = 最小化 KL 散度 = 最大似然估计。三条路殊途同归。

### 7.2 对 Transformer 的意义

Decoder 训练时，每个位置预测下一个 token 的概率分布 $q_\theta$，标签是 one-hot 的 $p$。交叉熵退化为：

$$H(p, q) = -\log q_\theta(x_{correct})$$

就是正确 token 的负对数概率。模型要做的就是让正确 token 的预测概率尽可能高——这正是最大似然估计。


---

## 八、Label Smoothing：为什么"故意犯错"反而更好？

> **出处**：Szegedy et al. (CVPR 2016) "Rethinking the Inception Architecture"；Vaswani et al. (2017)

### 8.1 One-hot 标签的问题

标准交叉熵要求模型对正确类别输出概率 1，对其他类别输出概率 0。但 softmax 只有在 logit 趋向无穷大时才能输出 1：

$$\text{softmax}(z_i) \to 1 \quad \text{当且仅当} \quad z_i - z_j \to \infty, \forall j \neq i$$

这迫使模型不断增大 logit 的绝对值，导致：
- 过拟合：模型对训练数据过度自信
- 泛化差：对分布外的输入缺乏鲁棒性

### 8.2 Label Smoothing 的数学形式

把 one-hot 标签 $y$ 替换为平滑标签：

$$y_{smooth} = (1 - \epsilon) \cdot y_{onehot} + \frac{\epsilon}{K}$$

其中：
- $y_{onehot}$：原始 one-hot 标签
- $\epsilon$：平滑系数（原始 Transformer 用 0.1）
- $K$：类别总数
- $y_{smooth}$：平滑后的标签

```
假设 K=5，正确类别是第 2 类：

one-hot:  [0, 1, 0, 0, 0]
smoothed: [0.02, 0.92, 0.02, 0.02, 0.02]   (ε=0.1)
```

模型不再需要输出 100% 的置信度，只需要输出 92% 就够了。这给了模型一个"不用绝对确定"的许可。

### 8.3 Label Smoothing 的正则化效果

从 KL 散度的角度看，label smoothing 等价于在标准交叉熵上加了一个正则项：

$$L_{smooth} = (1 - \epsilon) \cdot H(y, q) + \epsilon \cdot H(u, q)$$

其中 $u$ 是均匀分布。第二项 $H(u, q)$ 惩罚模型输出偏离均匀分布太远——也就是说，不允许模型对任何类别过度自信。

Vaswani et al. 在论文中报告了一个有趣的现象："Label smoothing hurts perplexity, as the model learns to be more unsure, but improves accuracy and BLEU score." 困惑度变差（因为模型不再 100% 确定），但翻译质量反而提升了。


---

## 九、Learning Rate Warmup：为什么不能一开始就用大学习率？

> **出处**：Vaswani et al. (2017) Section 5.3；Ma & Yarats (2024) "Why Warmup the Learning Rate?"

### 9.1 原始 Transformer 的学习率调度

Vaswani et al. 提出了一个两阶段的学习率公式：

$$lr = d_{model}^{-0.5} \cdot \min(step^{-0.5}, \; step \cdot warmup\_steps^{-1.5})$$

其中：
- $lr$：学习率
- $d_{model}$：模型隐藏层维度
- $step$：当前训练步数
- $warmup\_steps$：预热阶段的总步数（原始 Transformer 用 4000）

行为分两段：

```
阶段一（step < warmup_steps）：
  lr ≈ d_model^(-0.5) × step × warmup_steps^(-1.5)
  → 学习率线性增长

阶段二（step ≥ warmup_steps）：
  lr ≈ d_model^(-0.5) × step^(-0.5)
  → 学习率按 1/√step 衰减

原始 Transformer 用 warmup_steps = 4000
```

### 9.2 为什么需要 Warmup？

Adam 优化器维护每个参数的一阶矩（梯度均值）和二阶矩（梯度方差）的指数移动平均：

$$m_t = \beta_1 m_{t-1} + (1 - \beta_1) g_t$$
$$v_t = \beta_2 v_{t-1} + (1 - \beta_2) g_t^2$$

其中：
- $m_t$：第 $t$ 步的一阶矩估计（梯度的指数移动平均）
- $v_t$：第 $t$ 步的二阶矩估计（梯度平方的指数移动平均）
- $g_t$：第 $t$ 步的梯度
- $\beta_1, \beta_2$：衰减系数（通常 $\beta_1=0.9, \beta_2=0.999$）

参数更新量为 $\Delta \theta \propto m_t / \sqrt{v_t}$。

**问题在训练初期**：$m_t$ 和 $v_t$ 都初始化为 0，前几步的估计严重偏向 0。虽然 Adam 有偏差校正（$\hat{m}_t = m_t / (1 - \beta_1^t)$），但校正后的估计在前几十步仍然不稳定。如果此时学习率很大，不稳定的梯度估计 × 大学习率 = 参数剧烈震荡甚至发散。

Warmup 的作用就是在 Adam 积累可靠统计量的这段时间里，用小学习率保护训练过程。

### 9.3 Warmup 步数的选择

Ma & Yarats (2024) 的分析表明，warmup 的主要作用是让网络在训练早期经历一个"渐进锐化"阶段，逐步适应更大的学习率。warmup 步数通常设为总训练步数的 1%-5%。太短则保护不够，太长则浪费了高学习率带来的快速收敛。

---

## 十、信息瓶颈：为什么 Attention 能有效地筛选信息？（选读）

> **出处**：Tishby & Schwartz-Ziv (2017) "Opening the Black Box of Deep Neural Networks via Information"

这一节是理论视角，帮助理解"为什么 Attention 有效"，但目前还没有针对 Transformer 的严格证明。

### 10.1 信息瓶颈原理

给定输入 $X$ 和目标 $Y$，一个好的中间表示 $Z$ 应该满足：

$$\max I(Z; Y) \quad \text{subject to} \quad \min I(Z; X)$$

其中：
- $I(\cdot; \cdot)$：互信息（衡量两个变量之间共享的信息量）
- $X$：输入数据
- $Y$：预测目标（标签）
- $Z$：中间表示（模型学到的特征）

即：保留尽可能多的与预测目标相关的信息（$I(Z; Y)$ 大），同时压缩掉与预测无关的输入噪声（$I(Z; X)$ 小）。

### 10.2 Attention 与信息瓶颈

Attention 的 softmax 权重可以看作一种信息选择机制：

- 高权重的 token：信息被保留（与当前 query 相关）
- 低权重的 token：信息被压缩（与当前 query 无关）

每一层 Attention 都在做一次"选择性压缩"——保留对当前任务有用的信息，丢弃无关的上下文。这和信息瓶颈的目标天然吻合。

不过需要强调，这是一个启发性的类比，不是严格的数学证明。Tishby 的信息瓶颈理论本身在深度学习中的适用性仍有争议（Saxe et al., 2018 提出了质疑）。把它作为理解 Attention 的一个思考框架是有价值的，但不宜过度解读。

---

## 核心概念速查表

| 概念 | 一句话解释 | 为什么重要 |
|------|-----------|-----------|
| $\sqrt{d_k}$ 缩放 | 点积方差随维度线性增长，除以 $\sqrt{d_k}$ 使方差归一 | 防止 softmax 饱和导致梯度消失 |
| Softmax 温度 | $\sqrt{d_k}$ 本质上是 Boltzmann 分布的温度参数 | 控制注意力分布的锐度 |
| 正弦位置编码 | 不同频率的 sin/cos 编码位置，$PE(pos+k)$ 是 $PE(pos)$ 的线性变换 | 让模型通过线性运算学到相对位置关系 |
| Attention = 核回归 | softmax attention 等价于指数内积核的 Nadaraya-Watson 估计 | Attention 有经典统计学的理论根基 |
| 残差连接 | $y = F(x) + x$，梯度中恒等项 $I$ 保证梯度直通 | 深层 Transformer 能训练的核心保障 |
| LayerNorm | 沿特征维度归一化，每个样本独立 | 不受 batch 大小和序列长度影响 |
| 交叉熵 = KL 散度 = MLE | 三种优化目标在数学上完全等价 | 理解 Decoder 训练的本质 |
| Label Smoothing | 用 $(1-\epsilon) \cdot y + \epsilon/K$ 替代 one-hot | 防止过拟合，提升泛化 |
| LR Warmup | 前 N 步线性增长学习率，之后衰减 | 给 Adam 时间积累可靠的梯度统计量 |
| 信息瓶颈 | 好的表示应最大化 $I(Z;Y)$ 同时最小化 $I(Z;X)$ | 理解 Attention 为什么能有效筛选信息 |

---

## 学习检查清单

- [ ] 能推导为什么点积的方差是 $d_k$，以及为什么除以 $\sqrt{d_k}$
- [ ] 能解释 softmax 和 Boltzmann 分布的关系，以及温度参数的作用
- [ ] 能写出正弦位置编码的公式，并解释为什么 $PE(pos+k)$ 可以表示为 $PE(pos)$ 的线性变换
- [ ] 能把 Attention 改写成核回归的形式，并说出核函数是什么
- [ ] 能推导残差连接的梯度公式，并解释恒等项 $I$ 的作用
- [ ] 能说出 LayerNorm 和 BatchNorm 的归一化轴区别，以及为什么 Transformer 选 LayerNorm
- [ ] 能证明最小化交叉熵等价于最大似然估计
- [ ] 能写出 Label Smoothing 的公式，并解释它为什么能防止过拟合
- [ ] 能写出原始 Transformer 的学习率公式，并解释 warmup 的必要性
- [ ] 能用信息瓶颈的语言描述 Attention 在做什么（选读）

---

## 参考文献

| 编号 | 论文/博客 | 对应章节 |
|------|----------|---------|
| [1] | Vaswani et al. (2017). "Attention Is All You Need." NeurIPS. arXiv:1706.03762 | §1, §2, §3, §8, §9 |
| [2] | Jay Alammar. "The Illustrated Transformer." jalammar.github.io | §3 |
| [3] | Amirhossein Kazemnejad. "Transformer Architecture: The Positional Encoding." kazemnejad.com | §3 |
| [4] | Tsai et al. (2019). "Transformer Dissection: A Unified Understanding for Transformer's Attention via the Lens of Kernel." EMNLP. arXiv:1908.11775 | §4 |
| [5] | Choromanski et al. (2021). "Rethinking Attention with Performers." ICLR. arXiv:2009.14794 | §4 |
| [6] | He et al. (2016). "Deep Residual Learning for Image Recognition." CVPR. arXiv:1512.03385 | §5 |
| [7] | He et al. (2016). "Identity Mappings in Deep Residual Networks." ECCV. arXiv:1603.05027 | §5 |
| [8] | Ba, Kiros & Hinton (2016). "Layer Normalization." arXiv:1607.06450 | §6 |
| [9] | Cover & Thomas. "Elements of Information Theory." Wiley. | §7 |
| [10] | Lei Mao. "Cross Entropy, KL Divergence, and Maximum Likelihood Estimation." leimao.github.io | §7 |
| [11] | Szegedy et al. (2016). "Rethinking the Inception Architecture for Computer Vision." CVPR. arXiv:1512.00567 | §8 |
| [12] | Ma & Yarats (2024). "Why Warmup the Learning Rate?" arXiv:2406.09405 | §9 |
| [13] | Tishby & Schwartz-Ziv (2017). "Opening the Black Box of Deep Neural Networks via Information." arXiv:1703.00810 | §10 |
| [14] | Hinton et al. (2015). "Distilling the Knowledge in a Neural Network." arXiv:1503.02531 | §2 |

---

