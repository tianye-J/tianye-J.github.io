# Fog Archive Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recast Arden's Blog as a dark storm shell surrounding pale archive paper, with a Turner-like responsive artwork hero on the homepage.

**Architecture:** Keep PaperMod and every existing feature intact. Use a local Hugo image resource and `home_info.html` for the hero, preserve `list.html` data queries while changing only homepage semantics, and finish the visual system in the local extended stylesheet so no theme files are touched.

**Tech Stack:** Hugo Extended, Go templates, Hugo image processing, responsive HTML, CSS, existing vanilla JavaScript.

---

### Task 1: Add structural regression checks

**Files:**
- Create: `scripts/check_fog_archive.sh`

- [x] Assert the atmospheric tokens, responsive hero, artwork credit, archive bands, reduced-motion rule, and absence of retired homepage decoration.
- [x] Run `bash scripts/check_fog_archive.sh` and confirm it fails before implementation.

### Task 2: Add the responsive artwork hero

**Files:**
- Create: `assets/images/hero-artwork.jpg`
- Modify: `layouts/partials/home_info.html`

- [x] Copy the CC0 source image into Hugo assets.
- [x] Generate 960, 1600, and 2400 pixel WebP and JPEG candidates through Hugo's image pipeline.
- [x] Render the greeting, description, epigraph, actions, and credit directly over the artwork with fixed dimensions and high fetch priority.

### Task 3: Convert homepage content into archive bands

**Files:**
- Modify: `layouts/_default/list.html`

- [x] Keep existing section queries and links.
- [x] Add archive-paper semantics and expose dates with machine-readable `datetime` values.
- [x] Keep the experience strip immediately after the hero and the heatmap after the three bands.

### Task 4: Apply the storm-shell visual system

**Files:**
- Modify: `assets/css/extended/custom.css`

- [x] Define the supplied shell, paper, fog, ash-blue, storm, ink, ochre, and ember tokens.
- [x] Style header, footer, home hero, experience strip, archive bands, heatmap, list pages, articles, search, friends, 404, and both TOC modes.
- [x] Remove visible topographic backgrounds, card stacking, broad rounding, warm gradients, and terracotta dominance.
- [x] Add explicit desktop/tablet/mobile typography and hero crops, plus reduced-motion overrides.

### Task 5: Verify output and visual behavior

**Files:**
- Test: `scripts/check_fog_archive.sh`

- [x] Run the structural check, `hugo`, `hugo --minify`, and `git diff --check`.
- [x] Confirm generated HTML contains WebP/JPEG `srcset`, `sizes`, artwork credit, and high fetch priority.
- [x] Inspect home, list, article, About, Friends, Search, and 404 at desktop and mobile widths.
- [x] Confirm the ship remains visible, the next homepage section peeks below the hero, the 1440px timeline TOC stays outside the paper, and mobile content does not overflow.
