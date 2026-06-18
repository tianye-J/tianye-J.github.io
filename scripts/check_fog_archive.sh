#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
css="$root/assets/css/extended/custom.css"
hero="$root/layouts/partials/home_info.html"
home="$root/layouts/_default/list.html"

require() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if ! rg -q -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

reject() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if rg -q -- "$pattern" "$file"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

require '--shell:[[:space:]]*#182629' "$css" 'storm shell token is missing'
require '--ochre:[[:space:]]*#a96f38' "$css" 'ochre token is missing'
require '<picture class="home-hero-picture">' "$hero" 'responsive hero picture is missing'
require 'fetchpriority="high"' "$hero" 'hero must have high fetch priority'
require 'Public-domain artwork · CC0' "$hero" 'artwork credit is missing'
require 'home-archive-band' "$home" 'homepage archive bands are missing'
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

printf 'PASS: fog archive structure is present\n'
