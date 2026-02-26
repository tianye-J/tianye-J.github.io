# Arden J 个人博客 — 使用指南

## 目录结构速览

```
my_blog/
├── hugo.toml              ← 站点配置（标题、导航、社交链接等）
├── content/               ← 所有文章和页面
│   ├── about/index.md     ← 「About」页面
│   ├── projects/          ← 「Projects」分区
│   ├── research/          ← 「Research」分区
│   └── learning/          ← 「Learning」分区
├── assets/css/extended/
│   └── custom.css         ← 自定义样式（颜色、排版、布局）
├── layouts/               ← 模板覆盖（不动主题文件）
├── static/images/         ← 图片资源（logo、人像等）
└── themes/PaperMod/       ← 主题（不要直接修改）
```

---

## 一、日常写文章

### 1. 新建文章

在终端运行：

```bash
# 在 Learning 分区新建文章
hugo new content/learning/my-new-post.md

# 在 Projects 分区新建文章
hugo new content/projects/my-project.md

# 在 Research 分区新建文章
hugo new content/research/my-research.md
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

编辑 `content/about/index.md`，这是一个普通 Markdown 文件：

```markdown
+++
title = "About"
layout = "single"
hideMeta = true
hideFooter = false
+++

<!-- 人像图片 -->
<div class="about-illustration" aria-hidden="true">
  <img src="/images/portrait.png" alt="" loading="lazy" draggable="false">
</div>

<!-- 题词 -->
<div class="page-epigraph">
  <p class="epigraph-text">你想放的引言</p>
  <p class="epigraph-source">— 作者</p>
</div>

## 关于我

你的个人介绍...
```

- **换头像**：把新图片放到 `static/images/`，然后修改 `<img src="/images/你的文件名.png">`
- **改引言**：直接编辑 `epigraph-text` 和 `epigraph-source` 的内容
- **改正文**：自由编辑 Markdown 内容

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
  identifier = "projects"     # 唯一标识
  name = "Projects"           # 显示名
  url = "/projects/"          # 链接地址
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
  icon = '/images/logo.png'
  iconHeight = 28
```

---

## 五、新增分区（Section）

如果想增加一个新的内容分区（比如「Blog」）：

### 1. 创建分区目录和索引

```bash
mkdir -p content/blog
```

创建 `content/blog/_index.md`：

```markdown
+++
title = "Blog"
description = "日常随笔"
+++
```

### 2. 添加导航菜单

在 `hugo.toml` 中添加：

```toml
[[menu.main]]
  identifier = "blog"
  name = "Blog"
  url = "/blog/"
  weight = 25          # 调整数字控制在导航栏中的位置
```

### 3. 写文章

```bash
hugo new content/blog/first-post.md
```

新分区会自动出现在首页的分区展示中。

---

## 六、修改分区题词

每个分区的题词在其 `_index.md` 文件中：

```
content/projects/_index.md
content/research/_index.md
content/learning/_index.md
```

编辑其中的 HTML：

```html
<div class="page-epigraph">
  <p class="epigraph-text">你的新引言</p>
  <p class="epigraph-source">— 作者</p>
</div>
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
content/projects/my-project/
├── index.md        ← 文章内容
└── photo.png       ← 图片
```

在文章中引用：`![描述](photo.png)`

---

## 八、正式部署

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

## 九、常用命令速查

| 操作 | 命令 |
|---|---|
| 本地预览（含草稿） | `hugo server -D` |
| 本地预览（正式） | `hugo server` |
| 正式构建 | `hugo --minify` |
| 新建文章 | `hugo new content/分区/文件名.md` |
| 查看 Hugo 版本 | `hugo version` |

---

## 十、注意事项

- **不要修改** `themes/PaperMod/` 下的任何文件，所有自定义通过项目根目录的 `layouts/` 和 `assets/` 覆盖
- 样式修改统一在 `assets/css/extended/custom.css` 中进行
- 文章文件名建议用英文或拼音，避免中文 URL
- Front Matter 使用 TOML 格式（`+++` 分隔符），不是 YAML（`---`）
