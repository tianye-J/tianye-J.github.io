#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
css="$root/assets/css/extended/custom.css"
hero="$root/layouts/partials/home_info.html"
home="$root/layouts/_default/list.html"
interlude="$root/layouts/partials/home_artwork_interlude.html"
heatmap="$root/layouts/partials/home_heatmap.html"
heatmap_fetcher="$root/scripts/fetch_github_contributions.py"
section_artwork="$root/layouts/partials/section_artwork.html"
learning_index="$root/content/learning/_index.md"

require() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if ! rg -U -q -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

reject() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if rg -U -q -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

require_count() {
  local expected="$1"
  local pattern="$2"
  local file="$3"
  local message="$4"
  local actual
  actual="$(rg -c -- "$pattern" "$file" || true)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s (expected %s, found %s)\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

require_before() {
  local first_pattern="$1"
  local second_pattern="$2"
  local file="$3"
  local message="$4"
  local first_line second_line
  first_line="$(rg -n -- "$first_pattern" "$file" | head -1 | cut -d: -f1)"
  second_line="$(rg -n -- "$second_pattern" "$file" | head -1 | cut -d: -f1)"
  if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

require '--shell:[[:space:]]*#182629' "$css" 'storm shell token is missing'
require '--ochre:[[:space:]]*#a96f38' "$css" 'ochre token is missing'
require '<picture class="home-hero-picture">' "$hero" 'responsive hero picture is missing'
require 'fetchpriority="high"' "$hero" 'hero must have high fetch priority'
require 'images/monk-by-the-sea.jpg' "$hero" 'Friedrich hero source is missing'
require 'Caspar David Friedrich · The Monk by the Sea · c. 1808–1810' "$hero" 'Friedrich hero credit is missing'
reject 'Public-domain artwork · CC0' "$hero" 'unsupported generic artwork credit is still rendered'
require 'home-archive-band' "$home" 'homepage archive bands are missing'
require 'partial "home_artwork_interlude.html"' "$home" 'Turner chapter plate is missing from the homepage'
require 'images/clare-hall-turner-1793.jpeg' "$interlude" 'Turner chapter plate source is missing'
require 'J. M. W. Turner · Clare Hall · 1793' "$interlude" 'Turner chapter plate credit is missing'
require 'loading="lazy"' "$interlude" 'Turner chapter plate must be lazy-loaded'
require '@media \(prefers-reduced-motion: reduce\)' "$css" 'reduced-motion handling is missing'
reject 'home-doodle' "$hero" 'retired homepage doodle is still rendered'
reject 'topo-bg\.svg' "$hero" 'retired topographic artwork is still rendered'
require '--romantic-bg:[[:space:]]*#f7f5f0' "$css" 'parchment background token is missing'
require '--romantic-text:[[:space:]]*#2c3539' "$css" 'charcoal text token is missing'
require '--romantic-accent:[[:space:]]*#b87333' "$css" 'copper accent token is missing'
require '--romantic-dark-bg:[[:space:]]*#12171c' "$css" 'storm dark background token is missing'
require '--romantic-dark-text:[[:space:]]*#e0e6ed' "$css" 'mist dark text token is missing'
require '--romantic-dark-accent:[[:space:]]*#df9b1e' "$css" 'amber dark accent token is missing'
require '\[data-theme="dark"\]' "$css" 'dark theme selector is missing'
require 'disableThemeToggle[[:space:]]*=[[:space:]]*false' "$root/hugo.toml" 'theme toggle must be enabled'
require 'home-section-more home-section-more--header' "$home" 'View all links must live in section headers'
require_count '3' 'home-section-more home-section-more--header' "$home" 'all three homepage sections must render View all links'
reject 'if gt \(len \$(learning|projects|thinking)\) 3' "$home" 'homepage View all links must not depend on post count'
require 'counter-reset:[[:space:]]*archive-section' "$css" 'editorial section numbering is missing'
require 'project-status::before' "$css" 'project status marker is missing'
reject 'home-heatmap-cell:nth-child' "$css" 'heatmap cells must use a regular compact grid'
require '--heatmap-cell-size:[[:space:]]*clamp\(' "$css" 'heatmap needs a responsive desktop cell size'
require 'grid-template-columns:[[:space:]]*repeat\(var\(--heatmap-weeks,[[:space:]]*52\),[[:space:]]*var\(--heatmap-cell-size\)\)' "$css" 'heatmap weeks must use responsive adjacent columns'
require 'home-heatmap-grid[^}]*gap:[[:space:]]*var\(--heatmap-gap\)' "$css" 'heatmap cells must use the shared compact gap'
reject 'home-section-list[^}]*margin-top:[[:space:]]*-[0-9]' "$css" 'homepage article indexes must not rely on negative offsets'
require 'home-section-header[^}]*align-self:[[:space:]]*stretch' "$css" 'homepage section dividers must follow the taller column'
require 'WEEKS = 52' "$heatmap_fetcher" 'GitHub contribution fetcher must request 52 weeks'
require 'data-weeks="52"' "$heatmap" 'heatmap template must default to 52 weeks'
require 'last year' "$heatmap" 'heatmap summary must describe the last year'
require '--heatmap-cell-size:[[:space:]]*10px' "$css" 'mobile heatmap cells must shrink to 10px'
require '--heatmap-gap:[[:space:]]*2px' "$css" 'mobile heatmap gap must shrink to 2px'
require 'description = "Notes on foundation models, post-training, and AI infrastructure\."' "$learning_index" 'Learning section description must be concise'
require 'home-heatmap[[:space:]]*\{[^}]*display:[[:space:]]*block' "$css" 'mobile heatmap must remain visible'
require 'home-heatmap-months span[^}]*white-space:[[:space:]]*nowrap' "$css" 'heatmap month labels must not wrap vertically'
require '\[data-theme="dark"\] \.home-section-header h2 a[^}]*color:[[:space:]]*var\(--romantic-dark-text\)[[:space:]]*!important' "$css" 'archive headings need an explicit dark-theme text color'
reject 'if and \(eq \$status "ok"\)' "$heatmap" 'fallback contribution data must not hide the heatmap'
require 'london-from-greenwich-park\.jpg' "$section_artwork" 'Learning artwork mapping is missing'
require 'hero-artwork\.jpg' "$section_artwork" 'Projects artwork mapping is missing'
require 'turner-alpine-storm\.jpg' "$section_artwork" 'Thinking artwork mapping is missing'
require '480x webp' "$section_artwork" '480px WebP section artwork is missing'
require '960x webp' "$section_artwork" '960px WebP section artwork is missing'
require '1600x webp' "$section_artwork" '1600px WebP section artwork is missing'
require 'loading="eager"' "$section_artwork" 'section masthead artwork must load eagerly'
require 'fetchpriority="high"' "$section_artwork" 'section masthead artwork must have high priority'
require 'Variant" "page' "$home" 'section-page artwork call is missing'
reject 'Variant" "band' "$home" 'homepage archive artwork calls must be removed'
reject 'home-section-lead|home-section-meta' "$home" 'homepage artwork wrappers must be removed'
require 'section-artwork--page' "$css" 'section-page banner styling is missing'
require 'section-artwork figcaption[^}]*overflow-wrap:[[:space:]]*anywhere' "$css" 'section artwork credits must wrap on narrow screens'
require 'section-artwork figcaption[^}]*white-space:[[:space:]]*normal' "$css" 'mobile section artwork credits must allow line wrapping'
require 'home-section\.home-archive-band[^}]*background:[^;]*linear-gradient' "$css" 'homepage archive color wash is missing'
require 'section-masthead' "$home" 'section artwork and title need a shared masthead wrapper'
require 'section-masthead-copy' "$home" 'section title must overlay the artwork'
require_before 'section-masthead-breadcrumbs' 'section-masthead section-masthead--' "$home" 'breadcrumbs must remain above the artwork masthead'
require 'section-masthead[^}]*width:[[:space:]]*min\(1180px' "$css" 'section masthead must approach the homepage artwork width'
require 'section-artwork--page picture[^}]*aspect-ratio:[[:space:]]*14[[:space:]]*/[[:space:]]*5' "$css" 'desktop section masthead must use the larger 2.8:1 crop'
require 'section-masthead-copy[^}]*position:[[:space:]]*absolute' "$css" 'section title must be positioned over the artwork'
require 'about-facts-index' "$root/layouts/_default/about.html" 'About facts must use an editorial index'
require 'about-experience-copy' "$root/layouts/_default/about.html" 'About experience must use unboxed timeline copy'
require 'about-life-notes' "$root/layouts/_default/about.html" 'About life section must use editorial notes'
require 'about-tools-directory' "$root/layouts/_default/about.html" 'About tools must use a directory layout'
require 'friends-directory' "$root/layouts/_default/friends.html" 'Friends must use a directory layout'
require 'friend-entry' "$root/layouts/_default/friends.html" 'Friend links must use editorial entries'
reject 'about-fact-card|about-life-card|about-experience-card|about-tool-group' "$root/layouts/_default/about.html" 'About card markup must be removed'
reject 'friends-grid|friend-card' "$root/layouts/_default/friends.html" 'Friends card markup must be removed'

printf 'PASS: fog archive structure is present\n'
