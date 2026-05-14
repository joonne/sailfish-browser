/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

// Frame script for media control in webapp mode.
// - Patches MediaSession.prototype to capture action handlers and metadata
// - Listens for embedui:media-control messages and invokes captured handlers
// - Reports metadata changes to the embedder

(function() {
    var Cu = Components.utils;
    var actionHandlers = {};
    var lastMetadataJSON = "";

    // --- Patch MediaSession prototype before page scripts run ---

    addEventListener("DOMWindowCreated", function(e) {
        try {
            var win = e.target.defaultView || content;
            patchMediaSession(win);
        } catch (ex) {}
    }, true);

    function patchMediaSession(win) {
        var unwrapped = Cu.waiveXrays(win);
        var MediaSession = unwrapped.MediaSession;
        if (!MediaSession || !MediaSession.prototype) {
            return;
        }

        // Patch setActionHandler on the prototype
        var originalSetActionHandler = MediaSession.prototype.setActionHandler;
        MediaSession.prototype.setActionHandler = Cu.exportFunction(function(action, handler) {
            actionHandlers[action] = handler;
            originalSetActionHandler.call(this, action, handler);
        }, unwrapped, {allowCrossOriginArguments: true});

        // Patch metadata setter on the prototype
        var metaDesc = Object.getOwnPropertyDescriptor(MediaSession.prototype, "metadata");
        if (metaDesc && metaDesc.set) {
            var originalMetaSetter = metaDesc.set;
            var originalMetaGetter = metaDesc.get;
            Object.defineProperty(MediaSession.prototype, "metadata", {
                get: Cu.exportFunction(function() {
                    return originalMetaGetter.call(this);
                }, unwrapped),
                set: Cu.exportFunction(function(value) {
                    originalMetaSetter.call(this, value);
                    reportMetadata(value);
                }, unwrapped, {allowCrossOriginArguments: true}),
                configurable: true,
                enumerable: true
            });
        }

        // Poll metadata as backup (catches metadata set before our patch)
        win.setTimeout(Cu.exportFunction(function() { pollMetadata(win); }, unwrapped), 2000);
    }

    function reportMetadata(metadata) {
        try {
            if (!metadata) return;
            var meta = Cu.waiveXrays(metadata);
            var artwork = "";
            if (meta.artwork && meta.artwork.length > 0) {
                var best = meta.artwork[0];
                for (var i = 1; i < meta.artwork.length; i++) {
                    var sizes = meta.artwork[i].sizes || "";
                    var bestSizes = best.sizes || "";
                    if (parseInt(sizes) > parseInt(bestSizes)) {
                        best = meta.artwork[i];
                    }
                }
                artwork = best.src || "";
            }
            var data = {
                title: meta.title || "",
                artist: meta.artist || "",
                album: meta.album || "",
                artwork: artwork
            };
            var json = JSON.stringify(data);
            if (json !== lastMetadataJSON) {
                lastMetadataJSON = json;
                sendAsyncMessage("embed:media-session-metadata", data);
            }
        } catch (e) {}
    }

    function pollMetadata(win) {
        try {
            var session = Cu.waiveXrays(win.navigator).mediaSession;
            if (session && session.metadata) {
                reportMetadata(session.metadata);
            }
        } catch (e) {}
        try {
            win.setTimeout(Cu.exportFunction(function() { pollMetadata(win); }, Cu.waiveXrays(win)), 3000);
        } catch (e) {}
    }

    // --- Action handling ---

    addMessageListener("embedui:media-control", function(msg) {
        var action = msg.json.action;

        // Try the captured MediaSession action handler first
        if (actionHandlers[action]) {
            try {
                actionHandlers[action]({action: action});
                return;
            } catch (e) {}
        }

        // Fallback: directly control media elements
        var mediaElements = content.document.querySelectorAll("video, audio");
        var activeMedia = null;

        for (var i = 0; i < mediaElements.length; i++) {
            var el = mediaElements[i];
            if (!el.paused || el.currentTime > 0) {
                activeMedia = el;
                break;
            }
        }

        if (!activeMedia && mediaElements.length > 0) {
            activeMedia = mediaElements[0];
        }

        if (!activeMedia) {
            return;
        }

        switch (action) {
            case "play":
                activeMedia.play();
                break;
            case "pause":
                activeMedia.pause();
                break;
            case "nexttrack":
                activeMedia.currentTime = Math.min(
                    activeMedia.duration || Infinity,
                    activeMedia.currentTime + 10
                );
                break;
            case "previoustrack":
                activeMedia.currentTime = Math.max(0, activeMedia.currentTime - 10);
                break;
            case "stop":
                activeMedia.pause();
                activeMedia.currentTime = 0;
                break;
        }
    });
})();
