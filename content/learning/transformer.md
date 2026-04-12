+++
title = 'Self-Attention & Transformer 学习笔记'
date = 2026-03-13T12:08:04+08:00
draft = false
description = "transformer原理与基本架构"
tags = ["深度学习"]
series = ["Transformer"]
+++

## 一、为什么要学 Transformer？

Transformer 是当前深度学习的基础架构。NLP 领域的 BERT、GPT 系列，计算机视觉的 ViT，多模态模型 CLIP、Stable Diffusion——底层全是 Transformer。不理解 Transformer，后续读任何相关论文都会卡在架构细节上。

**学完本笔记后，应该能回答**：Q/K/V 怎么算？Multi-Head 为什么有用？Positional Encoding 干什么的？Encoder 和 Decoder 有什么区别？

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

因为 Q、K、V 全部来自**同一个输入** X。如果 Q 来自一个序列、K/V 来自另一个序列，就叫 **Cross-Attention**（交叉注意力）——这在 Transformer Decoder（如机器翻译中 Decoder 查看 Encoder 输出）和多模态模型（如图文对齐）中都会用到。

### 2.6 Self-Attention 的信息融合效果

以 BERT 为例，输入 `[CLS] I love this movie [SEP]`，经过 Self-Attention 后，`[CLS]` 位置的输出向量融合了整个句子的信息——这就是为什么 BERT 用 `[CLS]` 的输出做句子级分类。**每个 token 的输出都不再只代表自己，而是融合了序列中其他 token 的信息**。

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

### 3.4 实际模型中的 Multi-Head

主流 Transformer 模型普遍使用 8~16 个 head。比如 BERT-base 用 12 个 head（d_model=768，每个 head 的 dk=64），GPT-2 同样是 12 个 head（d_model=768）。更大的模型如 GPT-3 用了 96 个 head。多头数量的选择需要平衡表达能力和计算开销。

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

### 4.2 常见的位置编码方案

**方案一：正弦/余弦固定编码**（原始 Transformer 论文）

用不同频率的正弦和余弦函数为每个位置生成唯一的编码向量。优点是可以外推到训练时没见过的更长序列。

**方案二：可学习的位置编码**（GPT、BERT、CLIP 等）

直接把位置编码当作可训练参数，让模型自己学出最优的位置表示：

```python
# 可学习位置编码（简化版）
self.positional_embedding = nn.Parameter(
    torch.randn(max_seq_len, d_model)  # 可学习的，如 shape [512, 768]
)

def forward(self, tokens):
    x = self.token_embedding(tokens)    # [T, d_model]
    x = x + self.positional_embedding[:T]  # 加上位置信息
    x = self.transformer(x)
    return x
```

目前大多数模型使用可学习位置编码，因为它在固定长度输入上效果更好。

### 4.3 位置编码为什么重要？

一个直观的例子：`"狗咬人"` 和 `"人咬狗"` 用了完全相同的三个 token，但语义截然不同。没有位置编码，Self-Attention 无法区分这两个句子。

位置编码还影响模型对特殊 token 的处理。比如 BERT 把 `[CLS]` 放在位置 0，模型通过位置编码"知道"这个 token 的角色是汇聚全句信息；如果把 `[CLS]` 挪到中间，模型的行为会完全不同。

---

## 五、Transformer 完整架构

### 5.1 Encoder Block（编码器块）

这是 Transformer Encoder 的核心单元（BERT、ViT 等模型的基本构件），一个 Encoder Block 包含：

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
        self.activation = nn.GELU()            # 现代 Transformer 常用 GELU 激活

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

机器翻译："I love learning" [3词] → "我爱学习" [4字]     输入输出长度不同
文本摘要：一篇 500 字的文章 → 50 字的摘要
对话系统：用户问题 → 系统回答
```

Seq2seq 的核心架构就是 **Encoder + Decoder**（slides p15）：

```
输入序列 → [Encoder] → 隐层表示 → [Decoder] → 输出序列

Encoder：理解输入（"读题"）
Decoder：生成输出（"答题"）
```

**三种主流架构**：理解 Encoder 和 Decoder 的区别后，就能理解当前主流模型的架构选择：

- **Encoder-only**（BERT、ViT）：只用 Encoder，适合理解类任务（分类、特征提取）
- **Decoder-only**（GPT 系列）：只用 Decoder（带 Masked Self-Attention），适合生成类任务
- **Encoder-Decoder**（原始 Transformer、T5、BART）：完整架构，适合序列到序列任务（翻译、摘要）

---

## 七、Decoder — Autoregressive 生成（对应 slides p23-34）

### 7.1 什么是 Autoregressive（自回归）？

Decoder 生成输出时是**一个一个地生成**，每次生成一个 token，然后把这个 token 作为下一步的输入，如此循环（slides p24-25）。

```
以机器翻译 "I love learning" → "我爱学习" 为例（slides p24-25）：

第1步：输入 START token → Decoder → 输出概率分布 → argmax → "我"
第2步：输入 START + "我" → Decoder → 输出概率分布 → argmax → "爱"
第3步：输入 START + "我" + "爱" → Decoder → argmax → "学"
第4步：输入 START + "我" + "爱" + "学" → Decoder → argmax → "习"
第5步：输入 START + "我" + "爱" + "学" + "习" → Decoder → argmax → END

输出 END 后停止生成（slides p33-34）
```

**生活类比**：Autoregressive 像写作文——你先写第一个字，看了第一个字才写第二个字，看了前两个字才写第三个字。每个字都依赖前面所有已写的字。

### 7.2 错误传播问题（slides p30）

Autoregressive 有一个致命弱点：**如果某一步生成错了，后面所有步都会被带偏**。

```
正确路径：START → 我 → 爱 → 学 → 习 → END
错误路径：START → 我 → 受（错！）→ 学 → 习 → ...

"受"是错的，但 Decoder 会把"受"当成正确输入继续生成
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

CLIP 文本端和 GPT 都是 AT 风格。NAT 了解即可，目前主流生成模型基本都用 AT。

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

### 8.4 Masked Attention 的实际意义

**GPT 系列就用了 Masked Self-Attention**。这意味着在文本生成时，模型只能根据已生成的内容预测下一个 token：

```
生成句子 "今天天气真好"：

在 Masked Self-Attention 中：
  "今" 只能看到自己
  "天" 能看到 "今" 和自己
  "天" 能看到 "今", "天" 和自己
  "气" 能看到 "今", "天", "天" 和自己
  "真" 能看到前面所有 token
  "好" 能看到前面所有 token ← 融合了整个句子的信息

所以 Decoder-only 模型（如 GPT）取最后一个 token 的输出做预测
因为只有最后位置融合了前面所有 token 的信息
```

这也解释了为什么 GPT 风格的模型在生成任务上很强——Masked Attention 天然适配从左到右的自回归生成。而 BERT 用的是双向 Attention（无 mask），更适合理解类任务。

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

### 9.5 Cross Attention 的典型应用

Cross Attention 在以下场景中广泛使用：

- **机器翻译**：Decoder 生成目标语言时，通过 Cross Attention 查看源语言的 Encoder 输出
- **文本摘要**：Decoder 生成摘要时，回看原文的编码表示
- **多模态模型**：文本和图像之间的信息交互（如 Stable Diffusion 中文本条件引导图像生成）

注意，并非所有 Transformer 模型都有 Cross Attention。Encoder-only 模型（BERT）和 Decoder-only 模型（GPT）都没有 Cross Attention，只有完整的 Encoder-Decoder 架构才需要它。

---

## 十、Training — Teacher Forcing（对应 slides p45-46）

### 10.1 训练时的一个关键问题

推理时，Decoder 用**自己上一步的输出**作为下一步的输入（Autoregressive）。但训练时如果也这样做，一旦早期输出错误，后面的训练信号全部被污染。

### 10.2 Teacher Forcing 的解法（slides p46）

训练时不用 Decoder 自己的输出，而是**直接喂正确答案（Ground Truth）**作为输入：

```
推理时（Autoregressive，用自己的输出）：
  START → Decoder → "我" → Decoder → "爱" → Decoder → "学" → ...
  如果第2步输出了"受"而不是"爱"，后面全部出错

训练时（Teacher Forcing，用 Ground Truth）：
  输入：START, 我, 爱, 学     ← 全部是正确答案
  目标：我, 爱, 学, 习, END   ← 每个位置的监督信号

  不管 Decoder 预测对不对，下一步的输入始终是正确的
  → 每个位置都能得到准确的梯度信号
```

### 10.3 PyTorch 伪代码

```python
def train_step(encoder_output, target_sequence):
    """
    target_sequence: [我, 爱, 学, 习]（Ground Truth）
    """
    # 构造 Decoder 输入：在 target 前面加 START
    decoder_input = torch.cat([START_TOKEN, target_sequence[:-1]])
    # decoder_input = [START, 我, 爱, 学]

    # 构造标签：target 后面加 END
    labels = torch.cat([target_sequence, END_TOKEN])
    # labels = [我, 爱, 学, 习, END]

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
| 典型用途 | BERT、ViT、特征提取 | GPT、文本生成 |
| **代表模型** | **BERT、ViT** | **GPT 系列** |

**GPT 的特殊性**：GPT 虽然常被称为"语言模型"，但架构上就是 Decoder-only Transformer（有 Masked Self-Attention，没有 Cross Attention）。它不需要 Encoder，因为任务本身就是"根据前文生成下一个 token"。

```
完整 Encoder-Decoder（如机器翻译）：
  Masked Self-Attention → Cross Attention → FFN

GPT（Decoder-only）：
  Masked Self-Attention → FFN  （没有 Cross Attention）
  → 因此 GPT 是"只有 Self-Attention 的 Decoder"
```

---

## 十二、Transformer 变体与实际应用

学完 Encoder 和 Decoder 后，可以理解当前主流模型的架构选择逻辑。

### 12.1 Encoder-only：BERT

BERT 只用 Encoder（双向 Self-Attention），每个 token 都能看到序列中所有其他 token。这使得 BERT 擅长**理解类任务**——分类、命名实体识别、问答中的答案抽取。

```
输入：[CLS] I love this movie [SEP]

双向 Attention：每个 token 都能看到所有其他 token
→ [CLS] 位置的输出融合了整个句子的信息
→ 用 [CLS] 的输出接一个分类头，就能做情感分类
```

### 12.2 Decoder-only：GPT

GPT 只用 Decoder（Masked Self-Attention），每个 token 只能看到前面的 token。这天然适配**从左到右的文本生成**。

```
输入："今天天气"
→ "今" 只看自己
→ "天" 看 "今" 和自己
→ "天" 看 "今天" 和自己
→ "气" 看 "今天天" 和自己
→ 预测下一个 token："真"
```

GPT 系列从 GPT-1 到 GPT-4 都是这个架构，区别只在模型规模和训练数据。

### 12.3 Encoder-Decoder：T5、BART

完整的 Encoder-Decoder 架构适合**输入和输出都是序列、且长度不同**的任务：翻译、摘要、问答生成。Encoder 负责理解输入，Decoder 通过 Cross Attention 查看 Encoder 的输出来生成目标序列。

T5 的设计哲学是"把所有 NLP 任务都转化为 text-to-text 格式"，统一用 Encoder-Decoder 处理。

---

## 十三、核心概念速查表

| 概念 | 一句话解释 | 典型应用 / 为什么重要 |
|------|-----------|---------------------|
| Self-Attention | 序列中每个 token 和所有 token 计算相关性并融合信息 | 所有 Transformer 模型的核心操作 |
| Q/K/V | 查询/钥匙/值，三组线性变换 | 每层 Transformer 都有 |
| Scaled Dot-Product | 除以 √dk 防止梯度消失 | 保证 softmax 输出不会过于集中 |
| Multi-Head | 多组 Q/K/V 并行，捕捉不同关系 | BERT/GPT 用 12 个 head，大模型用更多 |
| Positional Encoding | 给 token 加上位置信息 | 没有它 Self-Attention 无法区分词序 |
| Residual Connection | 输出 = 原始输入 + 变换后的输入 | 确保深层 Transformer 能训练 |
| Layer Normalization | 对每个样本独立归一化 | 每个 Block 里有两或三个 |
| FFN | 两层 MLP，先升维再降维 | 提供非线性变换能力 |
| **Masked Self-Attention** | 每个 token 只能看到自己和前面的 token | **GPT 等生成模型的核心机制** |
| **Cross Attention** | Q 来自 Decoder，K/V 来自 Encoder | **机器翻译等 Seq2seq 任务的桥梁** |
| **Autoregressive** | 逐个生成 token，每步依赖前一步 | GPT 文本生成、机器翻译的 Decoder |
| **Teacher Forcing** | 训练时用 Ground Truth 而非模型输出作为输入 | Decoder 训练的标准做法 |
| **Exposure Bias** | 训练用真实输入 vs 推理用模型输出的不一致 | Scheduled Sampling 可缓解 |
| [EOS] / [SEP] Token | 序列末尾的特殊 token | Decoder-only 模型取最后位置做语义表示 |
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
- [ ] 能解释 Decoder-only 模型（GPT）为什么取最后位置的输出做预测
- [ ] 能区分 BERT（Encoder-only）和 GPT（Decoder-only）的架构差异及适用场景

---

## 十五、推荐学习顺序

1. 先看 **Self-Attention（上）** → 理解 Q/K/V 和 Attention Score
2. 再看 **Self-Attention（下）** → 理解 Multi-Head 和位置编码
3. 然后看 **Transformer（上）** → 理解 Encoder 完整架构
4. 最后看 **Transformer（下）** → 理解 Decoder、Cross Attention、Teacher Forcing
5. 动手实践：用 Hugging Face Transformers 库跑一个预训练模型（如 BERT 做文本分类），把学到的架构知识和实际代码对应起来

**视频链接**：
- Self-Attention（上）：https://youtu.be/hYdO9CscNes
- Self-Attention（下）：https://youtu.be/gmsMY5kc-zw
- Transformer（上）：https://youtu.be/n9TlOhRjYoc
- Transformer（下）：https://youtu.be/N6aRv06iv2g

---
