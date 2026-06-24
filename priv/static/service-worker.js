const CACHE_NAME = "medoru-v139";
const STATIC_ASSETS = [
  "/manifest.json",
  "/assets/css/app.css",
  "/assets/js/app.js",
  "/images/pwa-icon-192.png",
  "/images/pwa-icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // Cache assets individually so one failure doesn't break everything
      return Promise.all(
        STATIC_ASSETS.map((url) =>
          cache.add(url).catch((err) => {
            console.warn("[SW] Failed to cache:", url, err);
          })
        )
      );
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

  const url = new URL(request.url);
  const isNavigation = request.mode === "navigate";
  const isStaticAsset =
    url.pathname.startsWith("/assets/") ||
    url.pathname.startsWith("/images/") ||
    url.pathname === "/manifest.json" ||
    url.pathname === "/service-worker.js";

  if (isNavigation) {
    // Network-only for HTML pages: never cache, always fetch fresh.
    // This prevents stale CSRF tokens and ensures LiveView gets fresh HTML.
    event.respondWith(fetch(request));
  } else if (isStaticAsset) {
    // Cache-first for static assets
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;

        return fetch(request).then((response) => {
          if (!response || response.status !== 200 || response.type !== "basic") {
            return response;
          }
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, clone);
          });
          return response;
        });
      })
    );
  }
  // Let other requests (API, etc.) pass through untouched
});

// Handle push notifications
self.addEventListener("push", (event) => {
  if (!event.data) return;

  let payload;
  try {
    payload = event.data.json();
  } catch (_e) {
    payload = {
      title: "Medoru",
      body: event.data.text(),
    };
  }

  const title = payload.title || "Medoru";
  const options = {
    body: payload.body || "",
    icon: payload.icon || "/images/pwa-icon-192.png",
    badge: payload.badge || "/images/pwa-icon-192.png",
    tag: payload.tag || "medoru-notification",
    data: payload.data || {},
    requireInteraction: false,
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Handle notification clicks
self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  let url = "/";

  if (data.classroom_id) {
    url = `/classrooms/${data.classroom_id}?tab=chat`;
  } else if (data.conversation_id) {
    url = `/messages/${data.conversation_id}`;
  } else if (data.url) {
    url = data.url;
  }

  event.waitUntil(
    self.clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (client.url.includes(url) && "focus" in client) {
            return client.focus();
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow(url);
        }
      })
  );
});
