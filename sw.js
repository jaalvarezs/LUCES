/* Service Worker — Horómetros Fotoperiodo
   Estrategia: cache-first para el cascarón de la app (funciona sin internet);
   las peticiones a Supabase siempre van a la red (los datos offline se
   manejan con la cola en localStorage dentro de la app). */
const CACHE = 'horometros-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(APP_SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // Supabase y otras API: solo red (la app maneja el modo offline)
  if (url.hostname.endsWith('supabase.co')) return;
  // App shell y recursos estáticos: cache-first con actualización en segundo plano
  e.respondWith(
    caches.match(e.request).then(cacheado => {
      const red = fetch(e.request).then(resp => {
        if (resp && resp.status === 200 && (url.origin === location.origin || url.hostname === 'cdn.jsdelivr.net' || url.hostname.includes('fonts.g'))) {
          const copia = resp.clone();
          caches.open(CACHE).then(c => c.put(e.request, copia));
        }
        return resp;
      }).catch(() => cacheado);
      return cacheado || red;
    })
  );
});
