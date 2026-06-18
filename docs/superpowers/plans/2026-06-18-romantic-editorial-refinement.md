# Romantic Editorial Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the split dark-shell/light-card composition with a cohesive parchment light theme and a complete storm-grey dark theme, while tightening empty layout space.

**Architecture:** Keep the existing Hugo templates and artwork pipeline. Add a final romantic-editorial CSS layer that owns light/dark tokens and spacing, move homepage continuation links into their section headers, and use PaperMod's existing theme switcher rather than adding new state.

**Tech Stack:** Hugo Extended, Go templates, CSS custom properties, PaperMod theme state, Chroma syntax classes.

---

### Task 1: Define regression checks

**Files:**
- Modify: `scripts/check_fog_archive.sh`

- [x] Assert parchment, charcoal, copper, storm, mist, and amber tokens.
- [x] Assert the theme toggle is enabled and dark-mode selectors exist.
- [x] Assert homepage continuation links live inside section headers.
- [x] Run the check and confirm it fails before implementation.

### Task 2: Repair homepage content flow

**Files:**
- Modify: `layouts/_default/list.html`

- [x] Move each `View all` link into its matching section header.
- [x] Keep the article list as the only right-column element so no implicit second grid row is created.

### Task 3: Implement the romantic dual theme

**Files:**
- Modify: `hugo.toml`
- Modify: `assets/css/extended/custom.css`

- [x] Enable PaperMod's existing theme switcher.
- [x] Make light mode a continuous parchment field with charcoal text and copper interaction states.
- [x] Make dark mode a continuous storm-grey field with mist text and amber interaction states.
- [x] Remove visible main-card borders and shadows, and reduce desktop gutters.
- [x] Keep the artwork hero but treat it as a framed editorial image rather than a full dark-stage screen.

### Task 4: Tighten editorial spacing and typography

**Files:**
- Modify: `assets/css/extended/custom.css`

- [x] Use EB Garamond/Noto Serif SC for headings and book-serif text for body copy.
- [x] Remove homepage band minimum heights and reduce padding.
- [x] Compact list, About, Friends, Search, and article title areas while preserving readable paragraph rhythm.
- [x] Restyle blockquotes as margin notes without a filled background.

### Task 5: Harmonize technical content

**Files:**
- Modify: `assets/css/extended/syntax.css`
- Modify: `layouts/partials/comments.html`

- [x] Apply muted warm Chroma colors in light mode and subdued storm colors in dark mode.
- [x] Let Giscus follow the preferred color scheme and receive theme changes from the existing switcher.

### Task 6: Verify

**Files:**
- Test: `scripts/check_fog_archive.sh`

- [x] Run the structural regression check, `hugo`, `hugo --minify`, and `git diff --check`.
- [x] Inspect homepage, list, article, About, Friends, Search, and 404 in light and dark modes.
- [x] Confirm desktop and mobile layouts have no horizontal overflow or content-free grid rows.
