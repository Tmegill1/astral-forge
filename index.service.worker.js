// Astral Forge moved to https://astral-forge.netlify.app/. Players who
// installed the game from this address still have the old offline service
// worker; browsers fetch this file to update it, and this version deletes the
// game's offline cache, unregisters itself and reloads open windows, which
// then land on the redirect page.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      await caches.delete(key);
    }
    await self.registration.unregister();
    const windows = await self.clients.matchAll({ type: "window" });
    for (const client of windows) {
      client.navigate(client.url);
    }
  })());
});
