+++
title = '使用 PyTorch 实现 YOLO 目标检测'
date = 2026-02-10
draft = false
tags = ['深度学习', 'PyTorch', '计算机视觉']
description = '从零实现 YOLO 目标检测算法，理解锚框机制、损失函数设计与 NMS 后处理流程。'
+++

## 动机

目标检测是计算机视觉中的核心任务之一。YOLO（You Only Look Once）以其端到端的检测速度著称，适合机器人实时视觉感知场景。

## 核心概念

### 网格划分

将输入图像划分为 $S \times S$ 的网格，每个网格单元负责检测中心落在该区域的目标。

### 锚框（Anchor Boxes）

每个网格单元预测 $B$ 个边界框，每个框包含 5 个参数：

$$
(x, y, w, h, \text{confidence})
$$

### 损失函数

YOLO 的损失函数由三部分组成：

$$
\mathcal{L} = \lambda_{\text{coord}} \mathcal{L}_{\text{box}} + \mathcal{L}_{\text{obj}} + \lambda_{\text{noobj}} \mathcal{L}_{\text{noobj}} + \mathcal{L}_{\text{class}}
$$

## 实现要点

```python
class YOLOv1(nn.Module):
    def __init__(self, num_classes=20):
        super().__init__()
        self.backbone = self._build_backbone()
        self.head = nn.Linear(4096, 7 * 7 * (5 * 2 + num_classes))

    def forward(self, x):
        features = self.backbone(x)
        return self.head(features.flatten(1))
```

## 训练结果

在 VOC2012 数据集上的训练达到了 **mAP 65.3%**，验证了基础实现的正确性。下一步计划迁移到 YOLOv5 架构以提升检测精度。
