---
name: hugo-ops
description: "Use this skill for ALL file operations in this Hugo blog — creating articles, modifying frontmatter, adding sections, previewing, and building. This skill MUST be used whenever the user asks to create a new post, add content, write a new article, start a draft, or any operation that creates or modifies content files. Directly creating .md files with Write/Edit will NOT be recognized by Hugo — you must use `hugo new` via the CLI. Also use when the user mentions 新建文章、写文章、发布、预览、构建、部署."
---

# Hugo Blog Operations

This blog uses Hugo with the PaperMod theme. Hugo has its own content management system — directly creating `.md` files bypasses Hugo's template engine and the files won't render correctly. All content operations must go through the Hugo CLI.

## Why This Matters

When you run `hugo new content/learning/my-post.md`, Hugo:
1. Reads `archetypes/default.md` to generate proper TOML frontmatter (`+++` delimiters)
2. Sets the correct `date` with timezone
3. Sets `draft = true` by default
4. Places the file in the right content directory

If you create a file directly with the Write tool, Hugo may not recognize it, the frontmatter format may be wrong, or the date/draft fields may be missing. Always use the CLI.

## Content Operations

### Creating a New Article

```bash
# Working directory must be the blog root
cd /Users/a/Desktop/learning/Arden's_blog

# Create in a specific section
hugo new content/learning/my-post.md
hugo new content/projects/my-project.md
hugo new content/research/my-research.md
```

After `hugo new` creates the file, THEN use Edit to add content, tags, description, series, and other frontmatter fields. The two-step flow is:

1. `hugo new content/<section>/<filename>.md` — creates the skeleton
2. Edit the generated file — add body content, tags, description, etc.

### Frontmatter Format

This blog uses TOML frontmatter (`+++` delimiters, NOT `---` YAML):

```toml
+++
title = 'Article Title'
date = 2026-04-13T14:00:00+08:00
draft = false
description = "Short summary for article list"
tags = ["tag1", "tag2"]
series = ["Series Name"]
math = true              # Enable LaTeX rendering if needed
+++
```

### Publishing

Change `draft = true` to `draft = false` in the frontmatter. That's it.

### Deleting Articles

```bash
rm content/learning/old-post.md
```

### Adding Images

Two approaches:

**Global images** — put in `static/images/`, reference as `![alt](/images/file.png)`

**Page bundle** — convert article to directory form:
```
content/learning/my-post/
├── index.md
└── image.png
```
Reference as `![alt](image.png)`

## Section Operations

### Creating a New Section

```bash
mkdir -p content/newsection
```

Then create `content/newsection/_index.md` with section metadata, and add a navigation entry in `hugo.toml`.

## Preview & Build

```bash
# Preview with drafts (development)
hugo server -D

# Preview without drafts (production simulation)
hugo server

# Build for deployment
hugo --minify
```

Do NOT run `hugo server` as a background process from Claude — tell the user to run it manually in their terminal.

## Verification

After creating or modifying content, run `hugo` (without server) to verify the build succeeds:

```bash
cd /Users/a/Desktop/learning/Arden's_blog && hugo 2>&1 | tail -5
```

## Rules

- **Never** use Write to create new `.md` content files — always `hugo new` first
- **Never** modify files under `themes/PaperMod/` — use `layouts/` and `assets/` overrides
- Custom CSS goes in `assets/css/extended/custom.css`
- Filenames should be English or pinyin, avoid Chinese characters in URLs
- Frontmatter is TOML (`+++`), not YAML (`---`)
