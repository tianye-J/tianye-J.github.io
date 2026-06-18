#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
css="$root/assets/css/extended/custom.css"
hero="$root/layouts/partials/home_info.html"
home="$root/layouts/_default/list.html"
interlude="$root/layouts/partials/home_artwork_interlude.html"
heatmap="$root/layouts/partials/home_heatmap.html"

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
require 'counter-reset:[[:space:]]*archive-section' "$css" 'editorial section numbering is missing'
require 'project-status::before' "$css" 'project status marker is missing'
require 'home-heatmap-cell:nth-child' "$css" 'organic heatmap variation is missing'
require 'home-heatmap[[:space:]]*\{[[:space:]]*display:[[:space:]]*block' "$css" 'mobile heatmap must remain visible'
require 'home-heatmap-months span[^}]*white-space:[[:space:]]*nowrap' "$css" 'heatmap month labels must not wrap vertically'
require '\[data-theme="dark"\] \.home-section-header h2 a[^}]*color:[[:space:]]*var\(--romantic-dark-text\)[[:space:]]*!important' "$css" 'archive headings need an explicit dark-theme text color'
reject 'if and \(eq \$status "ok"\)' "$heatmap" 'fallback contribution data must not hide the heatmap'

printf 'PASS: fog archive structure is present\n'
