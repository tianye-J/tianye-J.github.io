+++
title = 'FedDG 论文导读'
date = 2026-03-07T21:22:43+08:00
draft = false
description = "从 PromptFL、FedSR、SHOT 三条线梳理 FedDG / CLIP 训练场的论文地基。"
tags = ["联邦域泛化", "论文导读", "CLIP", "Prompt Learning", "Source-Free DA"]
series = ["联邦域泛化"]
+++


## 全局视角：三篇"地基"论文

| 论文 | 定位 |
|---|---|
| **PromptFL**（2023） | 方向一的起点 Baseline，"联邦 Prompt 学习的 FedAvg" |
| **FedSR**（NeurIPS 2022） | 通用 FedDG Baseline，三个方向都必须比较的对象 |
| **SHOT**（ICML 2020） | 方向三的历史根源，Source-Free DA 的奠基之作 |

这三篇是"祖师爷"级别——必须理解，但后续工作要站在它们肩膀上，不是复现它们。

---

# 方向一：CLIP / LLM + 联邦提示微调

## 入门论文

### CoOp — Prompt Learning for Vision-Language Models

> **会议**：IJCV 2022（原版 ICCV 2021）  
> **关键词**：Soft Prompt, CLIP, Context Optimization  
> 读这篇是因为 PromptFL 本质上就是"把 CoOp 塞进联邦框架"，不懂 CoOp 就没法理解 PromptFL。

CLIP 用"a photo of a [CLASS]"这样的手工文本做零样本分类，但手工模板很依赖玄学——换一句话描述，准确率可能差 10%。CoOp 的解决方案很直接：**别手写模板，让模型自己学出来**。

**Soft Prompt 的核心机制**

```
手工 Prompt（Hard Prompt）：
  输入 → "a photo of a [cat]" → CLIP 文本编码 → 分类

Soft Prompt（CoOp 的做法）：
  输入 → [v1][v2][v3][v4][cat] → CLIP 文本编码 → 分类
            ↑
        这 4 个 [v] 不是文字，是可学习的浮点向量
        训练时只更新这 4 个向量，CLIP 的其余参数全部冻结
```

**Soft Prompt 就是在类别词前面拼几个可学习的浮点向量**，训练时只更新这几个向量，CLIP 其余参数全部冻结。

**生活类比**：CLIP 是一个很聪明但很挑食的翻译官，Soft Prompt 就是你摸索出的一套"最佳开场白"，每次跟翻译官说话前先念这串开场白，它就会以最利于你任务的方式工作。

**训练目标**（PyTorch 伪代码）：

```python
import torch
import torch.nn as nn

class CoOp(nn.Module):
    def __init__(self, clip_model, n_ctx=4, ctx_dim=512):
        super().__init__()
        # 只有这一个小矩阵是可训练的，其余全部 requires_grad=False
        self.ctx = nn.Parameter(torch.randn(n_ctx, ctx_dim))
        self.clip = clip_model
        for p in self.clip.parameters():
            p.requires_grad = False  # CLIP 冻结

    def forward(self, image, class_token):
        # class_token: [num_classes, ctx_dim]（预先编码好的类别词向量）
        # 把 soft prompt 拼在类别词前面
        prompt = torch.cat([self.ctx.expand(len(class_token), -1, -1),
                            class_token.unsqueeze(1)], dim=1)
        text_features = self.clip.encode_text(prompt)
        image_features = self.clip.encode_image(image)
        # 对比学习：让图像特征和对应类别的文本特征最近
        logits = image_features @ text_features.T
        return logits
```

CoOp 证明了 Soft Prompt 在单机场景有效。PromptFL 的核心贡献就是"把这个 ctx 向量的训练过程改成联邦聚合"——理解了这一点，下面这篇就很自然了。

---

### PromptFL — Let Federated Participants Cooperatively Learn Prompts Instead of Models

> **期刊**：IEEE Transactions on Mobile Computing, 2023  
> **关键词**：Federated Prompt Learning, Communication Efficiency  
> 读完 CoOp 之后接着读这篇。

**核心问题**：标准联邦学习（FedAvg）每轮要同步整个模型的梯度，对 ViT-B/16 这种 86M 参数的大模型来说通信代价极高。PromptFL 的思路很简单：**只让客户端训练 Soft Prompt，模型本身变成不动的"公共基础设施"**。

**通信量差距有多大？**

```
FedAvg（同步全模型）：
  每轮通信 = ResNet-50 全量参数 ≈ 25M × 32bit = 800MB/客户端/轮

PromptFL（只同步 Prompt）：
  每轮通信 = 16 tokens × 512 dim = 8192个浮点数 ≈ 32KB/客户端/轮
  压缩比：约 25000:1
```

**联邦训练流程**：

```
1. 服务器广播：全局 Prompt 向量 ctx_global（极小）
2. 客户端本地：
     用 ctx_global 初始化本地 ctx
     在本地数据上训练 ctx（CLIP 全程冻结）
     上传 ctx_grad（梯度，同样极小）
3. 服务器聚合：FedAvg(ctx_grad_1, ctx_grad_2, ...) → ctx_global 更新
4. 重复
```

**PyTorch 联邦聚合伪代码**：

```python
# 服务器端
def fedavg_prompts(client_prompts, client_sizes):
    """client_prompts: list of [n_ctx, ctx_dim] tensors"""
    total = sum(client_sizes)
    global_prompt = torch.zeros_like(client_prompts[0])
    for prompt, size in zip(client_prompts, client_sizes):
        global_prompt += prompt * (size / total)
    return global_prompt

# 客户端本地训练（核心只改了一行）
optimizer = torch.optim.SGD([ctx], lr=0.002)  # 只优化 ctx
for x, y in local_dataloader:
    logits = model(x, ctx)                     # CLIP 不参与优化
    loss = F.cross_entropy(logits, y)
    loss.backward()
    optimizer.step()
```

**PromptFL 的局限（后续工作要超越的地方）**：
- 所有客户端学出来的是**同一个** Global Prompt，不区分客户端的域差异
- 没有考虑 Prompt 的跨域泛化性——在训练过的域上好，但遇到新域就不行
- 2023 年的工作，后续 CVPR/ICML 已经在此基础上叠了很多层

---

## 进阶阅读

| 论文 | 会议 | 一句话贡献 | 和我的关系 |
|---|---|---|---|
| **DiPrompT** | CVPR 2024 | 把 Prompt 解耦成"通用知识"和"域特有风格"两部分 | 直接 Baseline，需要超越 |
| **FedPGP** | ICML 2024 (arXiv:2405.09771) | LoRA 风格个性化 Prompt + CLIP 泛化约束 | 理解个性化 vs. 泛化的 trade-off |
| **FedTPG** | ICLR 2024 | 文本驱动的 Prompt Generator，让 Prompt 能泛化到未见类别 | Generator 思路可借鉴 |
| **FedDSPG** | arXiv 2025/09 (arXiv:2509.20807) | 生成式视角：训练 Generator 为未见域动态生成 Prompt | 最新 SOTA，找它的裂缝 |
| **FedMVP** | ICCV 2025 | 多模态（图像+属性）注入 Prompt，超越纯文本 Prompt | 拓展视野用 |

PromptFL → DiPrompT → FedDSPG，三篇连起来看就能理解这个子方向的进化主线。

---

# 方向二：机器人 Sim-to-Real + FedDG

## 入门论文

### FedSR — A Simple and Effective Domain Generalization Method for Federated Learning

> **会议**：NeurIPS 2022  
> **作者**：A. Tuan Nguyen, Philip Torr, Ser-Nam Lim（牛津 + Meta AI）  
> **代码**：github.com/atuannguyen/FedSR  
> 这是通用 FedDG Baseline，不是机器人专属——但方向二实验对比中必须出现它。

**核心问题**：大多数联邦学习方法只关心在现有客户端上表现好，完全忽视"来了一个从没见过的新客户端（新域）该怎么办"。FedSR 把 Domain Generalization 的目标正式嫁接进联邦框架。

**FedSR 的核心思路：让表示"简单"**

```
普通深度学习的特征学习：
  尽可能学到所有特征，包括域特有特征（光照、背景、噪声）
  → 在训练域上极好，在新域上灾难性失败

FedSR 的"简单表示"：
  用信息瓶颈原则，只保留预测标签必要的特征，丢掉域特有噪声
  → 泛化能力更强（因为学到的是本质特征）
```

**两个核心正则化项**：

```python
def fesr_loss(z, y, z_dist, lambda_l2r=0.01, lambda_cmi=0.001):
    """
    z:      特征向量（encoder 输出）
    y:      标签
    z_dist: 特征的概率分布（变分推断）
    """
    # 主损失：标准分类
    ce_loss = F.cross_entropy(classifier(z), y)
    
    # 正则化1：L2 范数正则（让表示空间紧凑）
    l2r_loss = torch.norm(z, p=2, dim=1).mean()
    
    # 正则化2：条件互信息最小化（让特征只保留与 y 相关的信息）
    # I(X; Z | Y) → 最小化，用 ELBO 近似
    cmi_loss = -z_dist.log_prob(z).mean()  # KL 散度近似
    
    total = ce_loss + lambda_l2r * l2r_loss + lambda_cmi * cmi_loss
    return total
```

**生活类比**：FedSR 就像考前只记最核心的知识点，不背偏题。每个学生（客户端）用自己的笔记学习，但大家都遵循"只记主干，不记杂枝"的原则，最后合并的全局模型在任何新考场（新域）都有基础分保底。

**为什么方向二必须用 FedSR 做 Baseline**：它是学术界公认的 FedDG 通用 Baseline。论文如果不包含 FedSR 的比较结果，审稿人大概率会要求补充。它有**官方开源代码**，在 PACS/VLCS/Office-Home/DomainNet 上都有报告数字，可以直接拿来对比。

---

### Sim-to-Real Transfer via Language（非联邦版原型）

> **会议**：RSS 2024（Robotics: Science and Systems）  
> **关键词**：CLIP semantic anchor, Sim-to-Real, Domain-invariant representation  
> 这篇是方向二 idea 的直接前身——无联邦版本的 CLIP 语义锚对齐。

**核心思路**：仿真图和真实图长得完全不同，但它们描述的是**同一个物理概念**（"一个红色积木"）。CLIP 的文字端天然理解这些概念，因此可以作为"跨域语义锚点"。

```
不用 CLIP：
  仿真图特征 → [ResNet] → 向量 A    ← 这两个向量差异极大
  真实图特征 → [ResNet] → 向量 B    ← 无法对齐

用 CLIP 文字锚：
  仿真图特征 → [CLIP Image Enc] → 向量 A ─┐
                                            ├─→ 都靠近"a red cube" 的文本向量
  真实图特征 → [CLIP Image Enc] → 向量 B ─┘
  文字锚点   → [CLIP Text Enc]  → 向量 T（"a red cube on a table"）
```

**这篇论文的"裂缝"**：它完全没有考虑联邦场景。多台机器人的数据如果放到同一台机器上做对齐，就违反了数据隐私原则。**如何在各客户端数据不能共享的情况下，用 CLIP 文字端做分布式的语义锚对齐？**——这就是方向二 idea 的切入点。

---

## 进阶阅读

| 论文 | 会议 | 一句话贡献 | 和我的关系 |
|---|---|---|---|
| **gPerXAN** | CVPR 2024 | 个性化重组 BN 层过滤域偏见，论文直接提机器人应用 | 方向二专属 Baseline |
| **FedDG（Liu et al.）** | CVPR 2021 | FedDG 开山之作：频域风格迁移生成跨域样本 | 理解数据操作分支的奠基逻辑 |
| **StableFDG** | NeurIPS 2023 | 风格+注意力双路联合联邦域泛化 | 参考数据增强策略 |
| **FedADG** | arXiv 2021 | 对抗联邦域对齐，用参考分布做分布匹配 | 理解域对齐分支的基本方法 |
| **VisDA-2017 数据集论文** | arXiv 2017 | 152K 仿真 + 55K 真实，Sim-to-Real 标准 Benchmark | 方向二的首选数据集 |

FedSR → gPerXAN → Sim2Real with Language，再看 FedDG (CVPR 2021) 了解数据操作分支的历史。

---

# 方向三：Source-Free FedDG + 不确定性感知聚合（蔡老师主场）

## 入门论文

### SHOT — Do We Really Need to Access the Source Data?

> **会议**：ICML 2020  
> **作者**：Liang et al.  
> **关键词**：Source-Free DA, Pseudo-label, Information Maximization  
> Source-Free Domain Adaptation 领域的开山之作，也是蔡老师方向的"祖师爷"。

**核心问题**：传统域自适应（DA）假设源域数据和目标域数据同时可访问，但现实中源域数据往往因为**隐私或版权**被销毁。SHOT 首次提出：**只用预训练好的源域模型 + 无标注目标域数据，能否完成自适应？**

**SHOT 的两个核心 loss**：

```python
def shot_loss(features, pseudo_labels, predictions):
    """
    features:      目标域样本的特征向量
    pseudo_labels: 模型自己预测出来的标签（高置信度样本才用）
    predictions:   softmax 输出概率
    """
    # 刀一：信息最大化（IM Loss）
    # 让模型预测：每个样本要确定（熵最小化）
    #            同时各类别要均匀（避免模型对所有样本都预测同一类）
    
    # 熵最小化：让每个样本的预测"集中"在一个类别
    entropy_loss = -(predictions * torch.log(predictions + 1e-8)).sum(dim=1).mean()
    
    # 多样性最大化：让不同样本的预测类别尽量分散
    mean_pred = predictions.mean(dim=0)  # 批次内的平均预测分布
    diversity_loss = (mean_pred * torch.log(mean_pred + 1e-8)).sum()  # 最大化边际熵的负值
    
    im_loss = entropy_loss + diversity_loss
    
    # 刀二：自监督伪标签（只用高置信度样本）
    pseudo_loss = F.cross_entropy(predictions, pseudo_labels)
    
    return im_loss + pseudo_loss
```

**生活类比**：SHOT 就像一个"只带毕业证书（模型）、没带过去卷子（源数据）"被调往新城市的医生。他的自适应策略是：先给所有病人快速诊断（生成伪标签），只相信自己最有把握的判断（高置信度），用这些判断来调整诊断风格（模型微调），同时确保诊断结果不会退化成"所有人都是感冒"（多样性约束）。

**SHOT 的历史地位**：它是蔡老师研究链的"源头"。后续工作（如 UCon-SFDA）是在 SHOT 基础上，用更精确的不确定性建模来改进"如何判断哪些伪标签值得信任"这个核心问题。

**关键局限**：SHOT 是**单机版本**，源数据销毁发生在单台机器上。如何把这个框架推广到多客户端的联邦设置？——这就是方向三的研究动机。

---

### FedWCA — Federated Source-Free Domain Adaptation via Weighted Cluster Aggregation

> **会议**：WACV 2025  
> **arXiv**：arXiv:2412.13757  
> **关键词**：Source-Free, Federated, Weighted Aggregation, Pseudo-label  
> 目前最接近方向三 idea 的前驱论文，也是最直接的超越对象。

FedWCA 把 Source-Free DA 真正搬进了联邦框架，并提出了第一个有理论支撑的联邦加权聚合方法。

**三阶段流程**：

```
阶段一：各客户端私有聚类
  每个客户端对本地特征做 K-means 聚类
  → 得到 K 个簇，每个簇代表一种"局部数据模式"
  → 注意：聚类结果不上传，只上传簇的统计量（保护隐私）

阶段二：加权簇聚合（WCA）
  服务器收到各客户端的簇统计量
  计算各客户端模型与全局模型的"特征对齐程度"作为权重
  对齐好（特征分布接近全局）→ 权重高
  对齐差（特征分布偏离全局）→ 权重低
  加权平均 → 全局模型更新

阶段三：Mixup 伪标签自训练
  用全局模型生成伪标签
  用 Mixup 数据增强 + 伪标签做自监督微调
```

**PyTorch 加权聚合伪代码**：

```python
def weighted_cluster_aggregation(client_models, client_features, global_model):
    """
    client_models:   各客户端上传的本地模型参数
    client_features: 各客户端的特征统计量（均值/方差，不是原始数据）
    global_model:    当前全局模型
    """
    weights = []
    for features in client_features:
        # 用特征和全局模型的对齐程度作为权重
        # 对齐程度 = 特征质心与全局分类器权重的余弦相似度
        global_weights = global_model.classifier.weight  # [num_classes, feat_dim]
        alignment = F.cosine_similarity(
            features.mean(dim=0, keepdim=True),  # [1, feat_dim]
            global_weights.mean(dim=0, keepdim=True)
        )
        weights.append(alignment.item())
    
    # 归一化权重
    weights = torch.softmax(torch.tensor(weights), dim=0)
    
    # 加权聚合
    new_state = {}
    for key in client_models[0].keys():
        new_state[key] = sum(w * m[key] for w, m in zip(weights, client_models))
    
    return new_state
```

**FedWCA 的致命裂缝**（也是 idea 入口）：

> **权重是静态的。** 对齐程度一旦计算完毕，在整个聚合过程中就固定了。但真实场景中，同一个客户端的数据里同时存在"高置信度样本"（白天光线充足）和"低置信度样本"（夜间、遮挡），静态权重无法区分这两类样本。**把动态不确定性估计引入聚合权重计算，就是填补 FedWCA 最大裂缝的方向。**

---

### UCon-SFDA — Revisiting Source-Free Domain Adaptation: Uncertainty Control Perspective

> **会议**：ICLR 2025  
> **OpenReview ID**：nx9Z5Kva96  
> **关键词**：DRO, Uncertainty Control, Partial Label, Source-Free  
> 蔡老师研究方向的最新代表作，方向三 idea 的技术提供方。

UCon-SFDA 用 Distributionally Robust Optimization（DRO）理论来精确建模哪些样本是"不确定的"，并为不确定样本设计专门的"宽松监督"策略。

**不确定性的三个来源**：

```
UCon-SFDA 把不确定性分成三类：
  1. 数据固有模糊性（本来就难分的样本，如边界类别）
  2. 域偏移导致的不确定性（从源域到目标域的分布变化）
  3. 模型容量导致的不确定性（模型本身的预测置信度）

对不同来源的不确定性，分别设计不同的监督信号强度。
```

**关键创新：Partial Label（偏标签）**——对高置信度样本用 hard pseudo-label 强监督，对低置信度样本只要求 top-K 个最可能的类别都算对，不强迫选一个。

```python
def uncertainty_aware_loss(predictions, uncertainty_scores, threshold=0.3):
    """
    predictions:       模型 softmax 输出，shape [B, C]
    uncertainty_scores: 每个样本的不确定性分数，shape [B]
    threshold:          高/低不确定性分界线
    """
    high_conf_mask = uncertainty_scores < threshold   # 低不确定性 = 高置信度
    low_conf_mask  = uncertainty_scores >= threshold  # 高不确定性 = 低置信度
    
    # 高置信度样本：用 Hard Pseudo-label 强监督
    hard_labels = predictions[high_conf_mask].argmax(dim=1)
    hard_loss = F.cross_entropy(predictions[high_conf_mask], hard_labels)
    
    # 低置信度样本：用 Partial Label 宽松监督
    # Top-K 个最可能的类别都算对（不强迫选一个）
    topk_mask = torch.zeros_like(predictions[low_conf_mask])
    topk_idx = predictions[low_conf_mask].topk(k=3, dim=1).indices
    topk_mask.scatter_(1, topk_idx, 1.0)
    partial_loss = -(topk_mask * torch.log(predictions[low_conf_mask] + 1e-8)).sum(dim=1).mean()
    
    return hard_loss + 0.5 * partial_loss
```

**UCon-SFDA 的裂缝**：这是**单机版本**，假设只有一台机器，没有联邦多客户端场景。它无法处理"如何在不共享数据的情况下，让多个客户端的不确定性信息指导服务器聚合"。

---

## 核心 Idea：两篇论文的"乐高拼接"

```
UCon-SFDA（ICLR 2025）         FedWCA（WACV 2025）
  ↓                               ↓
  动态不确定性估计               联邦 Source-Free 加权聚合
  精确的样本级不确定性建模        但权重是静态的
  单机版本（无联邦场景）          无动态不确定性感知
           ↓
           Idea：
    Dynamic Uncertainty-Aware
    Federated Aggregation
   （动态不确定性感知联邦聚合）
```

---

## 进阶阅读

| 论文 | 会议 | 一句话贡献 | 和我的关系 |
|---|---|---|---|
| **SHOT++** | TPAMI 2023 | SHOT 的增强版，加入目标域类别均衡约束 | 理解 SHOT 系列演化 |
| **NRC** | NeurIPS 2021 | 利用近邻关系图做 Source-Free DA | 邻域一致性思路 |
| **AaD** | NeurIPS 2022 | 对抗式 Source-Free DA，无需源域数据做域对齐 | 另一类 SFDA 方法视角 |
| **FedBN** | ICLR 2021 | 保留本地 BN 层不聚合，处理客户端间分布偏移 | 联邦个性化经典工作 |
| **SCAFFOLD** | ICML 2020 | 用控制变量纠正 client drift，FedAvg 的重要改进 | 方向三实验的联邦优化 Baseline |

**阅读建议**：SHOT → FedWCA（arXiv:2412.13757）→ UCon-SFDA（ICLR 2025）。三篇连起来就是方向三的完整故事线。

---

# 三方向论文全局索引

| 论文简称 | 全名关键词 | 会议/期刊 | 可查找方式 | 方向归属 |
|---|---|---|---|---|
| **CoOp** | Context Optimization for Vision-Language Models | IJCV 2022 | 搜 "CoOp CLIP prompt learning" | 方向一地基 |
| **PromptFL** | Let Federated Participants Learn Prompts | IEEE TMC 2023 | 搜 "PromptFL Guo 2023" | 方向一入门 |
| **DiPrompT** | Disentangled Prompt Tuning for FedDG | CVPR 2024 | 搜 "DiPrompT CVPR 2024" | 方向一进阶 |
| **FedPGP** | Federated Personalized Generalization Prompts | ICML 2024 | arXiv:2405.09771 | 方向一进阶 |
| **FedTPG** | Federated Text-driven Prompt Generation | ICLR 2024 | 搜 "FedTPG Qiu 2024" | 方向一进阶 |
| **FedDSPG** | Federated DG with Domain-Specific Soft Prompts | arXiv 2025 | arXiv:2509.20807 | 方向一前沿 |
| **FedMVP** | Federated Multimodal Visual Prompt Tuning | ICCV 2025 | 搜 "FedMVP ICCV 2025" | 方向一前沿 |
| **FedSR** | Simple Effective Domain Generalization for FL | NeurIPS 2022 | github: atuannguyen/FedSR | 方向二/三通用 Baseline |
| **gPerXAN** | Assemble Normalization for FedDG | CVPR 2024 | 搜 "gPerXAN CVPR 2024" | 方向二专属 Baseline |
| **FedDG (Liu)** | Episodic Learning Continuous Frequency Space | CVPR 2021 | 搜 "FedDG CVPR 2021 medical" | 方向二历史根源 |
| **SHOT** | Source Hypothesis Transfer Unsupervised DA | ICML 2020 | 搜 "SHOT ICML 2020 Liang" | 方向三地基 |
| **FedWCA** | Federated Source-Free DA Weighted Cluster Agg | WACV 2025 | arXiv:2412.13757 | 方向三核心前驱 |
| **UCon-SFDA** | Uncertainty Control SFDA | ICLR 2025 | OpenReview: nx9Z5Kva96 | 方向三核心前驱 |

---

## 阅读优先级建议

**方向三（推荐）**：
1. 优先：SHOT → FedWCA → UCon-SFDA（理解 idea 的来龙去脉）
2. 之后：FedSR（实验对比 Baseline），FedBN、SCAFFOLD（联邦优化基础）
3. 有余力：NRC、AaD（丰富 Related Work）

**方向一**：
1. 优先：CoOp → PromptFL → DiPrompT → FedDSPG
2. 之后：FedSR（对比 Baseline），FedTPG（Generator 思路参考）
3. 有余力：FedMVP（最新 SOTA）

**方向二**：
1. 优先：FedSR → gPerXAN → Sim2Real with Language
2. 之后：FedDG (CVPR 2021)（了解数据操作分支），FedADG（域对齐分支）
3. 有余力：VisDA-2017 数据集论文，GraspNet-1Billion

---

*整理者：Arden 江 | NJUPT 机器人工程 2025 级*
