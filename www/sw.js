/* COLD LOGIC service worker: offline support + notification clicks.
   Network first, so a new deploy shows up the next time the app opens online. */
const CACHE = 'coldlogic-202611241344';
const SCHED = 'coldlogic-sched';   /* reminder snapshot written by the app, read here when the app is closed */
const FILES = ['./', 'index.html', 'manifest.json', 'firebase-config.js',
  'assets/profile.jpg', 'assets/logo.png', 'assets/physique.jpg', 'assets/academics.jpg',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/maskable-512.png', 'icons/apple-touch-180.png', 'sounds/sounds.json'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE)
    .then(c => Promise.all(FILES.map(f => c.add(f).catch(() => {}))))
    .then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE && k !== SCHED).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;   /* Firebase and other sites go straight to the network */
  e.respondWith(
    fetch(req).then(res => {
      if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req).then(m => m || (req.mode === 'navigate' ? caches.match('index.html') : undefined)))
  );
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const target = (e.notification.data && e.notification.data.url) || './';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
    for (const c of list) { if ('focus' in c) return c.focus(); }
    return self.clients.openWindow(target);
  }));
});

/* Reminders while the app is closed: the app saves its upcoming reminders; Chrome's periodic background sync
   wakes this worker now and then (best effort, it is the browser that decides when) and due ones are shown. */
async function fireDue() {
  try {
    const c = await caches.open(SCHED);
    const r = await c.match('sched.json');
    if (!r) return;
    const list = await r.json();
    const fr = await c.match('fired.json');
    const fired = fr ? await fr.json() : {};
    const now = Date.now();
    for (const e of list) {
      if (now >= e.from && now < e.until && !fired[e.key]) {
        fired[e.key] = now;
        await self.registration.showNotification(e.title, {
          body: e.body, tag: e.key, renotify: true,
          icon: 'icons/icon-192.png', badge: 'icons/icon-192.png',
          vibrate: [80, 40, 80], data: { url: e.url || './' }
        });
      }
    }
    Object.keys(fired).forEach(k => { if (now - fired[k] > 3 * 864e5) delete fired[k]; });
    await c.put('fired.json', new Response(JSON.stringify(fired)));
  } catch (err) {}
}
self.addEventListener('periodicsync', e => { if (e.tag === 'cl-remind') e.waitUntil(fireDue()); });
self.addEventListener('message', e => {
  const d = e.data || {};
  if (d.type === 'fire-due') e.waitUntil(fireDue());
  if (d.type === 'fired' && d.key) e.waitUntil((async () => {
    const c = await caches.open(SCHED), fr = await c.match('fired.json');
    const fired = fr ? await fr.json() : {}; fired[d.key] = Date.now();
    await c.put('fired.json', new Response(JSON.stringify(fired)));
  })());
});
