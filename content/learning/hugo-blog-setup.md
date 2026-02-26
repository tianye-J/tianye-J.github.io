+++
title = 'Hugo + PaperMod 博客搭建记录'
date = 2026-02-26
draft = false
tags = ['Hugo', '博客', '教程']
description = '从零开始搭建 Hugo 静态博客的完整记录，包括主题配置、样式自定义与部署流程。'
+++

## 为什么选择 Hugo

对比了几个主流静态博客方案后，选择 Hugo 的原因：

1. **构建速度极快** — 毫秒级构建，开发体验优秀
2. **无需运行时依赖** — 单个二进制文件，部署简单
3. **PaperMod 主题** — 简洁优雅，与我追求的极简设计理念契合

## 项目结构

```
my_blog/
├── hugo.toml          # 站点配置
├── content/           # Markdown 文章
│   ├── projects/      # 项目展示
│   ├── research/      # 研究内容
│   ├── learning/      # 学习笔记
│   └── about/         # 关于页面
├── assets/css/        # 自定义样式
├── layouts/           # 模板覆盖
├── static/            # 静态资源
└── themes/PaperMod/   # 主题（不要直接修改）
```

## 设计理念

本博客采用 **"极简人文主义"** 设计风格：

- 暖色调背景，营造纸质阅读感
- 衬线字体（Noto Serif），提升可读性
- 仅使用轻微的 CSS 过渡动画
- 大量留白，让内容本身成为焦点

## 常用命令

```bash
# 本地预览（含草稿）
hugo server -D

# 新建文章
hugo new content/learning/my-post.md

# 生产构建
hugo --minify
```

## 下一步计划

- [ ] 配置 GitHub Actions 自动部署
- [ ] 添加评论系统
- [ ] 优化 SEO 和 Open Graph 标签
