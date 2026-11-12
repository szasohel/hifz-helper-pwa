(() => {
    'use strict';

    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const standalone = window.matchMedia('(display-mode: standalone)');
    const dismissalKey = 'hifz.iosInstallGuide.dismissed';
    if (!isIOS || navigator.standalone === true || standalone.matches) return;

    try {
        if (localStorage.getItem(dismissalKey) === 'true') return;
    } catch (_) {
        // Installation help should still work when browser storage is unavailable.
    }

    const guide = document.createElement('aside');
    guide.id = 'ios-install-guide';
    guide.setAttribute('aria-labelledby', 'ios-install-title');
    guide.innerHTML = `
    <h2 id="ios-install-title">Install Hifz Helper</h2>
    <p>Add it to your Home Screen for an app-like experience.</p>
    <ol>
      <li>Open this page in <strong>Safari</strong>.</li>
      <li>Tap <strong>Share</strong> (the square with an upward arrow).</li>
      <li>Choose <strong>Add to Home Screen</strong>.</li>
      <li>If shown, enable <strong>Open as Web App</strong>, then tap <strong>Add</strong>.</li>
    </ol>
    <p>Installation does not guarantee offline access. Progress is stored locally, without cloud sync.</p>
    <button type="button">Got it — don’t show again</button>
  `;
    guide.querySelector('button').addEventListener('click', () => {
        try {
            localStorage.setItem(dismissalKey, 'true');
        } catch (_) {
            // Dismiss for this page even when persistence is blocked.
        }
        guide.remove();
    });
    document.body.appendChild(guide);

    // Hide the instructions if the browser switches to an installed display mode.
    standalone.addEventListener('change', () => {
        if (standalone.matches) guide.remove();
    });
})();