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
header="$root/layouts/partials/header.html"
footer="$root/layouts/partials/footer.html"
extend_head="$root/layouts/partials/extend_head.html"
extend_footer="$root/layouts/partials/extend_footer.html"
comments="$root/layouts/partials/comments.html"
collapse="$root/layouts/shortcodes/collapse.html"
syntax="$root/assets/css/extended/syntax.css"

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
require 'data-mobile-weeks="26"' "$heatmap" 'mobile heatmap must render six months'
require 'last 6 months' "$heatmap" 'mobile heatmap summary must describe the last six months'
require 'last year' "$heatmap" 'heatmap summary must describe the last year'
require '--heatmap-cell-size:[[:space:]]*clamp\(8px,[[:space:]]*2\.45vw,[[:space:]]*10px\)' "$css" 'mobile heatmap cells must use a narrow-screen clamp'
require '--heatmap-gap:[[:space:]]*clamp\(1px,[[:space:]]*0\.45vw,[[:space:]]*2px\)' "$css" 'mobile heatmap gap must use a narrow-screen clamp'
require 'description = "Notes on foundation models, post-training, and AI infrastructure\."' "$learning_index" 'Learning section description must be concise'
require 'home-heatmap[[:space:]]*\{[^}]*display:[[:space:]]*block' "$css" 'mobile heatmap must remain visible'
require 'home-heatmap-months span[^}]*white-space:[[:space:]]*nowrap' "$css" 'heatmap month labels must not wrap vertically'
require 'mobile-menu-toggle' "$header" 'mobile hamburger toggle is missing from the header'
require 'aria-controls="menu"' "$header" 'mobile hamburger toggle must control the menu'
require 'home-section-header h2[[:space:]]*\{[^}]*font-size:[[:space:]]*clamp\(24px,[[:space:]]*7vw,[[:space:]]*29px\)' "$css" 'mobile homepage section titles must use the tighter archive scale'
require 'home-section-entry h3[[:space:]]*\{[^}]*font-size:[[:space:]]*clamp\(17px,[[:space:]]*4\.8vw,[[:space:]]*19px\)' "$css" 'mobile homepage article titles must stay compact inside archive slips'
require 'home-section\.home-archive-band::before[[:space:]]*\{[^}]*font-size:[[:space:]]*clamp\(48px,[[:space:]]*13vw,[[:space:]]*54px\)' "$css" 'mobile archive numbering must recede behind the title area'
require 'home-section-entry a[[:space:]]*\{[^}]*padding:[[:space:]]*14px[[:space:]]*48px[[:space:]]*15px[[:space:]]*16px' "$css" 'mobile homepage entries need compact slip padding and right-side arrow space'
require 'home-section-entry a[[:space:]]*\{[^}]*background:[^;]*linear-gradient' "$css" 'mobile homepage entries must use subtle archive-paper slips'
require 'home-section-entry a[[:space:]]*\{[^}]*border:[^;]*1px solid' "$css" 'mobile homepage entry slips need a quiet paper edge'
require 'home-section-entry a::after' "$css" 'mobile homepage entry slips need a right-side navigation mark'
require 'home-section-entry \+ \.home-section-entry::before[[:space:]]*\{[^}]*display:[[:space:]]*none' "$css" 'mobile homepage slips must not keep the old loose divider marks'
require 'home-section-entry \.entry-summary[[:space:]]*\{[^}]*display:[[:space:]]*none' "$css" 'mobile homepage summaries must be hidden for a cleaner index rhythm'
require 'top-link[[:space:]]*\{[^}]*width:[[:space:]]*38px[^}]*height:[[:space:]]*38px[^}]*opacity:[[:space:]]*0\.78' "$css" 'mobile top-link must be smaller and visually lighter'
require 'aria-expanded="false"' "$header" 'mobile hamburger toggle must expose collapsed state'
require 'menu-open' "$footer" 'mobile menu script must toggle the open state'
require 'Escape' "$footer" 'mobile menu must close on Escape'
reject '#menu[^}]*overflow-x:[[:space:]]*auto' "$css" 'mobile menu must not rely on horizontal scrolling'
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
require 'section-artwork--page picture[[:space:]]*\{[^}]*width:[[:space:]]*100%[^}]*min-height:[[:space:]]*0[^}]*aspect-ratio:[[:space:]]*4[[:space:]]*/[[:space:]]*3' "$css" 'mobile section artwork must derive height from the available width'
require 'home-section\.home-archive-band[^}]*background:[^;]*linear-gradient' "$css" 'homepage archive color wash is missing'
require 'section-masthead' "$home" 'section artwork and title need a shared masthead wrapper'
require 'section-masthead-copy' "$home" 'section title must overlay the artwork'
require_before 'section-masthead-breadcrumbs' 'section-masthead section-masthead--' "$home" 'breadcrumbs must remain above the artwork masthead'
require 'section-masthead[^}]*width:[[:space:]]*min\(1180px' "$css" 'section masthead must approach the homepage artwork width'
require 'section-artwork--page picture[^}]*aspect-ratio:[[:space:]]*14[[:space:]]*/[[:space:]]*5' "$css" 'desktop section masthead must use the larger 2.8:1 crop'
require 'section-masthead-copy[^}]*position:[[:space:]]*absolute' "$css" 'section title must be positioned over the artwork'
require '\.section-masthead--learning \.section-masthead-copy[[:space:]]*\{[^}]*padding-left:[[:space:]]*clamp\(20px,[[:space:]]*3vw,[[:space:]]*36px\)' "$css" 'Learning masthead copy needs a deliberate inset from the artwork edge'
require 'about-facts-index' "$root/layouts/_default/about.html" 'About facts must use an editorial index'
require 'about-experience-copy' "$root/layouts/_default/about.html" 'About experience must use unboxed timeline copy'
require 'about-life-notes' "$root/layouts/_default/about.html" 'About life section must use editorial notes'
require 'about-tools-directory' "$root/layouts/_default/about.html" 'About tools must use a directory layout'
require_count '1' '<h1[ >]' "$root/layouts/_default/about.html" 'About must expose one primary page heading'
require '<header class="about-profile-header about-hero"' "$root/layouts/_default/about.html" 'About title and biography must share one profile header'
require 'id="about-profile-title"' "$root/layouts/_default/about.html" 'About profile heading needs a stable accessible label target'
reject 'about-header' "$root/layouts/_default/about.html" 'About must not keep a second standalone page header'
require '\.about-page[[:space:]]*\{[^}]*counter-reset:[[:space:]]*about-section' "$css" 'About page must number only the sections that render'
require '\.about-section[[:space:]]*\{[^}]*display:[[:space:]]*grid[^}]*grid-template-columns:[[:space:]]*minmax\(180px,[[:space:]]*220px\)[[:space:]]*minmax\(0,[[:space:]]*1fr\)[^}]*counter-increment:[[:space:]]*about-section' "$css" 'About sections need the shared desktop dossier grid'
require '\.about-section-heading::before[[:space:]]*\{[^}]*content:[[:space:]]*counter\(about-section,[[:space:]]*decimal-leading-zero\)' "$css" 'About section headings need automatic visible indexes'
require '\.about-tools-directory[[:space:]]*\{[^}]*grid-template-columns:[[:space:]]*repeat\(3,[[:space:]]*minmax\(0,[[:space:]]*1fr\)\)' "$css" 'About tools need three balanced desktop columns'
require '@media screen and \(min-width:[[:space:]]*769px\) and \(max-width:[[:space:]]*960px\)' "$css" 'About needs a dedicated tablet breakpoint'
require '\.about-tools-directory[[:space:]]*\{[^}]*grid-template-columns:[[:space:]]*repeat\(2,[[:space:]]*minmax\(0,[[:space:]]*1fr\)\)' "$css" 'About tools need a two-column tablet layout'
require '\[data-theme="dark"\] \.about-tool-mark img[[:space:]]*\{[^}]*filter:[^;]*invert\(' "$css" 'dark About tool icons need a light inverse treatment'
reject 'about-button|about-fact-card|about-life-card|about-experience-card|about-experience-badge|about-facts-grid|about-life-grid|about-tools-grid|about-tool-group|about-tag-row' "$css" 'retired About card rules must be removed from the stylesheet'
require 'friends-directory' "$root/layouts/_default/friends.html" 'Friends must use a directory layout'
require 'friend-entry' "$root/layouts/_default/friends.html" 'Friend links must use editorial entries'
reject 'about-fact-card|about-life-card|about-experience-card|about-tool-group' "$root/layouts/_default/about.html" 'About card markup must be removed'
reject 'friends-grid|friend-card' "$root/layouts/_default/friends.html" 'Friends card markup must be removed'

# Progressive visual-polish regressions.
reject '^@import[[:space:]]+url\(' "$css" 'font imports must not live inside the concatenated extended stylesheet'
require 'fonts.googleapis.com/css2\?family=EB\+Garamond' "$extend_head" 'editorial web fonts must load from the document head'
require '--romantic-muted:[[:space:]]*#656d69' "$css" 'small light-theme metadata needs a WCAG-safe muted token'
reject '--romantic-dark-panel' "$css" 'mobile dark cards must only use defined Romantic tokens'
require 'TocOpen[[:space:]]*=[[:space:]]*false' "$root/hugo.toml" 'long inline tables of contents should be collapsed by default'
require '\.katex-display[[:space:]]*\{[^}]*max-width:[[:space:]]*100%[^}]*overflow-x:[[:space:]]*auto' "$css" 'display equations need bounded horizontal scrolling'
require '\.terms-tags a[[:space:]]*\{[^}]*color:[[:space:]]*var\(--primary\)[^}]*background:[[:space:]]*transparent' "$css" 'taxonomy links need readable editorial styling'
require '\.archive-year[[:space:]]*\{[^}]*max-width:[[:space:]]*920px' "$css" 'archive groups must align with the shared list measure'
require '\.pagination a[[:space:]]*\{[^}]*color:[[:space:]]*var\(--primary\)[^}]*background:[[:space:]]*transparent[^}]*border:[[:space:]]*1px solid var\(--border\)' "$css" 'pagination controls need explicit high-contrast colors'
require '\.post-content a[[:space:]]*\{[^}]*box-shadow:[[:space:]]*none' "$css" 'article links must not render duplicate underlines'
require '\.post-content figure figcaption p[[:space:]]*\{[^}]*margin:[[:space:]]*0' "$css" 'figure captions must not inherit paragraph spacing'
require '\.toc-tl-dot[[:space:]]*\{[^}]*border:[[:space:]]*1px solid var\(--tertiary\)' "$css" 'timeline TOC nodes need a visible inactive outline'
require '\.series-nav[[:space:]]*\{[^}]*border-radius:[[:space:]]*0' "$css" 'series navigation must follow the unboxed editorial language'
require '\.post-collapse[[:space:]]*\{' "$css" 'article collapse blocks need a local component style'
require 'class="post-collapse"' "$collapse" 'collapse shortcode must render valid local component markup'
require '\.copy-code[[:space:]]*\{[^}]*display:[[:space:]]*block' "$css" 'code copy controls must remain discoverable without hover'
require "copybutton\.classList\.add\('copy-code'\)" "$extend_footer" 'local footer override must preserve PaperMod code-copy behavior'
require 'navigator\.clipboard\.writeText\(codeblock\.textContent\)[^;]*\.catch\(copyWithSelection\)' "$extend_footer" 'clipboard rejection must fall back to selection copying'
require 'function copyingFailed\(\)' "$extend_footer" 'copy failures need visible feedback instead of a silent catch'
require '\.chroma \.lnt,[[:space:]]*\n\.chroma \.ln[[:space:]]*\{[[:space:]]*color:[[:space:]]*#656b66' "$syntax" 'light code line numbers need readable contrast'
require '\[data-theme="dark"\] \.chroma \.lnt,[[:space:]]*\n\[data-theme="dark"\] \.chroma \.ln[[:space:]]*\{[[:space:]]*color:[[:space:]]*#8f9ba4' "$syntax" 'dark code line numbers need readable contrast'
require 'Typewriter entrance effect' "$extend_footer" 'homepage typing entrance effect must be restored'
require 'document\.createTreeWalker\(h1,[[:space:]]*NodeFilter\.SHOW_TEXT\)' "$extend_footer" 'homepage typing must animate existing text nodes without flattening emphasis markup'
require "h1\.setAttribute\('aria-label',[[:space:]]*fullText\)" "$extend_footer" 'homepage typing must expose the complete title while characters animate'
reject "h1\.textContent[[:space:]]*=[[:space:]]*''" "$extend_footer" 'homepage typing must not replace the authored strong emphasis'
require '\.typewriter-cursor[[:space:]]*\{[^}]*animation:[[:space:]]*cursor-blink' "$css" 'homepage typing needs a visible restrained cursor'
require 'giscusScript\.dataset\.theme[[:space:]]*=[[:space:]]*document\.documentElement\.dataset\.theme' "$comments" 'Giscus must initialize from the active site theme'

open_braces="$(tr -cd '{' < "$css" | wc -c | tr -d '[:space:]')"
close_braces="$(tr -cd '}' < "$css" | wc -c | tr -d '[:space:]')"
if [[ "$open_braces" != "$close_braces" ]]; then
  printf 'FAIL: custom.css braces are unbalanced (open %s, close %s)\n' "$open_braces" "$close_braces" >&2
  exit 1
fi

printf 'PASS: fog archive structure is present\n'
