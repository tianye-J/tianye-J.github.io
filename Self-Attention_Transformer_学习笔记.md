# Self-Attention & Transformer 学习笔记

> **课程来源**：李宏毅 ML 2023 Spring（Self-attention 上/下 + Transformer 上/下）
> **学习目标**：理解 CLIP 文本编码器的核心架构，为 CoOp / Federated Prompt Tuning 研究打基础
> **整理者**：Arden 江 | NJUPT 机器人工程 2025级
> **更新日期**：2026-03-12

---

## 一、为什么你必须学这个？

在你的研究路线 CoOp → PromptFL → DiPrompT 中，**CLIP 的文本编码器就是一个 Transformer**。你之前学到的 Soft Prompt `[v1][v2][v3][v4][CLASS]` 这串向量，就是被送进 Transformer 进行编码的。不理解 Transformer，就无法理解：

- 为什么 Prompt 的长度和位置会影响性能
- CLIP 取 `[EOS]` 位置的输出作为文本特征的原因
- DiPrompT 在 Transformer 中间层插入 Prompt 的设计动机

**学完本笔记后，你应该能回答**：Q/K/V 怎么算？Multi-Head 为什么有用？Positional Encoding 干什么的？Encoder 和 Decoder 有什么区别？

---

## 二、Self-Attention（自注意力机制）

### 2.1 核心问题：如何处理变长序列？

输入可能是一句话（5个词）、一段语音（200帧）、一张图（196个patch），长度不固定。传统 FC 层要求固定输入维度，无法处理这种情况。

**生活类比**：你在教室里坐着，老师点名提问。FC 层相当于老师只看你一个人；Self-Attention 相当于老师让全班每个人都互相看一眼，综合所有人的信息后再做判断。

### 2.2 Self-Attention 的计算流程

假设输入序列有 T 个 token，每个 token 是一个 d 维向量：

```
输入：X = [x₁, x₂, ..., xT]，shape = [T, d]

第1步：生成 Q, K, V（三个"角色"）
  Q = X @ Wq    # Query: "我在找什么？"    shape = [T, dk]
  K = X @ Wk    # Key:   "我能提供什么？"  shape = [T, dk]
  V = X @ Wv    # Value: "我的实际内容"    shape = [T, dv]

第2步：算 Attention Score（谁和谁最相关？）
  Score = Q @ K^T          # shape = [T, T]，每对 token 之间的相关性
  Score = Score / √dk      # 缩放，防止数值过大导致 softmax 梯度消失

第3步：Softmax 归一化
  Attention = softmax(Score, dim=-1)   # 每行和为1，变成概率分布

第4步：加权求和
  Output = Attention @ V    # shape = [T, dv]
```

**生活类比**：
- **Query（查询）**：你走进图书馆，脑子里想着"我要找关于机器人的书"
- **Key（钥匙）**：每本书封面上的标签，如"机器人"、"烹饪"、"历史"
- **Value（内容）**：书的实际内容
- **Attention Score**：你的需求和每本书标签的匹配程度
- **Output**：根据匹配程度，从所有书中加权提取出对你最有用的信息

### 2.3 PyTorch 伪代码

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class SelfAttention(nn.Module):
    def __init__(self, d_model, dk):
        super().__init__()
        self.Wq = nn.Linear(d_model, dk)
        self.Wk = nn.Linear(d_model, dk)
        self.Wv = nn.Linear(d_model, dk)
        self.scale = dk ** 0.5  # √dk

    def forward(self, x):
        """
        x: [batch, seq_len, d_model]
        """
        Q = self.Wq(x)   # [batch, T, dk]
        K = self.Wk(x)   # [batch, T, dk]
        V = self.Wv(x)   # [batch, T, dk]

        # Attention Score: Q和K的点积衡量相关性
        score = torch.bmm(Q, K.transpose(1, 2)) / self.scale  # [batch, T, T]

        # Softmax: 变成概率分布（每行和为1）
        attn = F.softmax(score, dim=-1)  # [batch, T, T]

        # 加权求和: 用相关性权重对V求和
        output = torch.bmm(attn, V)  # [batch, T, dk]
        return output
```

### 2.4 数值例子

```
假设 3 个 token，dk = 2（极简示例）

Q = [[1, 0],    K = [[1, 0],    V = [[5, 6],
     [0, 1],         [0, 1],         [7, 8],
     [1, 1]]         [1, 1]]         [9, 10]]

Score = Q @ K^T / √2:
  token1 和 token1: (1×1 + 0×0) / √2 = 0.71
  token1 和 token2: (1×0 + 0×1) / √2 = 0.00
  token1 和 token3: (1×1 + 0×1) / √2 = 0.71

  Score = [[0.71, 0.00, 0.71],
           [0.00, 0.71, 0.71],
           [0.71, 0.71, 1.41]]

Softmax（对每行归一化）:
  Attn ≈ [[0.39, 0.22, 0.39],    ← token1 主要关注自己和 token3
          [0.22, 0.39, 0.39],    ← token2 主要关注自己和 token3
          [0.24, 0.24, 0.52]]    ← token3 最关注自己

Output = Attn @ V:
  token1 的输出 = 0.39×[5,6] + 0.22×[7,8] + 0.39×[9,10]
               = [7.0, 8.0]
  → 每个 token 的输出都融合了其他 token 的信息！
```

### 2.5 为什么叫"Self"-Attention？

因为 Q、K、V 全部来自**同一个输入** X。如果 Q 来自一个序列、K/V 来自另一个序列，就叫 **Cross-Attention**（交叉注意力）——这在 Transformer Decoder 和 CLIP 的图文对齐中都会用到。

### 2.6 与 CLIP 的关系

CLIP 文本编码器中，你的 Soft Prompt `[v1][v2][v3][v4][cat]` 被送入 Transformer 后，每个 token 都会通过 Self-Attention 和其他所有 token 交互信息。这就是为什么 `[v1]` 的值会影响 `[cat]` 的编码——**它们在 Self-Attention 中互相"看见"了对方**。

---

## 三、Multi-Head Attention（多头注意力）

### 3.1 为什么需要多头？

单头 Attention 只学一种"关注模式"。但在自然语言中，一个词和其他词的关系是多维度的：

```
"The cat sat on the mat because it was soft"

"it" 需要同时关注：
  - 语法层面："it" 指代 "mat"（名词替代关系）
  - 语义层面："soft" 修饰 "mat"（属性关系）
  - 位置层面："it" 和 "mat" 距离较近

单头只能学一种关系，多头可以每个头学一种
```

### 3.2 Multi-Head 的计算

```
不是做一次 Attention，而是做 h 次（h 个 head），每次用不同的 W 矩阵：

Head_1 = Attention(X @ Wq1, X @ Wk1, X @ Wv1)
Head_2 = Attention(X @ Wq2, X @ Wk2, X @ Wv2)
...
Head_h = Attention(X @ Wqh, X @ Wkh, X @ Wvh)

最后拼接 + 线性变换：
MultiHead = Concat(Head_1, ..., Head_h) @ Wo
```

### 3.3 PyTorch 伪代码

```python
class MultiHeadAttention(nn.Module):
    def __init__(self, d_model, num_heads):
        super().__init__()
        self.num_heads = num_heads
        self.dk = d_model // num_heads  # 每个头的维度

        self.Wq = nn.Linear(d_model, d_model)
        self.Wk = nn.Linear(d_model, d_model)
        self.Wv = nn.Linear(d_model, d_model)
        self.Wo = nn.Linear(d_model, d_model)

    def forward(self, x):
        B, T, D = x.shape
        h = self.num_heads

        # 投影后 reshape 成多头：[B, T, D] → [B, h, T, dk]
        Q = self.Wq(x).view(B, T, h, self.dk).transpose(1, 2)
        K = self.Wk(x).view(B, T, h, self.dk).transpose(1, 2)
        V = self.Wv(x).view(B, T, h, self.dk).transpose(1, 2)

        # 每个头独立做 Attention
        score = (Q @ K.transpose(-2, -1)) / (self.dk ** 0.5)
        attn = F.softmax(score, dim=-1)        # [B, h, T, T]
        out = attn @ V                          # [B, h, T, dk]

        # 拼接所有头：[B, h, T, dk] → [B, T, D]
        out = out.transpose(1, 2).contiguous().view(B, T, D)
        return self.Wo(out)
```

### 3.4 与 CLIP/CoOp 的关系

CLIP ViT-B/16 的文本编码器用了 **12 个 head**，d_model=512，因此每个 head 的 dk=512/12≈42。你的 Soft Prompt 在编码过程中，每个 head 会从不同角度关注 prompt token 和 class token 之间的关系。

---

## 四、Positional Encoding（位置编码）

### 4.1 为什么需要位置编码？

Self-Attention 本身是**排列不变的**（permutation invariant）——打乱输入顺序，输出也只是对应打乱，不会改变每个 token 的值。但语言有顺序："狗咬人"和"人咬狗"意思完全不同。

```
Self-Attention 看到的：
  {狗, 咬, 人} → 一个无序集合，不知道谁在前谁在后

加了位置编码后：
  {狗+pos0, 咬+pos1, 人+pos2} → 现在知道顺序了
```

### 4.2 CLIP 用的位置编码

CLIP 文本编码器用的是**可学习的位置编码**（Learned Positional Embedding），不是原始 Transformer 论文的正弦/余弦固定编码：

```python
# CLIP 的位置编码（简化版）
self.positional_embedding = nn.Parameter(
    torch.randn(max_seq_len, d_model)  # 可学习的，shape [77, 512]
)

def forward(self, tokens):
    x = self.token_embedding(tokens)    # [T, 512]
    x = x + self.positional_embedding[:T]  # 加上位置信息
    x = self.transformer(x)
    return x
```

### 4.3 对 CoOp 的影响

CoOp 的 Soft Prompt 插在序列最前面（位置 0~3），class token 在后面（位置 4）。**位置编码会让模型知道"这些 prompt 向量在前面，类名在后面"**，所以论文才会区分 class token 放末尾还是放中间——因为位置不同，位置编码就不同，模型的理解方式也会变化。

---

## 五、Transformer 完整架构

### 5.1 Encoder Block（编码器块）

这是 CLIP 文本编码器的核心单元，一个 Encoder Block 包含：

```
输入 x
  ↓
[Multi-Head Attention] → 让每个 token 融合其他 token 的信息
  ↓ + x（残差连接）
[Layer Normalization]  → 稳定训练
  ↓
[Feed-Forward Network] → 两层 MLP，增加非线性
  ↓ + x（残差连接）
[Layer Normalization]
  ↓
输出
```

### 5.2 两个关键组件详解

**残差连接（Residual Connection）**：

```python
# 不加残差：信息逐层丢失
x = attention(x)

# 加残差：保留原始信息 + 新信息
x = x + attention(x)
# 类比：考试时不仅写新学的，也保留已有知识
```

**Layer Normalization**：

```python
# 对每个样本的特征维度做归一化（注意：不是 Batch Norm）
def layer_norm(x):
    mean = x.mean(dim=-1, keepdim=True)
    std = x.std(dim=-1, keepdim=True)
    return (x - mean) / (std + 1e-8)

# 为什么用 LayerNorm 而不是 BatchNorm？
# 因为序列长度不固定，BatchNorm（对 batch 维度归一化）不适用
# LayerNorm 对每个样本独立归一化，不受 batch 中其他样本影响
```

**Feed-Forward Network（FFN）**：

```python
class FFN(nn.Module):
    def __init__(self, d_model, d_ff):
        super().__init__()
        # 两层 MLP：先升维，再降维
        self.fc1 = nn.Linear(d_model, d_ff)    # 512 → 2048
        self.fc2 = nn.Linear(d_ff, d_model)    # 2048 → 512
        self.activation = nn.GELU()            # CLIP 用 GELU 激活

    def forward(self, x):
        return self.fc2(self.activation(self.fc1(x)))
```

### 5.3 完整 Transformer Encoder 伪代码

```python
class TransformerEncoderBlock(nn.Module):
    def __init__(self, d_model=512, num_heads=8, d_ff=2048, dropout=0.1):
        super().__init__()
        self.attn = MultiHeadAttention(d_model, num_heads)
        self.ffn = FFN(d_model, d_ff)
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        # Sub-layer 1: Multi-Head Attention + 残差 + LayerNorm
        attn_out = self.attn(x)
        x = self.norm1(x + self.dropout(attn_out))

        # Sub-layer 2: FFN + 残差 + LayerNorm
        ffn_out = self.ffn(x)
        x = self.norm2(x + self.dropout(ffn_out))

        return x

class TransformerEncoder(nn.Module):
    def __init__(self, num_layers=12, d_model=512, num_heads=8):
        super().__init__()
        self.layers = nn.ModuleList([
            TransformerEncoderBlock(d_model, num_heads)
            for _ in range(num_layers)
        ])

    def forward(self, x):
        for layer in self.layers:
            x = layer(x)
        return x
```

---

## 六、Seq2seq 框架总览（对应 slides p2, p15）

Transformer 最初是为 **Seq2seq（Sequence-to-sequence）** 任务设计的：输入一个序列，输出另一个序列，且输出长度由模型自己决定。

```
典型 Seq2seq 应用（slides p2）：

语音识别：语音帧序列 [T帧] → 文字序列 [N字]     T ≠ N
机器翻译："機器學習" [4字] → "machine learning" [2词]
语音翻译：英文语音 → 中文文字（跨模态+跨语言）
```

Seq2seq 的核心架构就是 **Encoder + Decoder**（slides p15）：

```
输入序列 → [Encoder] → 隐层表示 → [Decoder] → 输出序列

Encoder：理解输入（"读题"）
Decoder：生成输出（"答题"）
```

**与 CLIP 的关系**：CLIP 的文本端本质上只用了 Decoder 部分（带 Masked Self-Attention 的 Transformer），图像端用的是 Encoder（ViT）。理解 Encoder 和 Decoder 的区别，就能明白 CLIP 两端的架构差异。

---

## 七、Decoder — Autoregressive 生成（对应 slides p23-34）

### 7.1 什么是 Autoregressive（自回归）？

Decoder 生成输出时是**一个一个地生成**，每次生成一个 token，然后把这个 token 作为下一步的输入，如此循环（slides p24-25）。

```
以语音识别"機器學習"为例（slides p24-25）：

第1步：输入 START token → Decoder → 输出概率分布 → argmax → "機"
第2步：输入 START + "機" → Decoder → 输出概率分布 → argmax → "器"
第3步：输入 START + "機" + "器" → Decoder → argmax → "學"
第4步：输入 START + "機" + "器" + "學" → Decoder → argmax → "習"
第5步：输入 START + "機" + "器" + "學" + "習" → Decoder → argmax → END

输出 END 后停止生成（slides p33-34）
```

**生活类比**：Autoregressive 像写作文——你先写第一个字，看了第一个字才写第二个字，看了前两个字才写第三个字。每个字都依赖前面所有已写的字。

### 7.2 错误传播问题（slides p30）

Autoregressive 有一个致命弱点：**如果某一步生成错了，后面所有步都会被带偏**。

```
正确路径：START → 機 → 器 → 學 → 習 → END
错误路径：START → 機 → 氣（错！）→ 學 → 習 → ...

"氣"是错的，但 Decoder 会把"氣"当成正确输入继续生成
→ 一步错，步步错（error propagation）
```

这也是后面 Teacher Forcing 要解决的问题。

### 7.3 如何停下来？— END Token（slides p33-34）

Decoder 不知道应该输出多长的序列。解法是在词汇表里加一个特殊 token **END**（或 `<EOS>`）。当 Decoder 输出 END 时，生成结束。

```python
# Autoregressive 推理伪代码
def autoregressive_decode(encoder_output, max_len=100):
    tokens = [START_TOKEN]
    for _ in range(max_len):
        logits = decoder(tokens, encoder_output)  # 输入已有 tokens
        next_token = logits[-1].argmax()           # 取最后位置的预测
        if next_token == END_TOKEN:
            break
        tokens.append(next_token)
    return tokens
```

### 7.4 AT vs NAT（slides p36）

| 类型 | 全称 | 生成方式 | 优缺点 |
|------|------|---------|--------|
| AT | Autoregressive | 逐个生成，每步依赖前一步 | 质量高但速度慢 |
| NAT | Non-autoregressive | 一次性并行生成所有 token | 速度快但质量通常较差 |

CLIP 文本端和 GPT 都是 AT 风格。NAT 了解即可，当前你的研究不直接涉及。

---

## 八、Masked Self-Attention（对应 slides p27-29）

### 8.1 为什么需要 Mask？

回顾 Encoder 的 Self-Attention：每个 token 可以看到序列中**所有** token（包括后面的）。但 Decoder 在生成时，**还没生成的 token 不应该被看到**——你写第 2 个字的时候，第 3 个字还没写出来，不可能参考它。

```
Encoder Self-Attention（双向，无 mask）：
  计算 b2 时：看 a1, a2, a3, a4 全部

Decoder Masked Self-Attention（单向，有 mask）：
  计算 b2 时：只看 a1, a2（不能看 a3, a4）
```

### 8.2 Mask 是怎么实现的？（slides p29）

在计算 Attention Score 之后、Softmax 之前，把不应该看到的位置设为 **负无穷**，Softmax 后这些位置的权重就变成 0。

```python
def masked_self_attention(Q, K, V, mask):
    """
    mask: 上三角为 True 的布尔矩阵，True 的位置表示"不能看"
    """
    score = Q @ K.transpose(-2, -1) / (dk ** 0.5)   # [T, T]

    # 关键一步：把未来位置设为负无穷
    score = score.masked_fill(mask, float('-inf'))    # 未来位置 → -∞

    attn = F.softmax(score, dim=-1)  # -∞ 经过 softmax → 0
    output = attn @ V
    return output

# 生成 causal mask（下三角为 False，上三角为 True）
T = 4
mask = torch.triu(torch.ones(T, T), diagonal=1).bool()
# mask = [[False, True,  True,  True ],
#         [False, False, True,  True ],
#         [False, False, False, True ],
#         [False, False, False, False]]
```

### 8.3 Mask 后的 Attention 矩阵长什么样？

```
原始 Attention Score（Softmax 前）：
      t1    t2    t3    t4
t1 [ 0.8   0.3   0.5   0.1 ]
t2 [ 0.2   0.9   0.4   0.6 ]
t3 [ 0.3   0.7   0.8   0.2 ]
t4 [ 0.1   0.5   0.3   0.9 ]

Mask 后（上三角变 -∞）：
      t1    t2    t3    t4
t1 [ 0.8   -∞    -∞    -∞  ]  ← t1 只能看自己
t2 [ 0.2   0.9   -∞    -∞  ]  ← t2 看 t1 和自己
t3 [ 0.3   0.7   0.8   -∞  ]  ← t3 看 t1, t2, 自己
t4 [ 0.1   0.5   0.3   0.9 ]  ← t4 看所有

Softmax 后（-∞ → 0，每行和为 1）：
      t1    t2    t3    t4
t1 [ 1.0   0.0   0.0   0.0 ]
t2 [ 0.33  0.67  0.0   0.0 ]
t3 [ 0.19  0.29  0.52  0.0 ]
t4 [ 0.11  0.26  0.17  0.46]
```

### 8.4 与 CLIP 的关键关系

**CLIP 文本编码器就用了 Masked Self-Attention**（因为架构源自 GPT-2）。这意味着：

```
CoOp 的 prompt: [v1][v2][v3][v4][cat]

在 Masked Self-Attention 中：
  [v1] 只能看到自己
  [v2] 能看到 [v1] 和自己
  [v3] 能看到 [v1], [v2] 和自己
  [v4] 能看到 [v1], [v2], [v3] 和自己
  [cat] 能看到 [v1], [v2], [v3], [v4] 和自己 ← 看到了全部 prompt！

所以 CLIP 取 [EOS]（最后位置）的输出做特征
因为只有最后一个 token 融合了所有前面 token 的信息
```

这就是 CoOp 把 class token 放在 prompt **后面**（end 位置）的原因：class token 需要"看到"所有 prompt 向量才能生成好的文本特征。如果把 class token 放在前面（mid 位置），它看不到后面的 prompt 向量。

---

## 九、Cross Attention — Encoder-Decoder 的桥梁（对应 slides p39-43）

### 9.1 Cross Attention 是什么？

Cross Attention 是连接 Encoder 和 Decoder 的机制。在 Decoder 的每一层中，除了 Masked Self-Attention，还有一个 Cross Attention 模块，用来"查看" Encoder 的输出。

```
Decoder 一层的完整流程（slides p39 架构图）：

输入（已生成的 token）
  ↓
[Masked Self-Attention]  → Decoder 内部的 token 互相交流
  ↓ + 残差 + LayerNorm
[Cross Attention]        → Decoder 向 Encoder "提问"
  ↓ + 残差 + LayerNorm
[FFN]                    → 非线性变换
  ↓ + 残差 + LayerNorm
输出
```

### 9.2 Cross Attention 的 Q/K/V 来自哪里？（slides p40-41）

这是 Cross Attention 和 Self-Attention 的**关键区别**：

```
Self-Attention:  Q, K, V 全部来自同一个输入
Cross Attention: Q 来自 Decoder，K 和 V 来自 Encoder

具体来说（slides p40）：
  Encoder 输出 → 生成 K 和 V（"信息提供方"）
  Decoder 当前层输出 → 生成 Q（"信息查询方"）

  q = Decoder_output @ Wq      # Decoder 在问："我现在需要什么信息？"
  k1, k2, k3 = Encoder_out @ Wk  # Encoder 在说："我这里有这些信息"
  v1, v2, v3 = Encoder_out @ Wv  # Encoder 的实际信息内容

  attn_score = q @ [k1, k2, k3]^T  # 算 Decoder 和 Encoder 各位置的相关性
  output = softmax(attn_score) @ [v1, v2, v3]  # 加权提取 Encoder 的信息
```

### 9.3 PyTorch 伪代码

```python
class CrossAttention(nn.Module):
    def __init__(self, d_model, num_heads):
        super().__init__()
        self.Wq = nn.Linear(d_model, d_model)  # Q 来自 Decoder
        self.Wk = nn.Linear(d_model, d_model)  # K 来自 Encoder
        self.Wv = nn.Linear(d_model, d_model)  # V 来自 Encoder
        self.Wo = nn.Linear(d_model, d_model)
        self.dk = d_model // num_heads

    def forward(self, decoder_hidden, encoder_output):
        """
        decoder_hidden:  Decoder 当前层的输出 [B, T_dec, D]
        encoder_output:  Encoder 最终输出     [B, T_enc, D]
        """
        Q = self.Wq(decoder_hidden)   # [B, T_dec, D] — 来自 Decoder
        K = self.Wk(encoder_output)   # [B, T_enc, D] — 来自 Encoder
        V = self.Wv(encoder_output)   # [B, T_enc, D] — 来自 Encoder

        # Q 和 K 的维度不同：T_dec × T_enc
        score = Q @ K.transpose(-2, -1) / (self.dk ** 0.5)  # [B, T_dec, T_enc]
        attn = F.softmax(score, dim=-1)
        output = attn @ V  # [B, T_dec, D]

        return self.Wo(output)
```

### 9.4 生活类比

Cross Attention 就像**开卷考试**：Encoder 是你的参考资料（课本），Decoder 是你在写答案。每写一个字（Decoder），你都会回头翻参考资料（Encoder），找到和当前最相关的内容，提取出来辅助你写下一个字。

### 9.5 与 CLIP 的关系

CLIP 的文本端**没有用 Cross Attention**——它是纯 Decoder 风格的 Transformer（只有 Masked Self-Attention + FFN）。但理解 Cross Attention 对你后续研究很重要，因为：

- **CLIP 的图文对齐**本质上是在 embedding 空间做的"隐式 Cross Attention"（余弦相似度）
- **DiPrompT** 等进阶工作可能在 Prompt 和图像特征之间引入显式 Cross Attention
- 完整 Transformer 架构（如机器翻译）的 Decoder 都有 Cross Attention

---

## 十、Training — Teacher Forcing（对应 slides p45-46）

### 10.1 训练时的一个关键问题

推理时，Decoder 用**自己上一步的输出**作为下一步的输入（Autoregressive）。但训练时如果也这样做，一旦早期输出错误，后面的训练信号全部被污染。

### 10.2 Teacher Forcing 的解法（slides p46）

训练时不用 Decoder 自己的输出，而是**直接喂正确答案（Ground Truth）**作为输入：

```
推理时（Autoregressive，用自己的输出）：
  START → Decoder → "機" → Decoder → "器" → Decoder → "學" → ...
  如果第2步输出了"氣"而不是"器"，后面全部出错

训练时（Teacher Forcing，用 Ground Truth）：
  输入：START, 機, 器, 學     ← 全部是正确答案
  目标：機, 器, 學, 習, END   ← 每个位置的监督信号

  不管 Decoder 预测对不对，下一步的输入始终是正确的
  → 每个位置都能得到准确的梯度信号
```

### 10.3 PyTorch 伪代码

```python
def train_step(encoder_output, target_sequence):
    """
    target_sequence: [機, 器, 學, 習]（Ground Truth）
    """
    # 构造 Decoder 输入：在 target 前面加 START
    decoder_input = torch.cat([START_TOKEN, target_sequence[:-1]])
    # decoder_input = [START, 機, 器, 學]

    # 构造标签：target 后面加 END
    labels = torch.cat([target_sequence, END_TOKEN])
    # labels = [機, 器, 學, 習, END]

    # Decoder 一次性处理所有位置（因为 Mask 保证每个位置只看前面的）
    logits = decoder(decoder_input, encoder_output)  # [T, vocab_size]

    # 每个位置都算 cross entropy
    loss = F.cross_entropy(logits, labels)
    return loss
```

### 10.4 Exposure Bias（slides p56）

Teacher Forcing 有一个副作用叫 **Exposure Bias**：训练时 Decoder 总是看到正确的输入，但推理时看到的是自己（可能错误的）输出。训练和推理的"曝光"不一致。

```
训练时：Decoder 看到的 = Ground Truth（完美输入）
推理时：Decoder 看到的 = 自己的输出（可能有错）

→ 模型从未在训练中见过"错误输入"的情况
→ 一旦推理时出错，模型不知道如何纠正
```

解法之一是 **Scheduled Sampling**（slides p57）：训练时以一定概率用模型自己的输出代替 Ground Truth，让模型逐渐适应"不完美输入"。

---

## 十一、完整 Transformer Decoder Block

### 11.1 结构（综合 slides p26-27）

一个 Decoder Block 比 Encoder Block **多一层 Cross Attention**：

```
输入（已生成 token 的 embedding + Positional Encoding）
  ↓
[Masked Multi-Head Self-Attention]    ← 只看已生成的部分
  ↓ + 残差 + LayerNorm
[Cross Multi-Head Attention]          ← Q 来自 Decoder，K/V 来自 Encoder
  ↓ + 残差 + LayerNorm
[Feed-Forward Network]
  ↓ + 残差 + LayerNorm
输出
```

### 11.2 PyTorch 伪代码

```python
class TransformerDecoderBlock(nn.Module):
    def __init__(self, d_model=512, num_heads=8, d_ff=2048):
        super().__init__()
        self.masked_attn = MultiHeadAttention(d_model, num_heads)
        self.cross_attn = CrossAttention(d_model, num_heads)
        self.ffn = FFN(d_model, d_ff)
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)
        self.norm3 = nn.LayerNorm(d_model)

    def forward(self, x, encoder_output, causal_mask):
        # Sub-layer 1: Masked Self-Attention（只看前面的 token）
        attn_out = self.masked_attn(x, mask=causal_mask)
        x = self.norm1(x + attn_out)

        # Sub-layer 2: Cross Attention（查看 Encoder 的输出）
        cross_out = self.cross_attn(decoder_hidden=x,
                                     encoder_output=encoder_output)
        x = self.norm2(x + cross_out)

        # Sub-layer 3: FFN
        ffn_out = self.ffn(x)
        x = self.norm3(x + ffn_out)

        return x
```

### 11.3 Encoder vs Decoder 对比总结

| 特性 | Encoder | Decoder |
|------|---------|---------|
| Self-Attention 类型 | 双向（看所有 token） | **Masked**（只看前面的 token） |
| Cross Attention | 无 | 有（Q 来自 Decoder，K/V 来自 Encoder） |
| 生成方式 | 一次处理所有输入 | Autoregressive，逐个生成 |
| 训练技巧 | 标准监督学习 | Teacher Forcing |
| 典型用途 | BERT、ViT | GPT、文本生成 |
| **CLIP 中的角色** | **图像编码器（ViT）** | **文本编码器（GPT-2 风格，无 Cross Attention）** |

**CLIP 文本端的特殊性**：虽然叫"编码器"，但架构实际上是 Decoder 风格（有 Masked Self-Attention），只是去掉了 Cross Attention。这是因为 CLIP 文本端源自 GPT-2 架构。

```
完整 Decoder Block（如机器翻译）：
  Masked Self-Attention → Cross Attention → FFN

CLIP 文本端（简化版 Decoder）：
  Masked Self-Attention → FFN  （没有 Cross Attention）
  → 因此 CLIP 文本端是"只有 Self-Attention 的 Decoder"
```

---

## 十二、与 CoOp 研究的核心连接

学完 Encoder 和 Decoder 后，回头看 CoOp，这些设计决策现在应该完全通透了：

### 12.1 为什么 CLIP 取 [EOS] 位置做特征？

因为 CLIP 文本端用 Masked Self-Attention，只有最后位置的 token 融合了前面所有 token 的信息。

```
[v1][v2][v3][v4][cat][EOS]

[EOS] 的 Attention 范围：v1, v2, v3, v4, cat, EOS（全部）
→ [EOS] 是唯一一个"看过所有 prompt + 类名"的 token
→ 所以用 [EOS] 位置的输出代表整个句子的语义
```

### 12.2 为什么 CoOp 的 class token 位置影响性能？

```
end 位置（默认）：[v1][v2][v3][v4][cat]
  → [cat] 能看到所有 v1~v4
  → [EOS] 能看到 v1~v4 + cat
  → 信息充分

mid 位置：[v1][v2][cat][v3][v4]
  → [cat] 只能看到 v1, v2（看不到 v3, v4）
  → [EOS] 能看到全部
  → [cat] 处的信息不完整，但 v3, v4 能看到 cat 并补充信息
  → 更灵活，但训练更难
```

### 12.3 为什么 DiPrompT 在中间层插入 Prompt？

Transformer 有 12 层，每层都有 Self-Attention。DiPrompT 不只在输入层插入 prompt，还在中间层插入，相当于在不同抽象层次都给 CLIP "递任务说明卡"，从而更精细地引导特征提取。

---

## 十三、核心概念速查表

| 概念 | 一句话解释 | 与 CLIP/CoOp 的关系 |
|------|-----------|---------------------|
| Self-Attention | 序列中每个 token 和所有 token 计算相关性并融合信息 | CLIP 文本编码的核心操作 |
| Q/K/V | 查询/钥匙/值，三组线性变换 | 每层 Transformer 都有 |
| Scaled Dot-Product | 除以 √dk 防止梯度消失 | 和 CLIP 公式里的温度 τ 类似的缩放思想 |
| Multi-Head | 多组 Q/K/V 并行，捕捉不同关系 | CLIP 用 8~12 个 head |
| Positional Encoding | 给 token 加上位置信息 | CoOp prompt 的插入位置影响性能的原因 |
| Residual Connection | 输出 = 原始输入 + 变换后的输入 | 确保深层 Transformer 能训练 |
| Layer Normalization | 对每个样本独立归一化 | 每个 Block 里有两或三个 |
| FFN | 两层 MLP，先升维再降维 | 提供非线性变换能力 |
| **Masked Self-Attention** | 每个 token 只能看到自己和前面的 token | **CLIP 文本端用这个，所以取 [EOS] 做特征** |
| **Cross Attention** | Q 来自 Decoder，K/V 来自 Encoder | CLIP 文本端没有，但图文对齐是隐式版本 |
| **Autoregressive** | 逐个生成 token，每步依赖前一步 | CLIP 文本端的 Mask 设计源于此 |
| **Teacher Forcing** | 训练时用 Ground Truth 而非模型输出作为输入 | Decoder 训练的标准做法 |
| **Exposure Bias** | 训练用真实输入 vs 推理用模型输出的不一致 | Scheduled Sampling 可缓解 |
| [EOS] Token | 序列末尾的特殊 token | CLIP 取这个位置的输出做语义表示 |
| END Token | 告诉 Decoder 停止生成的信号 | Autoregressive 生成的终止条件 |

---

## 十四、学习检查清单

完成以下问题即代表掌握（新增 Decoder 相关项用 ★ 标注）：

- [ ] 给定 Q、K、V 矩阵，能手算 Attention 输出
- [ ] 理解为什么要除以 √dk
- [ ] 能解释 Multi-Head 的好处
- [ ] 知道 Positional Encoding 的必要性
- [ ] 能画出一个 Transformer Encoder Block 的结构
- [ ] ★ 能画出一个 Transformer Decoder Block 的结构（比 Encoder 多了什么？）
- [ ] ★ 能解释 Masked Self-Attention 的 mask 是怎么实现的（负无穷 → softmax → 0）
- [ ] ★ 能区分 Self-Attention 和 Cross Attention 的 Q/K/V 来源
- [ ] ★ 能解释 Autoregressive 生成的流程和 END token 的作用
- [ ] ★ 能解释 Teacher Forcing 的目的和 Exposure Bias 问题
- [ ] 理解 CLIP 文本端为什么取 [EOS] 而不是 [CLS] 或 Mean Pooling
- [ ] 能解释 CoOp 中 prompt 位置（end vs mid）对性能影响的原因

---

## 十五、推荐学习顺序

1. 先看 **Self-Attention（上）** → 理解 Q/K/V 和 Attention Score
2. 再看 **Self-Attention（下）** → 理解 Multi-Head 和位置编码
3. 然后看 **Transformer（上）** → 理解 Encoder 完整架构
4. 最后看 **Transformer（下）** → 理解 Decoder、Cross Attention、Teacher Forcing
5. 回头看 CoOp 论文 Section 3.1 → 此时应该完全通透

**视频链接**：
- Self-Attention（上）：https://youtu.be/hYdO9CscNes
- Self-Attention（下）：https://youtu.be/gmsMY5kc-zw
- Transformer（上）：https://youtu.be/n9TlOhRjYoc
- Transformer（下）：https://youtu.be/N6aRv06iv2g

---

*笔记整理：Arden 江 | AI 助手协助 | 基于李宏毅 2021 Spring Transformer slides (seq2seq_v9.pdf) | 2026-03-13*
