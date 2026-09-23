/* Portable AI Workspace — landing page
   Theme toggle (light/dark), smooth scroll, tlačítko "nahoru".
   Bez externích závislostí. */

(function () {
  'use strict';

  var THEME_KEY = 'portable-ai-theme';
  var root = document.documentElement;

  function safeStorageGet(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (error) {
      return null;
    }
  }

  function safeStorageSet(key, value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (error) {
      /* Soukromý režim nebo zakázaný localStorage - ticho ignorujeme. */
    }
  }

  function preferredTheme() {
    var stored = safeStorageGet(THEME_KEY);
    if (stored === 'light' || stored === 'dark') {
      return stored;
    }
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
      return 'light';
    }
    return 'dark';
  }

  function applyTheme(theme) {
    root.setAttribute('data-theme', theme);
    var button = document.getElementById('theme-toggle');
    if (button) {
      button.setAttribute('aria-pressed', String(theme === 'light'));
    }
  }

  function toggleTheme() {
    var next = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
    applyTheme(next);
    safeStorageSet(THEME_KEY, next);
  }

  function setupToTop() {
    var button = document.getElementById('to-top');
    if (!button) {
      return;
    }

    function update() {
      button.hidden = window.scrollY < 400;
    }

    window.addEventListener('scroll', update, { passive: true });
    button.addEventListener('click', function () {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
    update();
  }

  function setupSmoothScroll() {
    var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduceMotion) {
      return;
    }

    document.addEventListener('click', function (event) {
      var link = event.target.closest('a[href^="#"]');
      if (!link || link.getAttribute('href') === '#') {
        return;
      }

      var target = document.querySelector(link.getAttribute('href'));
      if (!target) {
        return;
      }

      event.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      history.replaceState(null, '', link.getAttribute('href'));
    });
  }

  function init() {
    applyTheme(preferredTheme());

    var button = document.getElementById('theme-toggle');
    if (button) {
      button.addEventListener('click', toggleTheme);
    }

    setupSmoothScroll();
    setupToTop();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
