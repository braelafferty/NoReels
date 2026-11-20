/// The Reels blocker, injected into every Instagram page before Instagram's own code runs.
/// Change what gets hidden in the SETTINGS block near the top.
enum NoReelsScript {
    static let source = #"""
(function () {
  'use strict';

  // ---------- Settings: change these to taste ----------
  const SETTINGS = {
    minVideoSeconds: 120,       // videos at least this long still show; shorter ones count as Reels and are hidden
    hideReelsTab: true,         // remove the Reels button and block the Reels page
    hideProfileReelsTab: true,  // hide the Reels tab on people's profiles
    exploreOpensSearch: false,  // true = skip the Explore grid and go straight to search
  };
  // ------------------------------------------------------

  const media = Object.create(null); // post code -> { video: true/false, duration: seconds or null }
  let scheduled = false;
  let leftFor = null;
  let lastPath = null;

  // ===== 1. Learn which posts are short videos, from the data Instagram itself loads =====

  function remember(code, isVideo, duration) {
    const prev = media[code] || { video: false, duration: null };
    media[code] = {
      video: prev.video || !!isVideo,
      duration: typeof duration === 'number' && isFinite(duration) && duration > 0 ? duration : prev.duration,
    };
  }

  const MEDIA_KEYS = ['media_type', 'is_video', 'video_duration', 'video_versions', 'image_versions2', 'display_url'];

  function walk(node, depth) {
    if (!node || typeof node !== 'object' || depth > 40) return;
    if (Array.isArray(node)) {
      for (let i = 0; i < node.length; i++) walk(node[i], depth + 1);
      return;
    }
    const code = typeof node.code === 'string' ? node.code
      : typeof node.shortcode === 'string' ? node.shortcode : null;
    if (code && /^[A-Za-z0-9_-]{6,}$/.test(code) && MEDIA_KEYS.some(function (k) { return k in node; })) {
      const isVideo = node.media_type === 2 || node.is_video === true ||
        (node.media_type !== 8 && Array.isArray(node.video_versions) && node.video_versions.length > 0);
      remember(code, isVideo, node.video_duration);
    }
    for (const key in node) {
      const v = node[key];
      if (v && typeof v === 'object') walk(v, depth + 1);
    }
  }

  function scanText(text) {
    if (!text || text.length < 2) return;
    text = text.replace(/^for \(;;\);/, '');
    try {
      walk(JSON.parse(text), 0);
    } catch (e) {
      // Some responses hold several JSON documents, one per line
      text.split('\n').forEach(function (line) {
        line = line.trim();
        if (line[0] !== '{' && line[0] !== '[') return;
        try { walk(JSON.parse(line), 0); } catch (e2) {}
      });
    }
    schedule();
  }

  const API = /\/(graphql|api)\//;

  // Read Instagram's own data responses as they arrive (no extra requests are made)
  const origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function (input) {
      const p = origFetch.apply(this, arguments);
      try {
        const url = typeof input === 'string' ? input : (input && (input.url || input.href)) || '';
        if (API.test(url)) {
          p.then(function (res) {
            res.clone().text().then(scanText, function () {});
          }, function () {});
        }
      } catch (e) {}
      return p;
    };
  }

  const origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    this.__nrUrl = String(url);
    return origOpen.apply(this, arguments);
  };
  const origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function () {
    if (API.test(this.__nrUrl || '')) {
      this.addEventListener('load', function () {
        try {
          if (this.responseType === '' || this.responseType === 'text') scanText(this.responseText);
          else if (this.responseType === 'json') { walk(this.response, 0); schedule(); }
        } catch (e) {}
      });
    }
    return origSend.apply(this, arguments);
  };

  // Data Instagram embeds in the page when it first loads
  const scannedScripts = new WeakSet();
  function scanEmbedded() {
    document.querySelectorAll('script[type="application/json"]').forEach(function (s) {
      if (scannedScripts.has(s)) return;
      scannedScripts.add(s);
      scanText(s.textContent);
    });
  }

  // ===== 2. Decide what to show =====

  function verdict(code) {
    const m = media[code];
    if (!m) return 'unknown';
    if (!m.video) return 'show';
    if (m.duration == null) return 'unknown';
    return m.duration >= SETTINGS.minVideoSeconds ? 'show' : 'hide';
  }

  const CODE_RE = /\/(?:p|reel|tv)\/([A-Za-z0-9_-]+)/;
  function codeFrom(href) {
    const m = href && href.match(CODE_RE);
    return m ? m[1] : null;
  }

  function setState(el, state) {
    const prev = el.__nrState || 'show';
    el.__nrState = state;
    if (prev === state) return;
    if (prev === 'hide') el.style.removeProperty('display');
    if (prev === 'wait') el.style.removeProperty('visibility');
    if (state === 'hide') el.style.setProperty('display', 'none', 'important');
    if (state === 'wait') el.style.setProperty('visibility', 'hidden', 'important');
  }

  // The visible tile around a link (so a hidden post doesn't leave an empty box)
  function tileFor(a) {
    let el = a;
    for (let i = 0; i < 2; i++) {
      const p = el.parentElement;
      if (p && p.tagName === 'DIV' && p.children.length === 1) el = p; else break;
    }
    return el;
  }

  // Explore, profile grids, search, DMs: every link to a post
  function processLinks() {
    document.querySelectorAll('a[href*="/p/"], a[href*="/reel/"], a[href*="/tv/"]').forEach(function (a) {
      if (a.closest('article')) return; // feed posts are handled as a whole below
      const href = a.getAttribute('href');
      const code = codeFrom(href);
      if (!code) return;
      let v = verdict(code);
      if (v === 'unknown') v = /\/reel\//.test(href) ? 'hide' : 'show';
      if (!a.__nrTile) a.__nrTile = tileFor(a);
      setState(a.__nrTile, v);
    });
  }

  // Home feed: each post is an <article>
  function processFeed() {
    if (location.pathname !== '/') return;
    document.querySelectorAll('article').forEach(function (post) {
      let code = null;
      const links = post.querySelectorAll('a[href]');
      for (let i = 0; i < links.length && !code; i++) code = codeFrom(links[i].getAttribute('href'));

      let v = code ? verdict(code) : 'unknown';
      if (v === 'unknown') {
        const vid = post.querySelector('video');
        if (!vid && !post.querySelector('a[href*="/reel/"]')) {
          v = 'show';
        } else if (vid && isFinite(vid.duration) && vid.duration > 0) {
          if (code) remember(code, true, vid.duration);
          v = vid.duration >= SETTINGS.minVideoSeconds ? 'show' : 'hide';
        } else {
          v = 'wait'; // keep its space (so the video can load) but don't show it until we know its length
        }
      }
      setState(post, v);
    });
  }

  // The video most in view on screen
  function mainVideo() {
    let best = null, bestArea = 0;
    document.querySelectorAll('video').forEach(function (v) {
      const r = v.getBoundingClientRect();
      const w = Math.min(r.right, innerWidth) - Math.max(r.left, 0);
      const h = Math.min(r.bottom, innerHeight) - Math.max(r.top, 0);
      const area = w > 0 && h > 0 ? w * h : 0;
      if (area > bestArea) { best = v; bestArea = area; }
    });
    return best;
  }

  // Opening a short video directly (from a DM, a shared link, swiping in the viewer): go back
  function checkPostPage() {
    const path = location.pathname;
    const m = path.match(/^\/(?:[^\/]+\/)?(reels?|p|tv)\/([A-Za-z0-9_-]+)/);
    if (!m) return;
    const code = m[2];
    let v = verdict(code);
    if (v === 'unknown' && m[1] !== 'p') {
      const vid = mainVideo();
      if (vid && isFinite(vid.duration) && vid.duration > 0) {
        remember(code, true, vid.duration);
        v = verdict(code);
      }
    }
    if (v === 'hide' && leftFor !== path) {
      leftFor = path;
      if (history.length > 1) history.back(); else location.replace('/');
    }
  }

  // ===== 3. Pages that are all Reels =====

  function redirectIfBlocked() {
    const path = location.pathname;
    let target = null;
    if (SETTINGS.hideReelsTab && /^\/reels\/?$/.test(path)) {
      target = '/';
    } else if (SETTINGS.exploreOpensSearch && /^\/explore\/?$/.test(path)) {
      target = '/explore/search/';
    } else if (SETTINGS.hideProfileReelsTab) {
      const m = path.match(/^\/([^\/]+)\/reels\/?$/);
      if (m) target = '/' + m[1] + '/';
    }
    if (target && target !== path) location.replace(target);
  }

  const selectors = [];
  if (SETTINGS.hideReelsTab) selectors.push('a[href="/reels/"]');
  if (SETTINGS.hideProfileReelsTab) selectors.push('a[href$="/reels/"]:not([href="/reels/"])');
  const style = document.createElement('style');
  style.textContent = selectors.length ? selectors.join(',\n') + ' { display: none !important; }' : '';
  function ensureStyle() {
    if (!style.isConnected) (document.head || document.documentElement).appendChild(style);
  }

  // ===== 4. Keep it all running as Instagram changes the page =====

  function run() {
    scanEmbedded();
    processLinks();
    processFeed();
    checkPostPage();
  }

  function schedule() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(function () {
      scheduled = false;
      run();
    });
  }

  new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
  // Video lengths become known when a video loads, which doesn't change the page itself
  document.addEventListener('loadedmetadata', schedule, true);
  document.addEventListener('durationchange', schedule, true);

  setInterval(function () {
    if (location.pathname !== lastPath) {
      lastPath = location.pathname;
      redirectIfBlocked();
    }
    ensureStyle();
    schedule();
  }, 500);

  ensureStyle();
  redirectIfBlocked();
})();
"""#
}