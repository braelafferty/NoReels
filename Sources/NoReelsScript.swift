/// The same Reels blocker as the Safari script, injected into every Instagram page.
enum NoReelsScript {
    static let source = #"""
(function () {
  'use strict';

  // ---------- Settings: change true / false to taste ----------
  const SETTINGS = {
    hideReelsTab: true,         // remove the Reels button from the nav bar and block the Reels page
    hideExploreGrid: true,      // Explore opens straight to search, so you can still look people up
    hideVideoPostsInFeed: true, // hide video posts in your home feed (on Instagram, those are Reels)
    blockReelLinks: true,       // hide reel links everywhere; opening one takes you to your feed instead
    hideProfileReelsTab: true,  // hide the Reels tab on people's profiles
  };
  // ------------------------------------------------------------

  // 1. CSS: hide Reels buttons and links as soon as they appear
  const selectors = [];
  if (SETTINGS.hideReelsTab) selectors.push('a[href="/reels/"]');
  if (SETTINGS.hideProfileReelsTab) selectors.push('a[href$="/reels/"]:not([href="/reels/"])');
  if (SETTINGS.blockReelLinks) selectors.push('a[href*="/reel/"]');

  const style = document.createElement('style');
  style.textContent = selectors.length
    ? selectors.join(',\n') + ' { display: none !important; }'
    : '';

  function ensureStyle() {
    if (!style.isConnected) (document.head || document.documentElement).appendChild(style);
  }
  ensureStyle();

  // 2. Redirects: never land on a Reels or Explore page
  function redirectIfBlocked() {
    const path = location.pathname;
    let target = null;

    if (SETTINGS.hideReelsTab && /^\/reels(\/|$)/.test(path)) {
      target = '/';
    } else if (SETTINGS.blockReelLinks && /\/reel\//.test(path)) {
      target = '/';
    } else if (SETTINGS.hideExploreGrid && /^\/explore\/?$/.test(path)) {
      target = '/explore/search/';
    } else if (SETTINGS.hideProfileReelsTab) {
      const m = path.match(/^\/([^\/]+)\/reels\/?$/);
      if (m) target = '/' + m[1] + '/';
    }

    if (target && target !== path) location.replace(target);
  }

  // 3. Home feed: hide posts that are reels / videos
  function cleanFeed() {
    if (!SETTINGS.hideVideoPostsInFeed) return;
    if (location.pathname !== '/') return;
    document.querySelectorAll('article').forEach(function (post) {
      if (post.style.display === 'none') return;
      if (post.querySelector('video, a[href*="/reel/"]')) {
        post.style.display = 'none';
      }
    });
  }

  // Run the feed cleaner whenever Instagram adds new content (at most once per frame)
  let scheduled = false;
  function schedule() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(function () {
      scheduled = false;
      cleanFeed();
    });
  }
  new MutationObserver(schedule).observe(document.documentElement, {
    childList: true,
    subtree: true,
  });

  // Instagram changes pages without reloading, so watch the address for changes
  let lastPath = null;
  setInterval(function () {
    if (location.pathname !== lastPath) {
      lastPath = location.pathname;
      redirectIfBlocked();
      schedule();
    }
    ensureStyle();
  }, 250);

  redirectIfBlocked();
})();
"""#
}
