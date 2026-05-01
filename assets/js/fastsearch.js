import * as params from '@params';

let fuse;
let searchItems = [];
let activeFilter = 'all';
let first;
let last;
let currentElem = null;
let resultsAvailable = false;
let currentQuery = '';

const resList = document.getElementById('searchResults');
const sInput = document.getElementById('searchInput');
const statusEl = document.getElementById('searchStatus');
const emptyEl = document.getElementById('searchEmpty');
const fallbackEl = document.getElementById('searchExternalFallback');
const suggestionButtons = document.querySelectorAll('[data-search-term]');
const filterButtons = document.querySelectorAll('[data-search-filter]');
const clearButtons = document.querySelectorAll('[data-search-clear]');

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function normalizeText(value) {
    return String(value ?? '').replace(/\s+/g, ' ').trim();
}

function truncateText(value, maxLength) {
    const normalized = normalizeText(value);
    if (normalized.length <= maxLength) return normalized;
    return `${normalized.slice(0, maxLength).trim()}...`;
}

function getFuseOptions() {
    const configured = params.fuseOpts ?? {};
    return {
        isCaseSensitive: configured.iscasesensitive ?? false,
        includeScore: true,
        includeMatches: true,
        minMatchCharLength: configured.minmatchcharlength ?? 1,
        shouldSort: configured.shouldsort ?? true,
        findAllMatches: configured.findallmatches ?? true,
        keys: configured.keys ?? [
            { name: 'title', weight: 0.30 },
            { name: 'tags', weight: 0.22 },
            { name: 'description', weight: 0.16 },
            { name: 'series', weight: 0.10 },
            { name: 'stack', weight: 0.08 },
            { name: 'status', weight: 0.06 },
            { name: 'outcome', weight: 0.04 },
            { name: 'summary', weight: 0.04 },
            { name: 'content', weight: 0.03 }
        ],
        location: configured.location ?? 0,
        threshold: configured.threshold ?? 0.36,
        distance: configured.distance ?? 1000,
        ignoreLocation: configured.ignorelocation ?? true
    };
}

function getSearchLimit() {
    return params.fuseOpts?.limit ?? 24;
}

function setStatus(message) {
    if (statusEl) statusEl.textContent = message;
}

function setEmptyState(isVisible, query) {
    if (!emptyEl) return;
    emptyEl.hidden = !isVisible;
    if (fallbackEl) {
        const term = encodeURIComponent(`site:ardenj.pages.dev ${query || ''}`.trim());
        fallbackEl.href = `https://www.google.com/search?q=${term}`;
    }
}

function getSectionLabel(item) {
    return item.sectionTitle || (item.section ? item.section.charAt(0).toUpperCase() + item.section.slice(1) : 'Note');
}

function getMatch(matches, key) {
    return (matches || []).find(function (match) {
        return match.key === key;
    });
}

function getArrayItemMatch(matches, key, index) {
    return (matches || []).find(function (match) {
        return match.key === key && match.refIndex === index;
    });
}

function getQueryTerms() {
    const query = normalizeText(currentQuery);
    if (!query) return [];

    const parts = query.split(/\s+/).filter(Boolean);
    const terms = query.includes(' ') ? [query].concat(parts) : [query];
    return Array.from(new Set(terms)).filter(function (term) {
        return term.length > 1 || /[\u3400-\u9fff]/.test(term);
    });
}

function findExactRanges(value) {
    const text = normalizeText(value);
    const textLower = text.toLocaleLowerCase();
    const ranges = [];

    getQueryTerms().forEach(function (term) {
        const termLower = term.toLocaleLowerCase();
        let cursor = 0;
        while (cursor < text.length) {
            const index = textLower.indexOf(termLower, cursor);
            if (index === -1) break;
            ranges.push([index, index + term.length - 1]);
            cursor = index + Math.max(term.length, 1);
        }
    });

    return ranges
        .sort(function (a, b) {
            return a[0] - b[0] || (b[1] - b[0]) - (a[1] - a[0]);
        })
        .reduce(function (merged, range) {
            const previous = merged[merged.length - 1];
            if (previous && range[0] <= previous[1]) {
                previous[1] = Math.max(previous[1], range[1]);
            } else {
                merged.push(range.slice());
            }
            return merged;
        }, []);
}

function highlightText(value, indices) {
    const text = normalizeText(value);
    if (!indices || indices.length === 0) return escapeHtml(text);

    let html = '';
    let lastIndex = 0;
    indices.forEach(function (region) {
        const start = Math.max(region[0], 0);
        const end = Math.min(region[1], text.length - 1);
        if (start > lastIndex) html += escapeHtml(text.slice(lastIndex, start));
        html += `<mark>${escapeHtml(text.slice(start, end + 1))}</mark>`;
        lastIndex = end + 1;
    });
    if (lastIndex < text.length) html += escapeHtml(text.slice(lastIndex));
    return html;
}

function highlightExactText(value) {
    const ranges = findExactRanges(value);
    if (ranges.length === 0) return escapeHtml(normalizeText(value));
    return highlightText(value, ranges);
}

function makeSnippet(value, indices, maxLength) {
    const text = normalizeText(value);
    if (!text) return '';
    const exactRanges = findExactRanges(text);
    const ranges = exactRanges.length > 0 ? exactRanges : [];
    if (ranges.length === 0 && (!indices || indices.length === 0)) return escapeHtml(truncateText(text, maxLength));

    const firstRegion = ranges[0] || indices[0];
    const center = firstRegion[0];
    const half = Math.floor(maxLength / 2);
    const start = Math.max(center - half, 0);
    const end = Math.min(start + maxLength, text.length);
    const clipped = text.slice(start, end);
    const adjusted = ranges
        .map(function (region) {
            return [region[0] - start, region[1] - start];
        })
        .filter(function (region) {
            return region[1] >= 0 && region[0] < clipped.length;
        })
        .map(function (region) {
            return [Math.max(region[0], 0), Math.min(region[1], clipped.length - 1)];
        });

    const prefix = start > 0 ? '...' : '';
    const suffix = end < text.length ? '...' : '';
    return `${prefix}${adjusted.length > 0 ? highlightText(clipped, adjusted) : escapeHtml(truncateText(clipped, maxLength))}${suffix}`;
}

function buildExcerpt(item, matches) {
    const descriptionMatch = getMatch(matches, 'description');
    if (descriptionMatch && item.description) return makeSnippet(item.description, descriptionMatch.indices, 180);

    const summaryMatch = getMatch(matches, 'summary');
    if (summaryMatch && item.summary) return makeSnippet(item.summary, summaryMatch.indices, 180);

    const contentMatch = getMatch(matches, 'content');
    if (contentMatch && item.content) return makeSnippet(item.content, contentMatch.indices, 180);

    return escapeHtml(truncateText(item.description || item.summary || item.content, 180));
}

function renderTags(item, matches) {
    if (item.section === 'projects' || !Array.isArray(item.tags) || item.tags.length === 0) return '';
    const tags = item.tags.map(function (tag, index) {
        const tagMatch = getArrayItemMatch(matches, 'tags', index);
        const label = tagMatch ? highlightExactText(tag) : escapeHtml(tag);
        return `<span>${label}</span>`;
    }).join('');
    return `<div class="entry-tags search-result-tags" aria-label="Tags">${tags}</div>`;
}

function renderProjectDetails(item, matches) {
    if (item.section !== 'projects') return '';

    const details = [];
    if (item.status) {
        const statusMatch = getMatch(matches, 'status');
        const status = statusMatch ? highlightExactText(item.status) : escapeHtml(item.status);
        details.push(`<span class="project-status">${status}</span>`);
    }
    if (Array.isArray(item.stack) && item.stack.length > 0) {
        const stack = item.stack.map(function (tool, index) {
            const stackMatch = getArrayItemMatch(matches, 'stack', index);
            return stackMatch ? highlightExactText(tool) : escapeHtml(tool);
        }).join(' · ');
        details.push(`<span class="project-stack">${stack}</span>`);
    }
    if (item.outcome) {
        const outcomeMatch = getMatch(matches, 'outcome');
        const outcome = outcomeMatch ? highlightExactText(item.outcome) : escapeHtml(item.outcome);
        details.push(`<span class="project-outcome">${outcome}</span>`);
    }
    if (details.length === 0) return '';

    return `<div class="project-entry-details search-project-details" aria-label="Project details">${details.join('')}</div>`;
}

function renderResult(result) {
    const item = result.item;
    const titleMatch = getMatch(result.matches, 'title');
    const title = titleMatch ? highlightExactText(item.title) : escapeHtml(item.title);
    const excerpt = buildExcerpt(item, result.matches);
    const readingTime = item.readingTime ? ` · ${item.readingTime} min` : '';

    return `<li class="post-entry search-result" data-section="${escapeHtml(item.section)}">
        <div class="search-result-meta">
            <span class="search-section-badge">${escapeHtml(getSectionLabel(item))}</span>
            <span>${escapeHtml(item.date || '')}${readingTime}</span>
        </div>
        <header class="entry-header">
            <h2 class="entry-hint-parent">${title}</h2>
        </header>
        <div class="entry-content search-result-excerpt">
            <p>${excerpt}</p>
        </div>
        ${renderTags(item, result.matches)}
        ${renderProjectDetails(item, result.matches)}
        <a class="entry-link search-result-link" aria-label="Open ${escapeHtml(item.title)}" href="${escapeHtml(item.permalink)}"></a>
    </li>`;
}

function updateFilterCounts(results) {
    const counts = { all: results.length, learning: 0, projects: 0, thinking: 0 };
    results.forEach(function (result) {
        if (Object.prototype.hasOwnProperty.call(counts, result.item.section)) counts[result.item.section] += 1;
    });

    Object.keys(counts).forEach(function (key) {
        const countEl = document.querySelector(`[data-filter-count="${key}"]`);
        if (countEl) countEl.textContent = counts[key];
    });
}

function setActiveFilter(filter) {
    activeFilter = filter;
    filterButtons.forEach(function (button) {
        const isActive = button.dataset.searchFilter === filter;
        button.classList.toggle('is-active', isActive);
        button.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    });
}

function getFilteredResults(results) {
    if (activeFilter === 'all') return results;
    return results.filter(function (result) {
        return result.item.section === activeFilter;
    });
}

function runSearch() {
    if (!fuse || !sInput || !resList) return;

    const query = sInput.value.trim();
    currentQuery = query;
    currentElem = null;
    resList.innerHTML = '';
    resultsAvailable = false;

    if (!query) {
        updateFilterCounts(searchItems.map(function (item) { return { item }; }));
        setStatus(`${searchItems.length} notes indexed. Type a query or try a starter search.`);
        setEmptyState(false, query);
        return;
    }

    const results = fuse.search(query, { limit: getSearchLimit() });
    updateFilterCounts(results);

    const filtered = getFilteredResults(results);
    if (filtered.length === 0) {
        setStatus(`No results for "${query}" in ${activeFilter === 'all' ? 'the archive' : activeFilter}.`);
        setEmptyState(true, query);
        return;
    }

    resList.innerHTML = filtered.map(renderResult).join('');
    resultsAvailable = true;
    first = resList.firstChild;
    last = resList.lastChild;
    setStatus(`${filtered.length} result${filtered.length === 1 ? '' : 's'} for "${query}".`);
    setEmptyState(false, query);
}

function activeToggle(anchor) {
    document.querySelectorAll('#searchResults .focus').forEach(function (element) {
        element.classList.remove('focus');
    });

    if (!anchor) return;
    anchor.focus();
    currentElem = anchor;
    anchor.parentElement.classList.add('focus');
}

function resetSearch() {
    if (!sInput || !resList) return;
    sInput.value = '';
    resList.innerHTML = '';
    resultsAvailable = false;
    currentElem = null;
    setActiveFilter('all');
    updateFilterCounts(searchItems.map(function (item) { return { item }; }));
    setEmptyState(false, '');
    setStatus(`${searchItems.length} notes indexed. Type a query or try a starter search.`);
    sInput.focus();
}

function applySearchTerm(term) {
    if (!sInput) return;
    sInput.value = term;
    sInput.focus();
    runSearch();
}

function initInteractions() {
    if (!sInput) return;

    sInput.addEventListener('input', runSearch);
    sInput.addEventListener('search', function () {
        if (!sInput.value) resetSearch();
    });

    suggestionButtons.forEach(function (button) {
        button.addEventListener('click', function () {
            applySearchTerm(button.dataset.searchTerm || '');
        });
    });

    clearButtons.forEach(function (button) {
        button.addEventListener('click', resetSearch);
    });

    filterButtons.forEach(function (button) {
        button.addEventListener('click', function () {
            setActiveFilter(button.dataset.searchFilter || 'all');
            runSearch();
        });
    });
}

function initKeyboardNavigation() {
    document.addEventListener('keydown', function (event) {
        if (!resList || !sInput) return;

        const key = event.key;
        const active = currentElem || document.activeElement;
        const inbox = document.getElementById('searchbox')?.contains(document.activeElement);

        if (key === 'Escape') {
            resetSearch();
            return;
        }

        if (!resultsAvailable || !inbox) return;

        if (key === 'ArrowDown') {
            event.preventDefault();
            if (document.activeElement === sInput || !active || active === sInput) {
                activeToggle(resList.firstChild?.querySelector('.search-result-link'));
            } else if (active.parentElement !== last) {
                activeToggle(active.parentElement.nextSibling?.querySelector('.search-result-link'));
            }
        } else if (key === 'ArrowUp') {
            event.preventDefault();
            if (active?.parentElement === first) {
                currentElem = null;
                sInput.focus();
                document.querySelectorAll('#searchResults .focus').forEach(function (element) {
                    element.classList.remove('focus');
                });
            } else if (active !== sInput) {
                activeToggle(active.parentElement.previousSibling?.querySelector('.search-result-link'));
            }
        } else if (key === 'ArrowRight' && active && active !== sInput) {
            active.click();
        }
    });
}

function initSearch() {
    if (!sInput || !resList) return;

    initInteractions();
    initKeyboardNavigation();

    fetch('../index.json')
        .then(function (response) {
            if (!response.ok) throw new Error(`Search index failed with ${response.status}`);
            return response.json();
        })
        .then(function (data) {
            searchItems = Array.isArray(data) ? data : [];
            fuse = new Fuse(searchItems, getFuseOptions());
            updateFilterCounts(searchItems.map(function (item) { return { item }; }));
            setStatus(`${searchItems.length} notes indexed. Type a query or try a starter search.`);
        })
        .catch(function (error) {
            setStatus('Search index could not be loaded.');
            console.error(error);
        });
}

initSearch();
