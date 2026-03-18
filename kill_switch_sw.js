// Kill-switch service worker
// Clears all caches and unregisters itself so the admin panel always loads fresh.
self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys()
      .then(function(names) {
        return Promise.all(names.map(function(name) {
          return caches.delete(name);
        }));
      })
      .then(function() {
        return self.registration.unregister();
      })
      .then(function() {
        return self.clients.matchAll({ type: 'window' });
      })
      .then(function(clients) {
        clients.forEach(function(client) {
          client.navigate(client.url);
        });
      })
  );
});
