const CACHE_NAME = "medoru-v1";
const STATIC_ASSETS = [
  "/",
  "/manifest.json",
  "/assets/css/app.css",
  "/assets/js/app.js",
  "/images/pwa-icon-192.png",
  "/images/pwa-icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
    })
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const { request } = event;

  // Skip non-GET requests
  if (request.method !== "GET") return;

  // Skip LiveView WebSocket and live navigation
  if (request.url.includes("/live") || request.url.includes("/socket")) return;

  event.respondWith(
    caches.match(request).then((cached) => {
      // Return cached version if available
      if (cached) return cached;

      // Otherwise fetch from network
      return fetch(request).then((response) => {
        // Don't cache non-success responses
        if (!response || response.status !== 200 || response.type !== "basic") {
          return response;
        }

        // Cache successful static asset responses
        const url = new URL(request.url);
        if (
          url.pathname.startsWith("/assets/") ||
          url.pathname.startsWith("/images/") ||
          url.pathname === "/manifest.json"
        ) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseClone);
          });
        }

        return response;
      });
    })
  );
});
