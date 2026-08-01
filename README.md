# Arden J 个人博客 — 使用指南

## 目录结构速览

```
my_blog/
├── hugo.toml              ← 站点配置（标题、导航、社交链接等）
├── content/               ← 所有文章和页面
│   ├── about/index.md     ← 「About」页面
│   ├── blog/              ← 「Blog」分区
│   ├── learning/          ← 「Learning」分区
│   └── thinking/          ← 「Thinking」分区
├── assets/css/extended/
│   ├── 00-tokens.css      ← 颜色、字体、尺寸等语义令牌
│   ├── 10-base.css        ← 排版基线与可访问性
│   ├── 20-chrome.css      ← 导航、页脚、搜索等站点框架
│   ├── 30-components.css  ← 文章、卡片、代码与 TOC 组件
│   ├── 40-pages.css       ← 首页及各类独立页面
│   ├── 50-motion.css      ← 动效与 reduced-motion
│   ├── 60-responsive.css  ← 768px / 1440px 响应式规则
│   └── syntax.css         ← Chroma 代码高亮双主题
├── layouts/               ← 模板覆盖（不动主题文件）
├── static/images/         ← 图片资源（logo、人像等）
└── themes/PaperMod/       ← 主题（不要直接修改）
```

---

## 一、日常写文章

### 1. 新建文章

在终端运行：

```bash
# 在 Blog 分区新建文章
hugo new content/blog/my-new-post.md

# 在 Learning 分区新建文章
hugo new content/learning/my-note.md

# 在 Thinking 分区新建文章
hugo new content/thinking/my-reflection.md
```

这会根据模板 `archetypes/default.md` 自动生成文件，内容类似：

```toml
+++
title = 'My New Post'
date = 2026-02-26T10:00:00+08:00
draft = true
+++
```

### 2. 编写文章内容

打开生成的 `.md` 文件，在 `+++` 下方用 Markdown 写正文：

```markdown
+++
title = '我的文章标题'
date = 2026-02-26T10:00:00+08:00
draft = true
description = '一句话摘要，会显示在文章列表中'
tags = ['ROS2', '机器人']
+++

正文从这里开始，支持所有 Markdown 语法...

## 二级标题

普通段落文字。

- 列表项
- 另一项

```python
# 代码块
print("hello")
```　
```

### 3. 常用 Front Matter 字段

| 字段 | 说明 | 示例 |
|---|---|---|
| `title` | 文章标题 | `'基于 ROS2 的导航系统'` |
| `date` | 发布日期 | `2026-02-26T10:00:00+08:00` |
| `draft` | 是否草稿 | `true`（草稿不会出现在正式构建中） |
| `description` | 摘要（显示在列表卡片） | `'一句话描述'` |
| `tags` | 标签 | `['ROS2', 'Python']` |
| `weight` | 排序权重（越小越靠前） | `1` |

### 4. 发布文章

将 `draft = true` 改为 `draft = false`，文章就会出现在正式构建中。

### 5. 删除文章

直接删除对应的 `.md` 文件即可：

```bash
rm content/learning/my-old-post.md
```

---

## 二、本地预览

```bash
# 含草稿的实时预览（推荐开发时用）
hugo server -D

# 不含草稿的预览（模拟正式发布效果）
hugo server
```

浏览器打开 `http://localhost:1313` 查看。修改文件后页面会自动刷新。

---

## 三、修改 About 页面

About 页使用 `layouts/_default/about.html`，结构化资料保存在 `data/about.yaml`。姓名、简介、头像、链接、经历、生活片段和工具栈都在该数据文件中修改。

`content/about/index.md` 负责页面元数据和可选的补充 Markdown：

```markdown
+++
title = "About"
layout = "about"
hideMeta = true
hideFooter = false
+++

## 补充内容

这部分会显示在结构化工具列表之后。
```

- **换头像**：把图片放到 `static/images/`，修改 `data/about.yaml` 的 `profile.avatar`
- **改个人资料或经历**：编辑 `data/about.yaml` 对应字段
- **补充长文**：从 `content/about/index.md` 的二级标题开始写，会接在结构化区块之后

---

## 四、修改站点配置

编辑 `hugo.toml`：

### 改网站标题 / 个人信息

```toml
title = "Arden J"                    # 网站标题

[params.homeInfoParams]
  Title = "Hello, I'm **Arden J**"   # 首页大标题（支持 Markdown 加粗）
  Content = "你的一句话介绍"            # 首页副标题
```

### 改社交链接

```toml
[[params.socialIcons]]
  name = "github"                    # 图标名（支持 github、email、twitter 等）
  url = "https://github.com/你的用户名"
```

要添加更多社交链接，复制这个块并修改 `name` 和 `url`。

### 改导航菜单

```toml
[[menu.main]]
  identifier = "blog"         # 唯一标识
  name = "Blog"               # 显示名
  url = "/blog/"              # 链接地址
  weight = 10                 # 排序（越小越靠左）
```

### 改页脚引言

```toml
[params.footer]
  text = '*万物静默如谜。* — 辛波斯卡'
```

### 改 Logo

把新 logo 图片放到 `static/images/`，然后修改：

```toml
[params.label]
  text = "Arden J"
  icon = '/images/logo-swirl.png'
  iconHeight = 28
```

---

## 五、新增分区（Section）

如果想增加一个新的内容分区（比如「Notes」）：

### 1. 创建分区目录和索引

```bash
mkdir -p content/notes
```

创建 `content/notes/_index.md`：

```markdown
+++
title = "Notes"
description = "日常随笔"
+++
```

### 2. 添加导航菜单

在 `hugo.toml` 中添加：

```toml
[[menu.main]]
  identifier = "notes"
  name = "Notes"
  url = "/notes/"
  weight = 25          # 调整数字控制在导航栏中的位置
```

### 3. 写文章

```bash
hugo new content/notes/first-post.md
```

如需让新分区出现在首页，还要：

1. 将 `notes` 加入 `hugo.toml` 的 `params.mainSections`。
2. 在 `data/sections.yaml` 添加 `notes` 的 `label`、`title`、`desc`、`noun`。
3. 如需分区题词，在 `data/epigraphs.yaml` 添加同名条目。

---

## 六、修改分区题词

首页与三个内容分区的题词统一保存在 `data/epigraphs.yaml`：

```yaml
learning:
  text: "你的新引言"
  source: "— 作者"
```

---

## 七、添加图片

### 方式一：放在 static 目录（全局共享）

```
static/images/my-photo.png
```

在文章中引用：`![描述](/images/my-photo.png)`

### 方式二：Page Bundle（跟随文章）

把文章改为目录形式：

```
content/learning/my-article/
├── index.md        ← 文章内容
└── photo.png       ← 图片
```

在文章中引用：`![描述](photo.png)`

---

## 八、PaperMod Shortcodes

PaperMod 自带几个短代码，适合在文章里做轻量增强。优先用在长文、图示和补充材料里，不建议为了装饰而滥用。

真实文章示例：`/learning/multi-learning/`

### 1. 折叠补充内容

适合收纳长推导、附录、命令输出或暂时不想打断正文节奏的材料：

```markdown
{{< collapse summary="展开推导过程" >}}
这里写可以被折叠的内容，支持 Markdown。

- 要点一
- 要点二
{{< /collapse >}}
```

如果想默认展开：

```markdown
{{< collapse summary="展开代码说明" openByDefault=true >}}
默认展开的内容。
{{< /collapse >}}
```

### 2. 带说明的图片

适合替代普通 Markdown 图片，增加 caption、居中和尺寸控制：

```markdown
{{< figure src="diagram.png" alt="模型结构图" caption="模型结构示意图" align="center" width="720" >}}
```

Page Bundle 中的图片继续放在文章目录旁边，例如：

```
content/learning/my-article/
├── index.md
└── diagram.png
```

### 3. 行内小图标

适合在一句话里嵌入很小的图标：

```markdown
PyTorch {{< inTextImg url="/images/tools/pytorch.svg" height="18" alt="PyTorch" >}} 是本文的主要框架。
```

### 4. 其他短代码

- `rawhtml`：在文章中插入少量 HTML。
- `ltr` / `rtl`：处理从左到右或从右到左的文本方向。

---

## 九、正式部署

### 构建

```bash
hugo --minify
```

产物在 `public/` 目录，部署到 GitHub Pages 即可。

### 部署前检查清单

1. 修改 `hugo.toml` 中的 `baseURL` 为你的实际域名：
   ```toml
   baseURL = 'https://你的用户名.github.io/'
   ```
2. 确保所有要发布的文章 `draft = false`
3. 运行 `hugo server` 最终预览确认

---
## 十、常用命令速查

| 操作 | 命令 |
|---|---|
| 本地预览（含草稿） | `hugo server -D` |
| 本地预览（正式） | `hugo server` |
| 正式构建 | `hugo --minify` |
| 新建文章 | `hugo new content/分区/文件名.md` |
| 查看 Hugo 版本 | `hugo version` |

---

## 十一、注意事项

- **不要修改** `themes/PaperMod/` 下的任何文件，所有自定义通过项目根目录的 `layouts/` 和 `assets/` 覆盖
- 样式按职责拆分在 `assets/css/extended/00-tokens.css` 至 `60-responsive.css`；代码高亮单独维护在 `syntax.css`
- 文章文件名建议用英文或拼音，避免中文 URL
- Front Matter 使用 TOML 格式（`+++` 分隔符），不是 YAML（`---`）
