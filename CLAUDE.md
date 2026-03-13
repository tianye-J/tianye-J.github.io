# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hugo 静态博客，使用 **PaperMod** 主题（要求 Hugo Extended >= v0.146.0）。语言为中文（`zh-cn`），部署到 GitHub Pages。自动部署通过 `.github/workflows/hugo.yaml` 在推送到 `main` 分支时触发。

## Commands

```bash
# 本地开发预览（含草稿）
hugo server -D

# 不含草稿的预览（模拟正式发布）
hugo server

# 生产构建
hugo --minify

# 新建文章（示例）
hugo new content/learning/my-post.md
```

## Architecture

- **配置文件**：`hugo.toml`（TOML 格式）
- **主题**：`themes/PaperMod/`——**不要直接修改主题文件**
- **自定义覆盖**：通过项目根目录的 `layouts/`、`assets/`、`i18n/`、`data/` 覆盖主题
- **自定义样式**：统一写在 `assets/css/extended/custom.css`，PaperMod 会自动加载该目录下所有 CSS

## Content Structure

文章使用 Markdown 编写，Front Matter 使用 **TOML 格式**（`+++` 分隔符，不是 YAML 的 `---`）：

```toml
+++
title = '文章标题'
date = 2026-01-01T10:00:00+08:00
draft = true
description = '摘要'
tags = ['tag1', 'tag2']
+++
```

内容分区：

- `content/projects/` — 项目展示
- `content/research/` — 研究内容
- `content/learning/` — 学习笔记
- `content/thinking/` — 随想
- `content/about/` — 关于页面（使用 `layout = "single"`）

发布文章：将 `draft = true` 改为 `draft = false`。

## Design Philosophy

本博客遵循 **"极简人文主义"** 设计理念：

- 暖色调底色（`#EAE3D8`）、衬线字体（Noto Serif / Noto Serif SC）
- 留白优先，内容为视觉焦点
- **仅允许轻量级动画**：CSS `transition`/`transform`，时长 `0.2s–0.3s`，缓动 `ease` 或 `ease-in-out`
- **禁止**粒子特效、视差滚动、复杂 JS 动画
- **不引入额外 JS 库**

设计决策优先级：**可读性 > 简洁 > 美观 > 功能丰富**

## Key Conventions

- 图片资源：全局共享放 `static/images/`，跟随文章的使用 Page Bundle（文章改为目录形式，`index.md` + 图片文件）
- 文章文件名使用英文或拼音，避免中文 URL；标题和摘要使用中文
- PaperMod 参数需放在正确的 TOML 子表下，如首页信息用 `[params.homeInfoParams]`
- 构建产物在 `public/`，不提交到主分支
- 新增样式前先检查 `custom.css` 是否已有相关规则，避免重复或冲突
