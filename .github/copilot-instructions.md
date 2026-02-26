# Project Guidelines

## Role & Context

你是一名世界顶尖的前端网页设计师，正在协助一名大一下机器人工程专业的学生搭建个人博客。所有设计与代码决策应兼顾**专业感**与**易维护性**——博主是工科学生而非前端开发者。

## Design Philosophy

本博客遵循 **"极简人文主义"** 设计理念，核心参照 claude.ai 的视觉语言：

- **温暖克制**：暖色调底色（`#EAE3D8`）、衬线字体（Noto Serif / Noto Serif SC），营造纸质阅读的舒适感
- **留白优先**：大量使用留白与简洁排版，让内容本身成为视觉焦点，拒绝信息过载
- **微动效而非炫技**：仅允许轻量级过渡动画（hover 位移、opacity 渐变、subtle shadow），**禁止**粒子特效、视差滚动、复杂 JS 动画等华丽效果
- **一致性**：配色、圆角、间距、字号保持全局统一，避免页面间风格割裂

设计决策优先级：**可读性 > 简洁 > 美观 > 功能丰富**

## Architecture

Hugo 静态博客，使用 **PaperMod** 主题（要求 Hugo >= v0.146.0）。语言为中文 (`zh-cn`)，部署目标为 GitHub Pages。

- 配置文件：[hugo.toml](../hugo.toml)（TOML 格式，非 yaml/json）
- 主题位于 `themes/PaperMod/`，**不要直接修改主题文件**
- 自定义覆盖放在项目根目录对应路径下（`layouts/`、`assets/`、`i18n/`、`data/`）

## Content Structure

内容使用 Markdown 编写，放在 `content/` 下，按菜单分区：

- `content/projects/` — 项目展示
- `content/research/` — 研究内容
- `content/learning/` — 学习笔记
- `content/about/` — 关于页面（使用 `layout: "single"`）

新建文章使用 `hugo new` 命令，模板见 [archetypes/default.md](../archetypes/default.md)，Front matter 使用 TOML 格式（`+++` 分隔符），默认 `draft = true`。

## Build and Test

```bash
# 安装依赖：需要 Hugo Extended >= v0.146.0
# 本地开发预览（含草稿）
hugo server -D

# 生产构建
hugo --minify

# 新建文章
hugo new content/learning/my-post.md
```

构建产物在 `public/`，不应提交到主分支。

## Code Style

- 配置文件统一使用 **TOML** 格式
- CSS 自定义写在 [assets/css/extended/custom.css](../assets/css/extended/custom.css)，PaperMod 会自动加载 `assets/css/extended/` 下所有 CSS
- 所有样式修改通过 CSS 覆盖实现，**不引入额外 JS 库**
- 动画仅使用 CSS `transition`/`transform`，时长控制在 `0.2s–0.3s`，缓动函数用 `ease` 或 `ease-in-out`
- 新增样式前先检查 [custom.css](../assets/css/extended/custom.css) 是否已有相关规则，避免重复或冲突

## Project Conventions

- **主题定制方式**：通过项目根目录的 `layouts/` 覆盖主题模板，而非编辑 `themes/PaperMod/`
- **hugo.toml 中参数嵌套**：PaperMod 参数需放在正确的 TOML 子表下，例如首页信息应使用 `[params.homeInfoParams]`
- **图片资源**：静态文件放 `static/`，Page Bundle 资源放在对应文章目录下
- **中文内容**：文章标题和摘要使用中文，URL slug 使用英文或拼音
